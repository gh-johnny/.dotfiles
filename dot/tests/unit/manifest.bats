#!/usr/bin/env bats
# The list language: packages.list resolution per backend, group filtering, hosts.

setup() { load helper; load_dot; }

@test "a bare name is used as-is" {
  OS_PKG=apt pkg_parse git
  [[ $P_SYS == git && -z $P_MISE$P_SCRIPT$P_CMD && $P_NA == 0 ]]
}

@test "a backend key renames the package; commas become several packages" {
  OS_PKG=dnf pkg_parse build pacman=base-devel dnf=gcc,gcc-c++,make
  assert_equal "$P_SYS" "gcc gcc-c++ make"
  OS_PKG=pacman pkg_parse build pacman=base-devel dnf=gcc,gcc-c++,make
  assert_equal "$P_SYS" "base-devel"
}

@test "distribution overrides take precedence over backend and ID_LIKE" {
  OS_PKG=dnf OS_ID=almalinux OS_LIKE='rhel fedora'
  pkg_parse script os_rhel=util-linux dnf=util-linux-script os_almalinux=alma-script
  assert_equal "$P_SYS" alma-script
  OS_ID=rocky pkg_parse script os_rhel=util-linux dnf=util-linux-script
  assert_equal "$P_SYS" util-linux
  OS_ID=fedora OS_LIKE='' pkg_parse script os_rhel=util-linux dnf=util-linux-script
  assert_equal "$P_SYS" util-linux-script
}

@test "backend=- means not from these repos, the fallback stays" {
  OS_PKG=apt pkg_parse neovim cmd=nvim apt=- mise=neovim
  assert_equal "$P_SYS" ""
  assert_equal "$P_MISE" "neovim"
  assert_equal "$P_CMD" "nvim"
}

@test "only= restricts a line to some backends" {
  OS_PKG=pacman pkg_parse shadow only=apk
  [[ $P_NA == 1 && -z $P_SYS ]]
  OS_PKG=apk pkg_parse shadow only=apk
  [[ $P_NA == 0 && $P_SYS == shadow ]]
}

@test "script= and cmd= are kept" {
  OS_PKG=apt pkg_parse tailscale cmd=tailscale script=tailscale
  [[ $P_SCRIPT == tailscale && $P_CMD == tailscale && $P_SYS == tailscale ]]
}

@test "list_lines keeps only active groups and drops comments" {
  manifest npm.list <<'L'
# header
ai   @openai/codex   # trailing comment
dev  @playwright/cli

mobile eas-cli
L
  DOT_GROUPS=(ai mobile)
  run list_lines npm.list
  assert_success
  assert_line --index 0 --regexp '^@openai/codex *$'
  assert_line --index 1 'eas-cli'
  refute_output --partial playwright
}

@test "list_lines_all keeps every line with its group" {
  manifest npm.list <<'L'
ai  a
dev b # x
L
  run list_lines_all npm.list
  assert_line --index 0 'ai  a'
  assert_line --index 1 --regexp '^dev b *$'
}

@test "a missing list is empty, not an error" {
  manifest other.list </dev/null
  run list_lines nope.list
  assert_success
  assert_output ''
}

@test "installer_line finds an entry in any group" {
  manifest installers.list <<'L'
ai  claude  claude  bash  https://claude.ai/install.sh
-   mise    mise    sh    https://mise.run
L
  run installer_line mise
  assert_output --regexp '^mise +sh +https://mise.run'
  run installer_line nope
  assert_failure
}

@test "hosts compose with include, without loading one twice" {
  DOT_HOSTS_DIR="$BATS_TEST_TMPDIR/hosts"; mkdir -p "$DOT_HOSTS_DIR"
  printf '# base\nDOT_GROUPS+=(base)\nDOT_STOW+=(zsh git)\n' >"$DOT_HOSTS_DIR/a.conf"
  printf '# b\ninclude a\ninclude a\nDOT_GROUPS+=(dev)\n' >"$DOT_HOSTS_DIR/b.conf"
  DOT_HOST=b host_load
  assert_equal "${DOT_GROUPS[*]}" "base dev"
  assert_equal "${DOT_STOW[*]}" "zsh git"
}

@test "drop removes words from a host array" {
  DOT_STOW=(zsh git tmux)
  drop DOT_STOW zsh
  assert_equal "${DOT_STOW[*]}" "git tmux"
}

@test "host_pick: --host, then the remembered one, then the hostname file" {
  DOT_HOSTS_DIR="$BATS_TEST_TMPDIR/hosts"; mkdir -p "$DOT_HOSTS_DIR" "$DOT_CONFIG"
  for h in cli pc "$(hostname)"; do echo "# $h" >"$DOT_HOSTS_DIR/$h.conf"; done
  DOT_YES=1
  host_pick pc; assert_equal "$DOT_HOST" pc
  echo cli >"$DOT_CONFIG/host"
  host_pick ""; assert_equal "$DOT_HOST" cli
  rm "$DOT_CONFIG/host"
  host_pick ""; assert_equal "$DOT_HOST" "$(hostname)"
}

@test "host_pick refuses a host that does not exist" {
  DOT_HOSTS_DIR="$BATS_TEST_TMPDIR/hosts"; mkdir -p "$DOT_HOSTS_DIR"
  run host_pick nosuchhost
  assert_failure
  assert_output --partial "not found"
}

@test "the real manifests parse: every packages.list line has a group and a name" {
  DOT_MANIFEST="$DOT_SRC/manifest"
  local group name rest n=0
  while read -r group name rest; do
    [[ -n $group && -n $name ]] || fail "bad line: $group $name"
    n=$((n + 1))
  done < <(list_lines_all packages.list)
  ((n > 20))
}

@test "the real hosts load and only name modules dot has" {
  local h m order=(self omarchy system flatpak links shell mise uv npm installers services ssh)
  for h in $(host_list); do
    DOT_HOST=$h host_load
    for m in "${DOT_MODULES[@]}"; do in_list "$m" "${order[@]}" || fail "$h: unknown module $m"; done
    for m in "${DOT_STOW[@]}"; do [[ -d $DOT_SRC/../$m ]] || fail "$h: no stow package $m"; done
  done
}

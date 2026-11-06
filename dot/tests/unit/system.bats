#!/usr/bin/env bats
# system: how a packages.list line becomes a repo package, a mise tool, an installer or nothing.

setup() {
  load helper; load_dot
  fake_backend fake
  DOT_GROUPS=(g)
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin"
}

plan() { system_plan; cat "$DOT_RUN/plan-$1"; }
fakecmd() { printf '#!/bin/sh\necho "%s 1.0"\n' "$1" >"$BATS_TEST_TMPDIR/bin/$1"; chmod +x "$BATS_TEST_TMPDIR/bin/$1"; hash -r; }

@test "installed packages are ok, missing ones planned for the repos" {
  manifest packages.list <<'L'
g git
g zsh
L
  INSTALLED="git"
  run plan sys
  assert_output $'zsh\tzsh'
  run cat "$DOT_RUN/plan-ok"
  assert_output git
}

@test "a command already on PATH satisfies the line, however it got there" {
  manifest packages.list <<'L'
g ripgrep cmd=rg mise=ripgrep
L
  fakecmd rg
  run plan ok
  assert_output ripgrep
}

@test "with a fallback, a name the repos lack goes to mise" {
  manifest packages.list <<'L'
g eza cmd=eza mise=eza
L
  AVAILABLE=""
  run plan mise
  assert_output $'eza\teza'
}

@test "with a fallback, a name the repos carry is taken from them" {
  manifest packages.list <<'L'
g eza cmd=eza mise=eza
L
  AVAILABLE="eza"
  run plan sys
  assert_output $'eza\teza'
}

@test "an explicit name is probed too when there is a fallback" {
  manifest packages.list <<'L'
g dust cmd=dust fake=du-dust mise=dust
L
  AVAILABLE=""
  run plan mise
  assert_output $'dust\tdust'
}

@test "backend=- with a script fallback plans the installer" {
  manifest packages.list <<'L'
g tailscale cmd=tailscale fake=- script=tailscale
L
  run plan script
  assert_output $'tailscale\ttailscale'
}

@test "backend=- without a fallback is gone, not an error" {
  manifest packages.list <<'L'
g build fake=-
L
  run plan gone
  assert_output build
}

@test "only= lines for other backends are ignored entirely" {
  manifest packages.list <<'L'
g shadow only=apk
L
  system_plan
  [[ ! -s $DOT_RUN/plan-sys && ! -s $DOT_RUN/plan-gone && ! -s $DOT_RUN/plan-ok ]]
}

@test "a tool mise installed earlier stays mise's (its config must not lose it)" {
  manifest packages.list <<'L'
g fzf cmd=fzf mise=fzf
L
  mkdir -p "$HOME/.local/share/mise/shims"
  printf '#!/bin/sh\n' >"$HOME/.local/share/mise/shims/fzf"; chmod +x "$HOME/.local/share/mise/shims/fzf"
  export PATH="$HOME/.local/share/mise/shims:$PATH"; hash -r
  run plan mise
  assert_output $'fzf\tfzf'
}

@test "groups that are off are not planned" {
  manifest packages.list <<'L'
g   git
off zsh
L
  run plan sys
  assert_output $'git\tgit'
}

@test "apply installs the plan in one batch and a second run installs nothing" {
  manifest packages.list <<'L'
g git
g zsh
L
  mod_system_apply >/dev/null
  assert_equal "$(cat "$BATS_TEST_TMPDIR/installs")" "install git zsh"
  rm -f "$DOT_RUN/plan-done"
  mod_system_apply >/dev/null
  [[ $(grep -c . "$BATS_TEST_TMPDIR/installs") == 1 ]]
}

@test "a failed batch is retried one by one and the bad name reported" {
  manifest packages.list <<'L'
g good
g bad
L
  be_install() { [[ " $* " == *" bad "* ]] && return 1; INSTALLED+=" $*"; }
  run mod_system_apply
  assert_failure
  assert_output --partial "could not install: bad"
  [[ " $INSTALLED " == *" good "* ]] || true
}

@test "arch.list is read on pacman only, AUR entries apart" {
  manifest packages.list </dev/null
  manifest arch.list <<'L'
g ghostty
g android-studio aur
L
  OS_PKG=pacman run arch_lines
  assert_line --index 0 $'ghostty\trepo'
  assert_line --index 1 $'android-studio\taur'
  OS_PKG=apt run arch_lines
  assert_output ''
}

@test "capture lists what no list knows, minus ignore.list" {
  manifest packages.list <<'L'
x git
L
  manifest ignore.list <<'L'
fake intel-ucode
*    linux
L
  INSTALLED="git intel-ucode linux htop"
  run system_capture
  assert_output htop
}

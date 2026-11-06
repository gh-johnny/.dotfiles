#!/usr/bin/env bats
# Distro detection: every distro on the support list resolves to the right package backend
# from its os-release alone (ID first, then ID_LIKE for derivatives).

setup() { load helper; load_dot; }

osr() { # ID ID_LIKE → detect, print the backend
  printf 'ID=%s\nID_LIKE="%s"\nPRETTY_NAME="test %s"\n' "$1" "$2" "$1" >"$BATS_TEST_TMPDIR/os-release"
  DOT_OS_RELEASE="$BATS_TEST_TMPDIR/os-release" os_detect
  echo "$OS_PKG"
}

@test "each supported distro maps to its backend" {
  local cases=(
    "arch||pacman" "endeavouros|arch|pacman" "manjaro|arch|pacman"
    "debian||apt" "ubuntu|debian|apt" "linuxmint|ubuntu debian|apt" "pop|ubuntu debian|apt"
    "zorin|ubuntu debian|apt" "elementary|ubuntu debian|apt" "mx|debian|apt" "kali|debian|apt"
    "fedora||dnf" "rhel|fedora|dnf" "centos|rhel fedora|dnf" "almalinux|rhel centos fedora|dnf"
    "opensuse-tumbleweed|opensuse suse|zypper" "opensuse-leap|suse opensuse|zypper"
    "void||xbps" "alpine||apk" "gentoo||emerge" "slackware||slackpkg" "nixos||nix"
  )
  local c id like want got
  for c in "${cases[@]}"; do
    IFS='|' read -r id like want <<<"$c"
    got=$(osr "$id" "$like")
    [[ $got == "$want" ]] || fail "$id (like: $like) → '$got', want $want"
  done
}

@test "an unknown derivative falls back to ID_LIKE" {
  run osr brand-new-distro "ubuntu debian"
  assert_output apt
}

@test "ID matching is case-insensitive" {
  run osr Arch ""
  assert_output pacman
}

@test "DOT_PKG overrides detection" {
  DOT_PKG=nix run osr debian ""
  assert_output nix
}

@test "nixos is flagged so system steps defer to configuration.nix" {
  osr nixos "" >/dev/null
  DOT_OS_RELEASE="$BATS_TEST_TMPDIR/os-release" os_detect
  [[ $OS_NIXOS == 1 ]]
}

@test "omarchy is detected by its checkout" {
  mkdir -p "$HOME/.local/share/omarchy"
  osr arch "" >/dev/null
  DOT_OS_RELEASE="$BATS_TEST_TMPDIR/os-release" os_detect
  [[ $OS_OMARCHY == 1 ]]
}

@test "os_summary names backend and init" {
  DOT_OS_RELEASE="$BATS_TEST_TMPDIR/none" DOT_PKG=apt os_detect
  run os_summary
  assert_output --partial "pkg=apt"
  assert_output --partial "init="
}

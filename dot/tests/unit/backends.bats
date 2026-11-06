#!/usr/bin/env bats
# Package backends against stubbed package managers: what each one asks the system, how it
# reads the answer, what it runs to install. The real thing runs in the container matrix.

setup() {
  load helper; load_dot
  root() { echo "ROOT $*"; }      # every install goes through root(): record instead of run
  OS_ID=test OS_VERSION=9
}

be() { source "$DOT_ROOT/lib/pkg/$1.sh"; }

@test "pacman: -T lists what is unsatisfied, install is --needed --noconfirm" {
  be pacman
  pacman() { [[ $1 == -T ]] && { shift; for p; do [[ $p == git ]] || echo "$p"; done; return 127; }; }
  run be_missing git zsh
  assert_output zsh
  run be_install zsh
  assert_output "ROOT pacman -S --needed --noconfirm zsh"
  run be_refresh
  assert_output "ROOT pacman -Syu --noconfirm"
}

@test "pacman: AUR refuses to bootstrap as root, uses yay/paru when present" {
  be pacman
  has() { [[ $1 == paru ]]; }
  run aur_helper
  assert_output paru
  has() { return 1; }
  if [[ $EUID -eq 0 ]]; then
    run aur_bootstrap
    assert_failure
    assert_output --partial "regular user"
  fi
}

@test "pacman: aur_install goes through the helper" {
  be pacman
  aur_bootstrap() { return 0; }
  aur_helper() { echo yay; }
  act() { echo "ACT $*"; }
  run aur_install android-studio
  assert_output "ACT yay -S --needed --noconfirm android-studio"
}

@test "apt: dpkg status decides installed, apt-cache candidate decides available" {
  be apt
  dpkg-query() { [[ ${*: -1} == git ]] && echo "install ok installed"; return 0; }
  apt-cache() { [[ $2 == zsh ]] && printf 'zsh:\n  Candidate: 5.9-6\n' || printf 'x:\n  Candidate: (none)\n'; }
  run be_missing git zsh
  assert_output zsh
  be_available zsh
  ! be_available nope
  run be_install zsh
  assert_output --partial "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq"
}

@test "dnf: rpm --whatprovides for installed, one cached repoquery for available" {
  be dnf
  rpm() { [[ ${*: -1} == git ]]; }
  dnf() { echo call >>"$BATS_TEST_TMPDIR/dnfcalls"; printf 'zsh\ntmux\n'; }
  run be_missing git zsh
  assert_output zsh
  be_available zsh
  be_available tmux
  ! be_available nope
  [[ $(grep -c call "$BATS_TEST_TMPDIR/dnfcalls") == 1 ]]
}

@test "dnf: the RHEL family gets EPEL and CRB, Fedora does not" {
  be dnf
  rpm() { return 1; }
  dnf() { return 1; }
  has() { [[ $1 == crb ]]; }
  OS_ID=almalinux run be_prepare
  assert_output --partial "ROOT dnf install -y -q epel-release"
  assert_output --partial "ROOT crb enable"
  OS_ID=rhel OS_VERSION=9.4 run be_prepare
  assert_output --partial "epel-release-latest-9.noarch.rpm"
  OS_ID=fedora run be_prepare
  assert_output ''
}

@test "zypper: exact search for available, --force-resolution on install" {
  be zypper
  zypper() { [[ ${*: -1} == zsh ]]; }
  be_available zsh
  ! be_available nope
  run be_install less
  assert_output "ROOT zypper -n -q install --force-resolution less"
}

@test "xbps: updates xbps itself first when it is outdated" {
  be xbps
  pkg_refresh_if_stale() { :; }
  xbps-install() { [[ $1 == -nu ]] && echo "xbps-0.60_1 update x86_64"; }
  run be_prepare
  assert_output "ROOT xbps-install -yu xbps"
  xbps-install() { :; }
  run be_prepare
  assert_output ''
}

@test "apk: info -e for installed, exact search for available" {
  be apk
  apk() { case $1 in info) [[ $3 == git ]] ;; search) [[ $4 == zsh ]] && echo zsh-5.9 ;; esac; }
  run be_missing git zsh
  assert_output zsh
  be_available zsh
  ! be_available nope
}

@test "emerge: /var/db/pkg for installed, category or bare name" {
  be emerge
  mkdir -p "$BATS_TEST_TMPDIR/vdb"
  compgen() { [[ $2 == /var/db/pkg/dev-vcs/git-* || $2 == "/var/db/pkg/*/tmux-"* ]]; }
  run be_missing dev-vcs/git app-shells/zsh tmux
  assert_output app-shells/zsh
  run be_install tmux
  assert_output --partial "--getbinpkg tmux"
}

@test "emerge: available means the ebuild dir exists" {
  be emerge
  FAKE_REPO="$BATS_TEST_TMPDIR/repo"; mkdir -p "$FAKE_REPO/app-misc/jq"
  _gentoo_repo() { echo "$FAKE_REPO"; }
  be_available app-misc/jq
  be_available jq
  ! be_available nope
}

@test "slackpkg: names from /var/log/packages, pkglist for available, a mirror when none" {
  be slackpkg
  export DOT_SYSROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$DOT_SYSROOT/var/log/packages" "$DOT_SYSROOT/var/lib/slackpkg" "$DOT_SYSROOT/etc/slackpkg"
  touch "$DOT_SYSROOT/var/log/packages/git-2.46.0-x86_64-1" "$DOT_SYSROOT/var/log/packages/aaa_base-15.0-x86_64-3"
  echo "slackware64 zsh 5.9 x86_64 1 zsh-5.9-x86_64-1 ./slackware64/ap txz" >"$DOT_SYSROOT/var/lib/slackpkg/pkglist"
  echo "Slackware 15.0" >"$DOT_SYSROOT/etc/slackware-version"
  echo "# all commented" >"$DOT_SYSROOT/etc/slackpkg/mirrors"
  run be_missing git zsh aaa_base
  assert_output zsh
  be_available zsh
  ! be_available nope
  ! be_stale
  run be_prepare
  assert_output --partial "slackware64-15.0/"
}

@test "nix: dot's own profile, no root, the user's profile untouched" {
  be nix
  act() { echo "ACT $*"; }
  nix-env() { [[ $1 == -p && $2 == "$DOT_NIX_PROFILE" && $3 == -q && $4 == git ]]; }
  run be_missing git zsh
  assert_output zsh
  run be_install zsh
  assert_output "ACT nix-env -p $DOT_NIX_PROFILE -f <nixpkgs> -iA zsh"
  [[ $DOT_NIX_PROFILE == "$HOME/.local/state/dot/nix-profile" ]]
}

@test "pkg_install retries one by one after a failed batch" {
  be_install() { [[ $# == 1 && $1 != bad ]] && return 0; return 1; }
  be_refresh() { :; }
  run pkg_install good bad
  assert_failure
  [[ $(cat "$DOT_RUN/pkg-failed") == bad ]]
}

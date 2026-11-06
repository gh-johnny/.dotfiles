#!/bin/sh
# Bootstrap a machine from nothing: bash, git and curl from the distro, the dotfiles checkout,
# then `dot apply`. POSIX sh on purpose: Alpine has no bash until this installs it.
#
#   curl -fsSL https://raw.githubusercontent.com/gh-johnny/.dotfiles/main/install.sh | sh
#   sh install.sh [--host NAME] [--yes] [--dry-run] ...     (anything else goes to dot apply)
#
# options:  --dir DIR     where the checkout goes (default ~/projects/dotfiles)
#           --repo URL    what to clone (default the https URL: a new machine has no SSH key yet)
#           --branch B    clone this branch
#           --from DIR    copy DIR instead of cloning (tests, offline installs from a USB stick)
set -eu

REPO=${DOT_REPO:-https://github.com/gh-johnny/.dotfiles.git}
DIR=${DOT_DIR:-$HOME/projects/dotfiles}
BRANCH=${DOT_BRANCH:-}
FROM=''

# separate our options from dot's, keeping dot's in "$@"
n=$#
while [ "$n" -gt 0 ]; do
  a=$1; shift; n=$((n - 1))
  case $a in
    --dir) DIR=$1; shift; n=$((n - 1)) ;;
    --repo) REPO=$1; shift; n=$((n - 1)) ;;
    --branch) BRANCH=$1; shift; n=$((n - 1)) ;;
    --from) FROM=$1; shift; n=$((n - 1)) ;;
    *) set -- "$@" "$a" ;;
  esac
done

say() { printf '\033[36m→\033[0m %s\n' "$*"; }
die() { printf '\033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

if [ "$(id -u)" = 0 ]; then SUDO=''
elif has sudo; then SUDO=sudo
elif has doas; then SUDO=doas
else die "run as root, or install sudo/doas first"
fi

# pkgname PM TOOL: the package that brings TOOL (dot needs the usual userland, which minimal
# images like nixos/nix lack).
pkgname() {
  case $1:$2 in
    *:cmp | *:diff) echo diffutils ;;
    *:find) echo findutils ;;
    nix:sed) echo gnused ;; nix:awk) echo gawk ;; nix:grep) echo gnugrep ;; nix:bash) echo bashInteractive ;;
    emerge:git) echo dev-vcs/git ;; emerge:curl) echo net-misc/curl ;; emerge:bash) echo app-shells/bash ;;
    *:awk) echo gawk ;;
    *) echo "$2" ;;
  esac
}

if has pacman; then PM=pacman; elif has apt-get; then PM=apt; elif has dnf; then PM=dnf
elif has zypper; then PM=zypper; elif has xbps-install; then PM=xbps; elif has apk; then PM=apk
elif has emerge; then PM=emerge; elif has slackpkg; then PM=slackpkg; elif has nix-env; then PM=nix
else PM=''
fi

need=''
for t in bash git curl sed awk grep find cmp diff; do
  has "$t" || { p=$(pkgname "$PM" "$t"); case " $need " in *" $p "*) ;; *) need="$need $p" ;; esac; }
done
if [ -n "$need" ]; then
  say "installing$need"
  # shellcheck disable=SC2086
  case $PM in
    pacman) $SUDO pacman -Syu --needed --noconfirm $need ;;
    apt)
      $SUDO apt-get update -qq
      $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $need ca-certificates ;;
    dnf) $SUDO dnf install -y -q $need ;;
    zypper) $SUDO zypper -n -q install $need ;;
    xbps)
      $SUDO xbps-install -Syu xbps >/dev/null 2>&1 || true
      $SUDO xbps-install -Sy $need ;;
    apk) $SUDO apk add -q $need ;;
    emerge)
      [ -d /var/db/repos/gentoo/profiles ] || $SUDO emerge-webrsync -q
      $SUDO emerge --noreplace --quiet --getbinpkg $need ;;
    slackpkg) $SUDO slackpkg -batch=on -default_answer=y install $need ;;
    nix) nix-env -f '<nixpkgs>' -iA $need ;;
    *) die "no package manager I know; install$need, then rerun" ;;
  esac
fi

if [ -d "$DIR/dot" ]; then
  say "dotfiles already at $DIR"
elif [ -n "$FROM" ]; then
  say "copying $FROM to $DIR"
  mkdir -p "$DIR"
  cp -a "$FROM/." "$DIR/"
else
  say "cloning $REPO to $DIR"
  mkdir -p "$(dirname "$DIR")"
  if [ -n "$BRANCH" ]; then git clone --branch "$BRANCH" "$REPO" "$DIR"; else git clone "$REPO" "$DIR"; fi
fi

exec bash "$DIR/dot/bin/dot" apply "$@"

#!/usr/bin/env bash
# Prepare a fresh Linux host for psync: packages, the psync package linked into $HOME, and user
# services that keep running after logout. Run it as the sync user (not root); sudo is used for
# packages and linger. Idempotent: it only does what is missing.
#
#   bash install.sh --plan          show what would be done, change nothing
#   bash install.sh                 do it
#   bash install.sh --with-backup   also install restic (and openssl) for `psync backup`
#
# Debian and Ubuntu (apt) and Arch (pacman). psync needs Syncthing 2 or newer: the Debian/Ubuntu
# archives still carry 1.x, so on apt systems this adds the official apt.syncthing.net repository
# (channel stable-v2) and its signing key. Pairing the host with the others is the next step
# (RUNBOOK.md, "Adding or replacing a host"); this script does not touch the network of your mesh.

set -euo pipefail

PLAN=false
WITH_BACKUP=false
for arg in "$@"; do
  case $arg in
    --plan) PLAN=true ;;
    --with-backup) WITH_BACKUP=true ;;
    *) echo "usage: bash install.sh [--plan] [--with-backup]" >&2; exit 2 ;;
  esac
done

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
# The package is stowed from wherever this script lives: STOW_DIR holds a directory named psync.
STOW_DIR=$(dirname "$HERE")
OS_RELEASE=${PSYNC_OS_RELEASE:-/etc/os-release}
SYNCTHING_KEY_URL=https://syncthing.net/release-key.gpg
SYNCTHING_KEYRING=/etc/apt/keyrings/syncthing-archive-keyring.gpg
SYNCTHING_LIST=/etc/apt/sources.list.d/syncthing.list
SYNCTHING_DEB="deb [signed-by=$SYNCTHING_KEYRING] https://apt.syncthing.net/ syncthing stable-v2"

die() { echo "install: $*" >&2; exit 1; }
say() { echo "install: $*"; }

# run CMD...: print it, and run it unless this is a plan
run() {
  echo "  + $*"
  $PLAN || "$@"
}

[[ $EUID -ne 0 ]] || die "run it as the sync user, not root (it uses sudo where it needs to)"
[[ $(basename "$HERE") == psync ]] ||
  die "this script lives in $HERE, but stow links a package by its directory name: keep the directory called psync"

family=unknown
if [[ -r $OS_RELEASE ]]; then
  # shellcheck disable=SC1090
  . "$OS_RELEASE"
  case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "* | *" ubuntu "*) family=apt ;;
    *" arch "*) family=pacman ;;
  esac
fi
[[ $family != unknown ]] ||
  die "unsupported distribution. Install by hand: syncthing (2 or newer), jq, curl, stow, git (restic and openssl for backups), then run: stow --no-folding --dir=$STOW_DIR --target=\$HOME psync"
if $PLAN; then say "$family system, plan only (nothing is changed)"; else say "$family system"; fi

wanted=(jq curl stow git)
$WITH_BACKUP && wanted+=(restic openssl)
missing=()
for tool in "${wanted[@]}"; do
  command -v "$tool" >/dev/null || missing+=("$tool")
done

syncthing_ok=false
if command -v syncthing >/dev/null; then
  major=$(syncthing --version 2>/dev/null | sed -n 's/^syncthing v\([0-9]*\)\..*/\1/p')
  [[ ${major:-0} -ge 2 ]] && syncthing_ok=true
fi

case $family in
  apt)
    if ! $syncthing_ok; then
      say "Syncthing 2 or newer is missing: adding the official repository (channel stable-v2)"
      run sudo mkdir -p /etc/apt/keyrings
      run sudo curl -fsSL -o "$SYNCTHING_KEYRING" "$SYNCTHING_KEY_URL"
      echo "  + echo '$SYNCTHING_DEB' | sudo tee $SYNCTHING_LIST"
      $PLAN || echo "$SYNCTHING_DEB" | sudo tee "$SYNCTHING_LIST" >/dev/null
      run sudo apt-get update
      missing+=(syncthing)
    fi
    ((${#missing[@]} == 0)) || run sudo apt-get install -y "${missing[@]}"
    ;;
  pacman)
    $syncthing_ok || missing+=(syncthing)
    ((${#missing[@]} == 0)) || run sudo pacman -S --needed --noconfirm "${missing[@]}"
    ;;
esac
say "linking the psync package into \$HOME"
run mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
run stow --no-folding --dir="$STOW_DIR" --target="$HOME" psync

say "user services should keep running without a login session"
if $PLAN; then
  echo "  + sudo loginctl enable-linger $USER"
elif ! sudo loginctl enable-linger "$USER" 2>/dev/null; then
  say "warning: could not enable linger (no systemd-logind here?). Do it where systemd runs: sudo loginctl enable-linger $USER"
fi

cat <<EOF

install: done. Say where your folder is and which ignore rules it gets (generic: node_modules, caches,
git lock files, SQLite companions; psync config lists every setting):
  psync init --folder-path ~/code --ignore-profile generic
Next, pair this host (the first host of a new mesh needs no peer; use --listen tcp://:22000
on a host the others will dial, tcp://127.0.0.1:22000 on one that only dials out):
  psync setup --listen tcp://:22000
  psync setup --peer-id <ID of a host already in> --peer-name <its name> --peer-address tcp://<its address>:22000 --listen tcp://127.0.0.1:22000
then, on a host that is already in the mesh:
  psync add-host --id <the ID this host printed> --name <this host's name>
and check with: psync hosts, psync doctor --roundtrip
EOF

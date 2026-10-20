#!/usr/bin/env bash
# The host-local pieces of the VPS that stow cannot carry. Idempotent. Run it from a checkout
# of this directory; RUNBOOK.md ("Rebuild the VPS") has the order of everything else.
#
#   bash install.sh user        as the sync user: minimal ~/.zshrc with the `psync ready` login hook,
#                               and the `ai` wrapper (a symlink breaks the launcher's repo-root detection)
#   sudo bash install.sh root   as root: the public-SSH guard. tcp/22 stays closed while Tailscale is
#                               healthy and reopens after 5 minutes without it; rpcbind is switched off
#
# SBIN_DIR, UNIT_DIR and RULES_V4 can be redirected (psync/tests/run.sh does).

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SBIN_DIR=${SBIN_DIR:-/usr/local/sbin}
UNIT_DIR=${UNIT_DIR:-/etc/systemd/system}
RULES_V4=${RULES_V4:-/etc/iptables/rules.v4}

# keep_once FILE: save what is there before the first overwrite, never again.
keep_once() {
  [[ ! -e $1 || -e $1.pre-psync ]] || cp -p "$1" "$1.pre-psync"
}

install_user() {
  keep_once "$HOME/.zshrc"
  install -m 644 "$HERE/zshrc" "$HOME/.zshrc"
  mkdir -p "$HOME/.local/bin"
  keep_once "$HOME/.local/bin/ai"
  install -m 755 "$HERE/ai" "$HOME/.local/bin/ai"
  echo "installed ~/.zshrc and ~/.local/bin/ai (originals, if any, kept as *.pre-psync)"
}

install_root() {
  install -m 755 "$HERE/psync-ssh-guard" "$SBIN_DIR/psync-ssh-guard"
  install -m 644 "$HERE/psync-ssh-guard.service" "$HERE/psync-ssh-guard.timer" "$UNIT_DIR/"
  systemctl daemon-reload
  # Out of the saved firewall too, or the rule is back after a reboot until the guard's first run.
  if [[ -e $RULES_V4 ]]; then
    sed -i '/^-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT$/d' "$RULES_V4"
  fi
  systemctl enable --now psync-ssh-guard.timer
  systemctl start psync-ssh-guard.service # closes the live rule right away when Tailscale is Running
  systemctl disable --now rpcbind.service rpcbind.socket 2>/dev/null || true
  echo "guard installed and active (journalctl -t psync-ssh-guard)"
}

case ${1-} in
  user) install_user ;;
  root) install_root ;;
  *) echo "usage: bash install.sh user | sudo bash install.sh root" >&2; exit 2 ;;
esac

# shellcheck shell=bash
# OpenRC (Alpine, Gentoo, Artix...). No user services.

svc_enabled() { [[ $1 == system ]] && rc-update show default 2>/dev/null | qgrep -E "^[[:space:]]*$2[[:space:]]"; }
svc_exists()  { [[ $1 == system && -x /etc/init.d/$2 ]]; }
svc_enable() {
  [[ $1 == user ]] && { warn "openrc has no user services ($2)"; return 1; }
  root rc-update add "$2" default || return 1
  [[ $OS_INIT_LIVE == 1 ]] && root rc-service "$2" start
  return 0
}

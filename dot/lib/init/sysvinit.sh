# shellcheck shell=bash
# SysV init (MX Linux's default boot, Slackware's rc.d, Devuan). Best effort.

svc_enabled() {
  [[ $1 == system ]] || return 1
  if [[ -d ${DOT_SYSROOT:-}/etc/rc.d && ! -d ${DOT_SYSROOT:-}/etc/rc2.d ]]; then [[ -x ${DOT_SYSROOT:-}/etc/rc.d/rc.$2 ]] # Slackware: executable bit = enabled
  else compgen -G "${DOT_SYSROOT:-}/etc/rc[2345].d/S*$2" >/dev/null
  fi
}
svc_exists() { [[ $1 == system && ( -e ${DOT_SYSROOT:-}/etc/init.d/$2 || -e ${DOT_SYSROOT:-}/etc/rc.d/rc.$2 ) ]]; }
svc_enable() {
  [[ $1 == user ]] && { warn "sysvinit has no user services ($2)"; return 1; }
  if [[ -e ${DOT_SYSROOT:-}/etc/rc.d/rc.$2 ]]; then root chmod +x "${DOT_SYSROOT:-}/etc/rc.d/rc.$2"
  elif has update-rc.d; then root update-rc.d "$2" defaults
  elif has chkconfig; then root chkconfig "$2" on
  else warn "do not know how to enable $2 here"; return 1
  fi
}

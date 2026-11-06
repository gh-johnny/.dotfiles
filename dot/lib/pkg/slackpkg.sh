# shellcheck shell=bash
# slackpkg (Slackware). Best effort: slackpkg does not resolve dependencies and a good part of
# a dev box only exists in SlackBuilds.org.

_slack_installed() { ls "${DOT_SYSROOT:-}/var/log/packages" 2>/dev/null | sed -E 's/-[^-]+-[^-]+-[^-]+$//'; }

be_missing() {
  local p inst
  inst=$(_slack_installed)
  for p; do grep -qxF "$p" <<<"$inst" || echo "$p"; done
}
be_available() { awk -v p="$1" '$2 == p { f = 1 } END { exit !f }' "${DOT_SYSROOT:-}/var/lib/slackpkg/pkglist" 2>/dev/null; }
be_stale()     { [[ ! -s "${DOT_SYSROOT:-}/var/lib/slackpkg/pkglist" ]]; }
be_refresh()   { root slackpkg -batch=on -default_answer=y update; }
be_install()   { root slackpkg -batch=on -default_answer=y install "$@"; }
be_explicit()  { _slack_installed; }

# slackpkg ships with every mirror commented out.
be_prepare() {
  local m="${DOT_SYSROOT:-}/etc/slackpkg/mirrors" ver
  grep -qE '^[[:space:]]*(https?|ftp)://' "$m" 2>/dev/null && return 0
  ver=$(sed -E 's/.* ([0-9.]+[^ ]*).*/\1/' "${DOT_SYSROOT:-}/etc/slackware-version" 2>/dev/null)
  [[ $ver == *+ || -z $ver ]] && ver=current
  warn "no slackpkg mirror selected, using mirrors.slackware.com for $ver"
  root sh -c "echo 'https://mirrors.slackware.com/slackware/slackware64-$ver/' >>'$m'"
}

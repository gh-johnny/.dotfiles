# shellcheck shell=bash
# runit (Void). A service is enabled by linking /etc/sv/NAME into the supervised directory.

_runsvdir() {
  local d
  for d in /var/service /run/runit/service /etc/runit/runsvdir/default; do
    [[ -d $d ]] && { echo "$d"; return; }
  done
  echo /var/service
}
svc_enabled() { [[ $1 == system && -e $(_runsvdir)/$2 ]]; }
svc_exists()  { [[ $1 == system && -d /etc/sv/$2 ]]; }
svc_enable() {
  [[ $1 == user ]] && { warn "runit user services are not managed by dot ($2)"; return 1; }
  local d
  d=$(_runsvdir)
  root mkdir -p "$d"
  root ln -sfn "/etc/sv/$2" "$d/$2"
}

# shellcheck shell=bash
# xbps (Void).

be_missing() {
  local p
  for p; do xbps-query "$p" >/dev/null 2>&1 || echo "$p"; done
}
be_available() { xbps-query -R "$1" >/dev/null 2>&1; }
be_stale()     { ! compgen -G '/var/db/xbps/*/*-repodata' >/dev/null; }
be_refresh()   { root xbps-install -S; }
be_install()   { root xbps-install -y "$@"; }
be_explicit()  { xbps-query -m | sed 's/-[^-]*$//'; }

# xbps refuses to install anything while xbps itself is out of date.
be_prepare() {
  pkg_refresh_if_stale
  if xbps-install -nu xbps 2>/dev/null | grep -q '^xbps-'; then
    root xbps-install -yu xbps
  fi
  return 0
}

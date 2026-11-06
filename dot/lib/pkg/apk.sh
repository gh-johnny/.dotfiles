# shellcheck shell=bash
# apk (Alpine, postmarketOS). musl: prebuilt glibc binaries will not run here.

be_missing() {
  local p
  for p; do apk info -e "$p" >/dev/null 2>&1 || echo "$p"; done
}
be_available() { [[ -n $(apk search -q -x "$1" 2>/dev/null) ]]; }
be_stale()     { ! compgen -G '/var/cache/apk/APKINDEX*' >/dev/null; }
be_refresh()   { root apk update -q; }
be_install()   { root apk add -q "$@"; }
be_explicit()  { cat /etc/apk/world; }

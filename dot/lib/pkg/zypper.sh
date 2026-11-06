# shellcheck shell=bash
# zypper (openSUSE Tumbleweed / Leap, SLE).

be_missing() {
  local p
  for p; do rpm -q --whatprovides "$p" >/dev/null 2>&1 || echo "$p"; done
}
be_available() { zypper -n -q search -x "$1" >/dev/null 2>&1; }
be_refresh()   { root zypper -n -q refresh; }
# --force-resolution: let the solver replace what conflicts (busybox-less and co. in minimal images)
be_install()   { root zypper -n -q install --force-resolution "$@"; }
be_explicit() {
  # zypp remembers what came in as a dependency; everything else was asked for.
  local auto=/var/lib/zypp/AutoInstalled
  rpm -qa --qf '%{NAME}\n' | sort -u | { if [[ -r $auto ]]; then grep -vxFf "$auto"; else cat; fi; }
}

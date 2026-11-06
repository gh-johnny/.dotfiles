# shellcheck shell=bash
# pkg: the package backend for this distro. Each lib/pkg/<backend>.sh defines
#   be_missing NAME...   print the ones that are not installed
#   be_available NAME    is it in the configured repos?
#   be_install NAME...   install them (non-interactive)
#   be_refresh           refresh the repo metadata
#   be_explicit          print what the user installed explicitly (for `dot capture`)
# and may define be_prepare (one-time repo setup, e.g. EPEL), called before the first install.

pkg_load() {
  [[ -n ${OS_PKG:-} ]] || die "no package manager found for ${OS_NAME:-this system}"
  local f="$DOT_ROOT/lib/pkg/$OS_PKG.sh"
  [[ -f $f ]] || die "no backend for $OS_PKG"
  # shellcheck disable=SC1090
  source "$f"
}

pkg_refresh() {
  [[ -f $DOT_RUN/refreshed ]] && return 0
  touch "$DOT_RUN/refreshed"
  info "refreshing $OS_PKG metadata"
  be_refresh
}

pkg_missing() { (($#)) || return 0; be_missing "$@"; }

pkg_available() {
  pkg_refresh_if_stale
  be_available "$1"
}

# Refresh before the first availability query on a box that never synced (containers, fresh installs).
pkg_refresh_if_stale() {
  [[ -f $DOT_RUN/refreshed ]] && return 0
  if declare -F be_stale >/dev/null && be_stale; then pkg_refresh; fi
  return 0
}

# pkg_install NAME...: one transaction; when it fails, retry one by one so a single bad name
# does not hold the rest back. Prints the names that still failed to $DOT_RUN/pkg-failed.
pkg_install() {
  (($#)) || return 0
  if [[ ! -f $DOT_RUN/prepared ]]; then
    touch "$DOT_RUN/prepared"
    declare -F be_prepare >/dev/null && be_prepare
  fi
  pkg_refresh_if_stale
  be_install "$@" && return 0
  [[ $DOT_DRY == 1 ]] && return 0
  (($# > 1)) || { echo "$1" >>"$DOT_RUN/pkg-failed"; return 1; }
  warn "batch install failed, retrying one by one"
  pkg_refresh
  local p rc=0
  for p; do
    be_install "$p" || { echo "$p" >>"$DOT_RUN/pkg-failed"; rc=1; }
  done
  return $rc
}

pkg_explicit() { be_explicit; }

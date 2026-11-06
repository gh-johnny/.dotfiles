# shellcheck shell=bash
# emerge (Gentoo). Uses the official binhost when it can (--getbinpkg): compiling the world
# from source is not "fast".

_gentoo_repo() { portageq get_repo_path / gentoo 2>/dev/null || echo /var/db/repos/gentoo; }

be_missing() {
  local p cat name
  for p; do
    if [[ $p == */* ]]; then cat=${p%/*} name=${p#*/}; else cat='*' name=$p; fi
    # shellcheck disable=SC2086
    compgen -G "/var/db/pkg/$cat/$name-[0-9]*" >/dev/null || echo "$p"
  done
}
be_available() {
  local repo p=$1
  repo=$(_gentoo_repo)
  if [[ $p == */* ]]; then [[ -d $repo/$p ]]; else compgen -G "$repo/*/$p" >/dev/null; fi
}
be_stale()    { [[ ! -d $(_gentoo_repo)/profiles ]]; }
be_refresh()  { root emerge-webrsync -q; }
be_install()  { root emerge --noreplace --quiet --quiet-build=y --getbinpkg "$@"; }
be_explicit() { cat /var/lib/portage/world; }

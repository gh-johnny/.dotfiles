# shellcheck shell=bash
# dnf (Fedora, RHEL, CentOS Stream, AlmaLinux, Rocky). The RHEL family gets EPEL + CRB first:
# half of a dev box (stow, neovim, fzf, ripgrep...) lives there.

be_missing() {
  local p
  for p; do rpm -q --whatprovides "$p" >/dev/null 2>&1 || echo "$p"; done
}
# one repoquery for the whole run: `dnf info` per package costs seconds each
be_available() {
  local c="$DOT_RUN/dnf-names"
  [[ -s $c ]] || dnf -q repoquery --queryformat '%{name}\n' 2>/dev/null | sort -u >"$c"
  grep -qxF "$1" "$c"
}
be_refresh()   { root dnf -q -y makecache; }
be_install()   { root dnf install -y -q "$@"; }
be_explicit()  { dnf repoquery --userinstalled --queryformat '%{name}\n' 2>/dev/null; }

be_prepare() {
  case $OS_ID in
    almalinux | rocky | centos | rhel | ol) ;;
    *) return 0 ;;
  esac
  if ! rpm -q epel-release >/dev/null 2>&1; then
    info "enabling EPEL"
    if [[ $OS_ID == rhel ]]; then
      root dnf install -y -q "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_VERSION%%.*}.noarch.rpm"
    else
      root dnf install -y -q epel-release
    fi
  fi
  if ! dnf -q repolist --enabled 2>/dev/null | qgrep -iE '^(crb|powertools|codeready)'; then
    has crb && root crb enable
  fi
  return 0
}

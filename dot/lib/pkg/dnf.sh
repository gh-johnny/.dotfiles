# shellcheck shell=bash
# dnf (Fedora, RHEL, CentOS Stream, AlmaLinux, Rocky). The RHEL family gets EPEL + CRB first:
# half of a dev box (stow, neovim, fzf, ripgrep...) lives there.

be_missing() {
  local p
  for p; do rpm -q --whatprovides "$p" >/dev/null 2>&1 || echo "$p"; done
}
be_available() { dnf -q info "$1" >/dev/null 2>&1; }
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
  if ! dnf -q repolist --enabled 2>/dev/null | grep -qiE '^(crb|powertools|codeready)'; then
    has crb && root crb enable
  fi
  return 0
}

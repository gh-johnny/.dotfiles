# shellcheck shell=bash
# os: what are we running on? Sets OS_ID, OS_NAME, OS_VERSION, OS_PKG (the package backend),
# OS_INIT (systemd | openrc | runit | sysvinit | none), OS_INIT_LIVE (1 when that init is PID 1,
# 0 in a container), OS_LIBC (glibc | musl), OS_ARCH, OS_NIXOS.

# Distro → package backend. Derivatives not listed here resolve through ID_LIKE
# (Pop!_OS, Zorin, elementary, MX, Lubuntu... all say "ubuntu" or "debian").
os_backend_for() {
  case $1 in
    arch | archarm | endeavouros | manjaro | manjaro-arm | garuda | cachyos | artix | omarchy) echo pacman ;;
    debian | ubuntu | linuxmint | pop | elementary | zorin | kali | mx | raspbian | neon | devuan) echo apt ;;
    fedora | rhel | centos | almalinux | rocky | ol | nobara) echo dnf ;;
    opensuse* | sles | sled | suse) echo zypper ;;
    void) echo xbps ;;
    alpine | postmarketos) echo apk ;;
    gentoo | funtoo) echo emerge ;;
    slackware) echo slackpkg ;;
    nixos) echo nix ;;
    *) return 1 ;;
  esac
}

os_detect() {
  OS_ID='' OS_LIKE='' OS_NAME='' OS_VERSION=''
  if [[ -r /etc/os-release ]]; then
    eval "$(
      # shellcheck disable=SC1091
      . /etc/os-release
      printf 'OS_ID=%q OS_LIKE=%q OS_NAME=%q OS_VERSION=%q' \
        "${ID:-}" "${ID_LIKE:-}" "${PRETTY_NAME:-${NAME:-}}" "${VERSION_ID:-}"
    )"
  elif [[ -r /etc/slackware-version ]]; then
    OS_ID=slackware OS_NAME=$(</etc/slackware-version)
  fi
  OS_ID=${OS_ID,,}

  OS_PKG=${DOT_PKG:-}
  if [[ -z $OS_PKG ]]; then
    local id
    for id in $OS_ID $OS_LIKE; do
      OS_PKG=$(os_backend_for "${id,,}") && break
    done
  fi
  if [[ -z $OS_PKG ]]; then # unknown distro: go by what is installed
    local pm
    for pm in pacman:pacman apt-get:apt dnf:dnf zypper:zypper xbps-install:xbps apk:apk emerge:emerge slackpkg:slackpkg nix-env:nix; do
      has "${pm%%:*}" && { OS_PKG=${pm#*:}; break; }
    done
  fi

  OS_NIXOS=0
  [[ $OS_ID == nixos ]] && OS_NIXOS=1

  # Omarchy runs on Arch and leaves os-release alone; its checkout is the tell.
  OS_OMARCHY=0
  [[ -d $HOME/.local/share/omarchy ]] && OS_OMARCHY=1

  OS_INIT=none OS_INIT_LIVE=0
  local pid1
  pid1=$(cat /proc/1/comm 2>/dev/null || true)
  if [[ -d /run/systemd/system ]]; then OS_INIT=systemd OS_INIT_LIVE=1
  elif has openrc || has rc-update; then OS_INIT=openrc; [[ $pid1 == init && -d /run/openrc ]] && OS_INIT_LIVE=1
  elif [[ -d /etc/sv ]] && has sv; then OS_INIT=runit; [[ $pid1 == runit* ]] && OS_INIT_LIVE=1
  elif has systemctl; then OS_INIT=systemd
  elif [[ -d /etc/init.d || -d /etc/rc.d ]]; then OS_INIT=sysvinit; [[ $pid1 == init ]] && OS_INIT_LIVE=1
  fi

  OS_LIBC=glibc
  if compgen -G '/lib/ld-musl-*' >/dev/null || { has ldd && ldd --version 2>&1 | grep -qi musl; }; then
    OS_LIBC=musl
  fi
  OS_ARCH=$(uname -m)

  OS_CONTAINER=0
  if [[ -f /.dockerenv || -f /run/.containerenv ]] || grep -qaE 'docker|containerd|podman|lxc' /proc/1/cgroup 2>/dev/null; then
    OS_CONTAINER=1
  fi
}

os_summary() {
  printf '%s (%s) · pkg=%s · init=%s%s · %s/%s%s%s\n' \
    "${OS_NAME:-unknown}" "${OS_ID:-?}" "${OS_PKG:-none}" "$OS_INIT" \
    "$([[ $OS_INIT_LIVE == 1 ]] || echo ' (not running)')" "$OS_ARCH" "$OS_LIBC" \
    "$([[ $OS_OMARCHY == 1 ]] && echo ' · omarchy')" "$([[ $OS_CONTAINER == 1 ]] && echo ' · container')"
}

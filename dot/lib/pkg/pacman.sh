# shellcheck shell=bash
# pacman (Arch, EndeavourOS, Manjaro, Omarchy...). AUR packages go through aur_install.

be_missing()   { pacman -T "$@" 2>/dev/null; return 0; } # -T prints what is not satisfied, provides included
be_available() { pacman -Si "$1" >/dev/null 2>&1 || pacman -Sg "$1" >/dev/null 2>&1; }
be_stale()     { ! compgen -G '/var/lib/pacman/sync/*.db' >/dev/null; }
# A sync without the upgrade is a partial upgrade, which Arch does not support: refresh = -Syu.
be_refresh()   { root pacman -Syu --noconfirm; }
be_install()   { root pacman -S --needed --noconfirm "$@"; }
be_explicit()  { pacman -Qqe; }

aur_helper() {
  local h
  for h in yay paru; do has "$h" && { echo "$h"; return 0; }; done
  return 1
}

# aur_bootstrap: build yay-bin from the AUR (makepkg refuses to run as root).
aur_bootstrap() {
  aur_helper >/dev/null && return 0
  if [[ $EUID -eq 0 ]]; then warn "AUR needs a regular user (makepkg will not act as root)"; return 1; fi
  online aur.archlinux.org || { warn "aur.archlinux.org is unreachable"; return 1; }
  info "bootstrapping yay"
  be_install base-devel git || return 1
  local d="$DOT_RUN/yay-bin"
  act git clone --depth=1 --quiet https://aur.archlinux.org/yay-bin.git "$d" || return 1
  (cd "$d" && act makepkg -si --noconfirm)
}

# aur_install NAME...: through yay/paru; they ask for sudo themselves.
aur_install() {
  (($#)) || return 0
  aur_bootstrap || return 1
  act "$(aur_helper)" -S --needed --noconfirm "$@"
}

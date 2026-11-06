# shellcheck shell=bash
# The rest of the machine:
#   self      ~/.local/bin/dot → this checkout
#   omarchy   the Omarchy base (Arch only), installed before anything else touches ~/.config
#   flatpak   GUI apps from Flathub on distros where arch.list does not apply
#   shell     login shell, Powerlevel10k, tmux plugin manager + plugins
#   services  system/user units and user groups (manifest/services.list)
#   ssh       the SSH key the configs expect

# ── self ─────────────────────────────────────────────────────────────────────

mod_self_apply() {
  local link="$HOME/.local/bin/dot"
  [[ $(readlink -f "$link" 2>/dev/null) == "$(readlink -f "$DOT_ROOT/bin/dot")" ]] && return 0
  run mkdir -p "${link%/*}" && run ln -sfn "$DOT_ROOT/bin/dot" "$link"
}
mod_self_status() {
  if [[ $(readlink -f "$HOME/.local/bin/dot" 2>/dev/null) == "$(readlink -f "$DOT_ROOT/bin/dot")" ]]; then
    report ok "~/.local/bin/dot → ${DOT_ROOT/#$HOME/\~}/bin/dot"
  else report miss "~/.local/bin/dot"
  fi
}

# ── omarchy ──────────────────────────────────────────────────────────────────

OMARCHY_DIR="$HOME/.local/share/omarchy"

mod_omarchy_apply() {
  [[ $DOT_OMARCHY == 1 ]] || return 0
  [[ $OS_PKG == pacman && $OS_ID == arch ]] || { warn "omarchy only installs on Arch Linux (this is $OS_ID)"; return 0; }
  [[ -d $OMARCHY_DIR ]] && { ok "omarchy $(cat "$OMARCHY_DIR/version" 2>/dev/null) present"; return 0; }
  [[ $EUID -eq 0 ]] && { err "omarchy must be installed as your user, not root"; return 1; }
  warn "omarchy is not installed: its installer reconfigures the whole desktop (and reboots at the end)"
  confirm "Install omarchy now?" n || { warn "skipped omarchy"; return 0; }
  local f="$DOT_RUN/omarchy-install"
  fetch https://omarchy.org/install >"$f" || { err "omarchy download failed"; return 1; }
  run bash "$f"
}
mod_omarchy_status() {
  [[ $DOT_OMARCHY == 1 ]] || return 0
  if [[ -d $OMARCHY_DIR ]]; then report ok "omarchy $(cat "$OMARCHY_DIR/version" 2>/dev/null)"
  else report miss "omarchy"
  fi
}

# ── flatpak ──────────────────────────────────────────────────────────────────

_flatpak_wanted() {
  [[ $DOT_FLATPAK == 1 || ( $DOT_FLATPAK == auto && $OS_PKG != pacman ) ]] || return 0
  list_lines flatpak.list | awk 'NF {print $1}'
}

mod_flatpak_apply() {
  local want=() id missing=()
  mapfile -t want < <(_flatpak_wanted)
  ((${#want[@]})) || return 0
  if ! has flatpak; then pkg_install flatpak || return 1; hash -r; fi
  flatpak remotes --user 2>/dev/null | grep -q '^flathub' ||
    run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || return 1
  for id in "${want[@]}"; do flatpak info --user "$id" >/dev/null 2>&1 || missing+=("$id"); done
  ((${#missing[@]})) || { ok "flatpak: apps installed"; return 0; }
  run flatpak install --user -y --noninteractive flathub "${missing[@]}"
}
mod_flatpak_status() {
  local id
  for id in $(_flatpak_wanted); do
    if has flatpak && flatpak info --user "$id" >/dev/null 2>&1; then report ok "flatpak $id"
    else report miss "flatpak $id"
    fi
  done
}

# ── shell ────────────────────────────────────────────────────────────────────

P10K_DIR="$HOME/powerlevel10k"
TPM_DIR="$HOME/.tmux/plugins/tpm"

_login_shell() { getent passwd "$USER" 2>/dev/null | cut -d: -f7 || awk -F: -v u="$USER" '$1 == u {print $7}' /etc/passwd; }

mod_shell_apply() {
  local rc=0 want
  USER=${USER:-$(id -un)}
  want=$(command -v "$DOT_SHELL" 2>/dev/null)
  if [[ -z $want ]]; then err "$DOT_SHELL is not installed"; rc=1
  elif [[ $(_login_shell) != "$want" ]]; then
    if [[ $OS_NIXOS == 1 ]]; then warn "NixOS: set users.users.$USER.shell = pkgs.$DOT_SHELL in configuration.nix"
    else
      grep -qxF "$want" /etc/shells 2>/dev/null || root sh -c "echo '$want' >>/etc/shells"
      if has chsh; then root chsh -s "$want" "$USER" || rc=1
      elif has usermod; then root usermod -s "$want" "$USER" || rc=1
      else err "no chsh/usermod to make $DOT_SHELL the login shell"; rc=1
      fi
    fi
  fi
  if [[ $DOT_SHELL == zsh ]] && in_list zsh "${DOT_STOW[@]}"; then
    git_clone https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" || rc=1
  fi
  if in_list tmux "${DOT_STOW[@]}"; then
    # an empty dir is what a broken submodule used to leave behind
    [[ -d $TPM_DIR && -z $(ls -A "$TPM_DIR") ]] && run rmdir "$TPM_DIR"
    if git_clone https://github.com/tmux-plugins/tpm "$TPM_DIR"; then
      # install the plugins tmux.conf lists, without opening tmux
      if has tmux && [[ -x $TPM_DIR/bin/install_plugins ]] && _tmux_plugins_missing; then
        run "$TPM_DIR/bin/install_plugins" >/dev/null || rc=1
      fi
    else rc=1
    fi
  fi
  return $rc
}

_tmux_plugins_missing() {
  local p
  for p in $(sed -nE "s/^set -g @plugin '([^']+)'.*/\1/p" "$HOME/.tmux.conf" 2>/dev/null); do
    [[ -d $HOME/.tmux/plugins/${p##*/} ]] || return 0
  done
  return 1
}

mod_shell_status() {
  local want
  want=$(command -v "$DOT_SHELL" 2>/dev/null)
  if [[ -n $want && $(_login_shell) == "$want" ]]; then report ok "login shell $want"
  else report miss "login shell is $(_login_shell), want $DOT_SHELL"
  fi
  if [[ $DOT_SHELL == zsh ]] && in_list zsh "${DOT_STOW[@]}"; then
    [[ -f $P10K_DIR/powerlevel10k.zsh-theme ]] && report ok "powerlevel10k" || report miss "powerlevel10k (~/powerlevel10k)"
  fi
  if in_list tmux "${DOT_STOW[@]}"; then
    if [[ ! -x $TPM_DIR/tpm ]]; then report miss "tmux plugin manager (~/.tmux/plugins/tpm)"
    elif _tmux_plugins_missing; then report miss "tmux plugins (prefix + I, or dot apply)"
    else report ok "tmux plugins"
    fi
  fi
}

# ── services ─────────────────────────────────────────────────────────────────

# _svc_lines: "scope<TAB>name" for this init, alternate names resolved (KEY=VAL by backend).
_svc_lines() {
  local scope name rest kv
  while read -r scope name rest; do
    [[ -n $scope ]] || continue
    for kv in $rest; do [[ ${kv%%=*} == "$OS_PKG" ]] && name=${kv#*=}; done
    [[ $name == - ]] && continue
    printf '%s\t%s\n' "$scope" "$name"
  done < <(list_lines services.list)
}

_in_group() { id -nG "$USER" 2>/dev/null | tr ' ' '\n' | grep -qxF "$1"; }
_group_exists() { getent group "$1" >/dev/null 2>&1 || grep -q "^$1:" /etc/group; }

mod_services_apply() {
  # shellcheck disable=SC1090
  source "$DOT_ROOT/lib/init/$OS_INIT.sh"
  local scope name rc=0
  USER=${USER:-$(id -un)}
  while IFS=$'\t' read -r scope name; do
    case $scope in
      usergroup)
        [[ $EUID -eq 0 ]] && continue
        _group_exists "$name" || { debug "group $name does not exist"; continue; }
        _in_group "$name" && continue
        if has usermod; then root usermod -aG "$name" "$USER" || rc=1
        else root addgroup "$USER" "$name" || rc=1
        fi
        warn "added $USER to $name: takes effect at the next login"
        ;;
      system | user)
        [[ $OS_NIXOS == 1 && $scope == system ]] && { warn "NixOS: enable $name in configuration.nix"; continue; }
        svc_exists "$scope" "$name" || { debug "$scope unit $name is not installed"; continue; }
        svc_enabled "$scope" "$name" && continue
        svc_enable "$scope" "$name" || rc=1
        ;;
    esac
  done < <(_svc_lines)
  return $rc
}

mod_services_status() {
  # shellcheck disable=SC1090
  source "$DOT_ROOT/lib/init/$OS_INIT.sh"
  local scope name
  USER=${USER:-$(id -un)}
  while IFS=$'\t' read -r scope name; do
    case $scope in
      usergroup)
        [[ $EUID -eq 0 ]] && continue
        if ! _group_exists "$name"; then report skip "group $name (does not exist)"
        elif _in_group "$name"; then report ok "in group $name"
        else report miss "not in group $name"
        fi
        ;;
      *)
        if ! svc_exists "$scope" "$name"; then report skip "$scope $name (not installed)"
        elif svc_enabled "$scope" "$name"; then report ok "$scope $name enabled"
        else report miss "$scope $name not enabled"
        fi
        ;;
    esac
  done < <(_svc_lines)
}

# ── ssh ──────────────────────────────────────────────────────────────────────

mod_ssh_apply() {
  [[ -n $DOT_SSH_KEY ]] || return 0
  local key=${DOT_SSH_KEY/#\~/$HOME}
  [[ -d $HOME/.ssh ]] || run mkdir -p "$HOME/.ssh"
  [[ $(stat -c %a "$HOME/.ssh" 2>/dev/null) == 700 ]] || run chmod 700 "$HOME/.ssh"
  [[ -f $key ]] && return 0
  if [[ ! -t 0 || $DOT_YES == 1 ]]; then warn "no SSH key at $DOT_SSH_KEY: run dot apply --only ssh in a terminal to create it"; return 0; fi
  info "creating $DOT_SSH_KEY (you will be asked for a passphrase)"
  run ssh-keygen -t ed25519 -C "${DOT_SSH_KEY_COMMENT:-$USER@$(hostname)}" -f "$key" || return 1
  say; ok "add it to GitHub: https://github.com/settings/keys"; cat "$key.pub"
}
mod_ssh_status() {
  [[ -n $DOT_SSH_KEY ]] || return 0
  if [[ -f ${DOT_SSH_KEY/#\~/$HOME} ]]; then report ok "ssh key $DOT_SSH_KEY"; else report miss "ssh key $DOT_SSH_KEY"; fi
}

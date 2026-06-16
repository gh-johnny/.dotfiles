#!/usr/bin/env bash
# =============================================================================
# Dotfiles — setup.sh
# Arch Linux  ·  Hyprland / Wayland  (Omarchy-based)
#
# Run: bash ~/projects/dotfiles/setup.sh
#
# Stages:
#   1  Package manager bootstrap (pacman + yay)
#   2  Dotfiles (clone + stow)
#   3  Shell (zsh, Powerlevel10k, keychain)
#   4  Window manager  ← choose: Omarchy | bare Hyprland | X11/i3 (legacy)
#   5  Terminals
#   6  Editor (Neovim)
#   7  Multiplexer (tmux + TPM)
#   8  Fonts
#   9  Dev & CLI tools
#  10  Apps
#  11  SSH key
#  --  Post-install checklist
# =============================================================================

set -euo pipefail

# ── helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}→ $*${NC}"; }
ok()      { echo -e "${GREEN}✓ $*${NC}"; }
warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
section() { echo -e "\n${CYAN}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

# ── confirmation ──────────────────────────────────────────────────────────────
echo "This script makes significant changes to your system."
echo "Review the file before continuing: ~/projects/dotfiles/setup.sh"
echo
while true; do
    read -rp "Continue? [y/N] " ANSWER
    case "$ANSWER" in
        [Yy]) break ;;
        *) echo "Aborted."; exit 0 ;;
    esac
done

DOTFILES="$HOME/projects/dotfiles"
DOTFILES_PACKAGES=(
    alacritty autostart btop fastfetch git ghostty hypr
    kitty lazygit nvim ssh starship tmux walker waybar zsh
)

# =============================================================================
section "1 — Package manager"
# =============================================================================

info "Syncing pacman databases..."
sudo pacman -Syyy

info "Installing base build tools (required for yay)..."
sudo pacman -S --needed base-devel git

if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    git clone https://aur.archlinux.org/yay-git.git /tmp/yay-git
    (cd /tmp/yay-git && makepkg -si)
    rm -rf /tmp/yay-git
else
    ok "yay already installed"
fi

# =============================================================================
section "2 — Dotfiles"
# =============================================================================

sudo pacman -S --needed stow

if [[ ! -d "$DOTFILES" ]]; then
    info "Cloning dotfiles..."
    mkdir -p "$HOME/projects"
    git clone git@github.com:gh-johnny/.dotfiles.git "$DOTFILES"
else
    ok "Dotfiles already cloned at $DOTFILES"
fi

info "Stowing packages..."
stow --dir="$DOTFILES" --target="$HOME" "${DOTFILES_PACKAGES[@]}"

# =============================================================================
section "3 — Shell"
# =============================================================================

sudo pacman -S --needed zsh keychain

info "Setting zsh as default shell..."
chsh -s /usr/bin/zsh

if [[ ! -d "$HOME/powerlevel10k" ]]; then
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/powerlevel10k"
else
    ok "Powerlevel10k already installed"
fi

# =============================================================================
section "4 — Window manager"
# =============================================================================

echo "Which WM setup do you want to install?"
echo "  1) Omarchy          (recommended — full curated Wayland/Hyprland experience)"
echo "  2) Bare Hyprland    (manual install, no omarchy layer)"
echo "  3) X11 / i3         (legacy — see archive/ for the old configs)"
echo "  4) Skip"
read -rp "Choice [1]: " WM_CHOICE
WM_CHOICE="${WM_CHOICE:-1}"

case "$WM_CHOICE" in
    1)
        # Omarchy — https://omarchy.org
        # Installs hyprland, hypridle, hyprlock, hyprsunset, waybar, walker,
        # ghostty, mako, uwsm, xdg-terminal-exec, fonts, icons, and more.
        if [[ ! -d "$HOME/.local/share/omarchy" ]]; then
            info "Cloning and installing Omarchy..."
            git clone https://github.com/basecamp/omarchy.git "$HOME/.local/share/omarchy"
            bash "$HOME/.local/share/omarchy/install.sh"
        else
            ok "Omarchy already installed"
        fi
        ;;

    2)
        # Bare Hyprland — manual Wayland stack without omarchy
        info "Installing bare Hyprland/Wayland stack..."
        sudo pacman -S --needed \
            hyprland hypridle hyprlock hyprsunset \
            hyprland-preview-share-picker \
            xdg-desktop-portal-hyprland \
            uwsm xdg-terminal-exec \
            waybar \
            mako libnotify \
            brightnessctl \
            jq

        yay -S --needed walker-bin
        ;;

    3)
        # X11 / i3 — legacy stack, kept for reference
        # Configs live in archive/ — they are NOT stowed in the default setup.
        warn "Installing legacy X11/i3 stack. Configs are in archive/."
        sudo pacman -S --needed \
            xorg i3 i3lock \
            rofi polybar \
            dunst libnotify \
            nitrogen \
            sxhkd \
            acpi \
            flameshot

        yay -S --needed brillo picom-git
        ;;

    4) info "Skipping WM install." ;;
esac

# =============================================================================
section "5 — Terminals"
# =============================================================================

# ghostty and alacritty are in the official repos.
# kitty is not — uncomment the yay line below if you want it.
sudo pacman -S --needed ghostty alacritty

# yay -S --needed kitty

# =============================================================================
section "6 — Editor"
# =============================================================================

sudo pacman -S --needed neovim

# =============================================================================
section "7 — Multiplexer"
# =============================================================================

sudo pacman -S --needed tmux

if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    info "Installing Tmux Plugin Manager (TPM)..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
    ok "TPM already installed"
fi

warn "After first tmux launch, press <prefix> + I to install plugins."

# =============================================================================
section "8 — Fonts"
# =============================================================================

sudo pacman -S --needed \
    ttf-jetbrains-mono-nerd \
    noto-fonts-emoji

# =============================================================================
section "9 — Dev & CLI tools"
# =============================================================================

sudo pacman -S --needed \
    ripgrep fd fzf jq \
    lazygit btop fastfetch

yay -S --needed lazydocker

# =============================================================================
section "10 — Apps"
# =============================================================================

sudo pacman -S --needed \
    nautilus \
    signal-desktop \
    obsidian \
    spotify \
    pamixer pavucontrol pipewire wireplumber

yay -S --needed \
    typora \
    slack-desktop \
    1password \
    1password-cli

# =============================================================================
section "11 — SSH key"
# =============================================================================

if [[ ! -f "$HOME/.ssh/gh" ]]; then
    info "Generating SSH key for GitHub (~/.ssh/gh)..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "jmfurtadoromero@gmail.com" -f "$HOME/.ssh/gh"
    echo
    ok "Key generated. Add the public key to https://github.com/settings/keys"
    echo
    cat "$HOME/.ssh/gh.pub"
    echo
else
    ok "SSH key ~/.ssh/gh already exists"
fi

# =============================================================================
section "Done — manual steps remaining"
# =============================================================================

echo "  [ ] pnpm         curl -fsSL https://get.pnpm.io/install.sh | sh -"
echo "  [ ] bun          curl -fsSL https://bun.sh/install | bash"
echo "  [ ] Android SDK  install via Android Studio or sdkmanager"
echo "  [ ] Neovim       open nvim → :Lazy sync"
echo "  [ ] tmux plugins tmux, then <prefix> + I"
echo "  [ ] p10k         run 'p10k configure' or let .p10k.zsh load automatically"
echo "  [ ] GitHub SSH   add ~/.ssh/gh.pub to https://github.com/settings/keys"
echo "  [ ] Reboot       to start the Hyprland / UWSM session"

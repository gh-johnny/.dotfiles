# dotfiles

Personal dotfiles for Arch Linux + Hyprland, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Stack

| Layer | Tool |
|---|---|
| OS | Arch Linux |
| WM | Hyprland (Wayland) |
| Terminal | Alacritty / Ghostty / Kitty |
| Shell | Zsh + Powerlevel10k |
| Editor | Neovim |
| Bar | Waybar |
| Launcher | Walker |
| Multiplexer | Tmux |
| Notifications | Mako (omarchy-managed) |
| Theme system | [omarchy](https://github.com/basecamp/omarchy) |

## Structure

Each top-level directory is a stow package. Its internal path mirrors `$HOME`, so stow can symlink it correctly.

```
dotfiles/
├── alacritty/    → ~/.config/alacritty/
├── autostart/    → ~/.config/autostart/
├── btop/         → ~/.config/btop/
├── fastfetch/    → ~/.config/fastfetch/
├── git/          → ~/.config/git/
├── ghostty/      → ~/.config/ghostty/
├── hypr/         → ~/.config/hypr/
├── kitty/        → ~/.config/kitty/
├── lazygit/      → ~/.config/lazygit/
├── nvim/         → ~/.config/nvim/
├── ssh/          → ~/.ssh/config
├── starship/     → ~/.config/starship.toml
├── tmux/         → ~/.tmux.conf
├── walker/       → ~/.config/walker/
├── waybar/       → ~/.config/waybar/
├── zsh/          → ~/.zshrc, ~/.p10k.zsh
└── archive/      (old X11/i3 configs — not stowed)
```

## Fresh machine setup

Run the guided setup script — it handles everything in order:

```bash
bash ~/projects/dotfiles/setup.sh
```

Or manually, step by step:

```bash
# 1. Install yay (AUR helper)
sudo pacman -S --needed base-devel git
git clone https://aur.archlinux.org/yay-git.git /tmp/yay-git && (cd /tmp/yay-git && makepkg -si)

# 2. Clone the repo
git clone git@github.com:gh-johnny/.dotfiles.git ~/projects/dotfiles

# 3. Install stow and link all packages (archive/ excluded — legacy X11/i3 configs)
sudo pacman -S stow
stow --dir=~/projects/dotfiles --target=$HOME --ignore='^archive$' */

# 4. Set zsh as default shell + install Powerlevel10k
sudo pacman -S zsh keychain
chsh -s /usr/bin/zsh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k

# 5. Install Omarchy (Hyprland/Wayland experience)
git clone https://github.com/basecamp/omarchy.git ~/.local/share/omarchy
bash ~/.local/share/omarchy/install.sh

# 6. Clone TPM for tmux plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Then inside tmux: <prefix> + I to install plugins
```

> See `setup.sh` for the full staged install including terminals, fonts, dev tools, and apps. `mako` is managed by omarchy — do not stow it.

## Day-to-day workflow

Since every config is a symlink into this repo, editing any config file **directly edits the repo**. Just commit after making changes:

```bash
cd ~/projects/dotfiles
git add -p
git commit
```

### Adding a new package

```bash
# 1. Create the stow structure
mkdir -p ~/projects/dotfiles/<pkg>/.config/<pkg>/

# 2. Move the existing real file/dir out of home
mv ~/.config/<pkg> ~/.config/<pkg>.bak

# 3. Copy it into the dotfiles package
cp -a ~/.config/<pkg>.bak/. ~/projects/dotfiles/<pkg>/.config/<pkg>/

# 4. Stow
stow --dir=~/projects/dotfiles --target=$HOME <pkg>

# 5. Verify it's a symlink, then remove the backup
ls -la ~/.config/<pkg>
```

### SSH key setup (first boot)

```bash
ssh-add ~/.ssh/gh   # enter passphrase once; keychain handles the rest
```

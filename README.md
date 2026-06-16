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

```bash
# 1. Install dependencies
sudo pacman -S stow zsh neovim alacritty tmux keychain

# 2. Clone the repo
git clone git@github.com:gh-johnny/dotfiles.git ~/projects/dotfiles

# 3. Stow all packages
stow --dir=~/projects/dotfiles --target=$HOME */

# 4. Set zsh as default shell
chsh -s /usr/bin/zsh

# 5. Install Powerlevel10k
yay -S zsh-theme-powerlevel10k-git
```

> **Note:** `mako` is not a stow package — its config is managed by omarchy. Install omarchy separately.

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

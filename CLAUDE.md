# Dotfiles — CLAUDE.md

## What this repo is

Stow-based dotfiles for an Arch Linux + Hyprland machine. The repo lives at `~/projects/dotfiles` and is the **single source of truth** for all config files. Each directory is a stow package; stow creates symlinks from `$HOME` into the package.

## Package map

| Package | Stow target |
|---|---|
| `alacritty` | `~/.config/alacritty/` |
| `autostart` | `~/.config/autostart/` |
| `btop` | `~/.config/btop/` |
| `fastfetch` | `~/.config/fastfetch/` |
| `git` | `~/.config/git/` |
| `ghostty` | `~/.config/ghostty/` |
| `hypr` | `~/.config/hypr/` |
| `kitty` | `~/.config/kitty/` |
| `lazygit` | `~/.config/lazygit/` |
| `nvim` | `~/.config/nvim/` |
| `ssh` | `~/.ssh/config` |
| `starship` | `~/.config/starship.toml` |
| `tmux` | `~/.tmux.conf` |
| `walker` | `~/.config/walker/` |
| `waybar` | `~/.config/waybar/` |
| `zsh` | `~/.zshrc`, `~/.p10k.zsh` |

`archive/` holds old X11/i3 packages — not stowed, kept for reference.

**This table must always reflect reality.** When a package is added, removed, or its target changes, update it immediately — re-mapping is always correct and expected.

## Stow commands

```bash
# Stow a single package
stow --dir=~/projects/dotfiles --target=$HOME <package>

# Stow everything at once (archive/ is excluded — it holds legacy X11/i3 configs)
stow --dir=~/projects/dotfiles --target=$HOME --ignore='^archive$' */

# Unstow
stow --dir=~/projects/dotfiles --target=$HOME -D <package>
```

## Adding a new package

1. Create `<package>/<stow-mirror-path>/` inside this repo.
   Example: `ghostty/.config/ghostty/config`
2. Move the real file out of `$HOME` (otherwise stow conflicts).
3. Run `stow --dir=~/projects/dotfiles --target=$HOME <package>`.
4. Commit.

## Key rules

- **Dotfiles is source of truth.** Never edit config files directly on the machine unless you immediately commit the change here too. Since every file is a symlink into this repo, editing via any editor already edits the repo.
- **README.md and setup.sh must always reflect reality.** When a package is added/removed, a tool changes, or the setup process shifts, update both files immediately — they are living documents, not snapshots.
- `mako` is managed by omarchy (`~/.config/omarchy/`). Do not stow it.
- `nvim` has no standalone git repo anymore — this is the only copy.
- `btop/themes/current.theme` is a symlink to omarchy's theme — that is intentional.

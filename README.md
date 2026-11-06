# dotfiles

Personal dotfiles for Arch Linux + Hyprland, managed with [GNU Stow](https://www.gnu.org/software/stow/),
and **`dot`**: the tool that sets up a machine from them on any Linux (Arch, Debian/Ubuntu and
derivatives, Fedora/RHEL, openSUSE, Void, Alpine, Gentoo, Slackware, NixOS). See [`dot/README.md`](dot/README.md).

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
├── mako/         → ~/.config/mako/config
├── mise/         → ~/.config/mise/config.toml (stowed --no-folding: dot writes conf.d/ beside it)
├── nvim/         → ~/.config/nvim/
├── ssh/          → ~/.ssh/config
├── starship/     → ~/.config/starship.toml
├── tmux/         → ~/.tmux.conf
├── walker/       → ~/.config/walker/
├── waybar/       → ~/.config/waybar/
├── zsh/          → ~/.zshrc, ~/.p10k.zsh
├── dot/          (the setup tool — not stowed)
├── install.sh    (bootstrap: bash + git + curl, the checkout, then dot apply)
├── bifrost/      (my ignore rules for bifrost sync — not stowed)
├── vps/          (the VPS's ~/.zshrc and `ai` wrapper — not stowed, see below)
└── archive/      (old X11/i3 configs — not stowed)
```

## Fresh machine setup

```bash
# from nothing (any distro): pick the profile with --host, or get asked
curl -fsSL https://raw.githubusercontent.com/gh-johnny/.dotfiles/main/install.sh | sh -s -- --host pc

# or from a checkout
bash ~/projects/dotfiles/install.sh --host pc
```

Profiles: `cli` (terminal only, any distro), `dev`, `desktop`, `pc` (this Arch + Omarchy PC),
`vps`. After the first run `dot` is on PATH: `dot status` shows drift, `dot apply` fixes it,
`dot capture` lists packages installed by hand that no list knows about. Everything else:
[`dot/README.md`](dot/README.md).

Left manual on purpose: adding `~/.ssh/gh.pub` to GitHub, `ssh-add ~/.ssh/gh` once, and
rebooting into the Hyprland session after Omarchy's first install.

## Day-to-day workflow

Since every config is a symlink into this repo, editing any config file **directly edits the repo**. Just commit after making changes:

```bash
cd ~/projects/dotfiles
git add -p
git commit
```

### Installing something new

Add it to the right list in `dot/manifest/` (or run `dot capture` later to find what you forgot),
then `dot apply`. A new stow package also goes into a host's `DOT_STOW`.

### Adding a new stow package

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

## Sync between hosts (bifrost)

`~/projects` is mirrored continuously between my hosts with
bifrost (Syncthing over Tailscale, my own tool, in its own repo): untracked files,
`.env`, `.git`, worktrees and the Claude Code / Codex sessions travel too. The tool, its install,
its tests and the runbook live in `~/projects/bifrost`; this repo only keeps my personal pieces:

| Here | What it is |
|---|---|
| `bifrost/stignore` | my ignore rules for `~/projects` (includes bifrost's `generic` profile). Each host's bifrost settings point at it with `ignore_include=dotfiles/bifrost/stignore`. It syncs, so an edit reaches every host |
| `vps/` | the VPS's minimal `~/.zshrc` (runs `bifrost ready` at SSH login) and its `ai` wrapper. `bash vps/install.sh` on the VPS installs them (a copy: a symlink breaks the launcher's repo-root detection) |
| `zsh/.zshrc` | the `ai()` function runs `bifrost ready` before launching an agent |
| `git/.config/git/config` | `core.checkStat=minimal`, `core.trustctime=false`, `gc.worktreePruneExpire=never`, so an index synced from another host stays valid and no host prunes another host's worktrees |

Rule when editing `bifrost/stignore`: whatever git *tracks* must sync, or it shows up as deleted
on the other host. Carve tracked files out with a `!` exception placed before the pattern that would
hide them. Changing the rules makes Syncthing rescan the whole folder (minutes).

Day to day: `bifrost wait` on the host you are leaving; the host you arrive on runs
`bifrost ready` by itself. Everything else (health checks, backups, recovery, adding or
replacing a host, the VPS's public-SSH guard): `~/projects/bifrost/README.md` and `RUNBOOK.md`.

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
├── psync/        → ~/.local/bin/psync, ~/.config/psync/, systemd user timer
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

## Sync between hosts (psync)

`~/projects` is mirrored continuously between the PC and the VPS with
[Syncthing](https://syncthing.net), both hosts always on as peers. Everything
travels, including untracked files, `.env`, `.git`, worktrees and harness chat
history (Claude Code and Codex sessions live inside `ai-agents/agents/*`).
Both hosts use the same absolute paths (`/home/jo/...`), so worktree `gitdir:`
links and Claude Code's per-path session folders work unchanged.

```bash
psync status      # peers, pending changes, conflicts (exit 1 if not in sync)
psync wait        # block until every peer has everything — run before shutting the PC down
psync conflicts   # list *.sync-conflict-* files
psync pause       # stop syncing on this host (stays paused across reboots)
psync resume      # start again, picks up where it stopped
```

On the PC a user timer (`psync-check.timer`) raises a desktop notification for
new conflicts, folder errors or a peer disconnected for over an hour.

**What stays per host** (`psync/.config/psync/stignore`, synced, applies everywhere):
dependencies and build caches (`node_modules`, `.venv`, `target`, `.terraform`, …,
rebuilt natively — the VPS is ARM), git lock files, SQLite `-wal/-shm` files, logins
(`.credentials.json`, Codex `auth.json`) and live runtime state of the harnesses,
including Codex's `*.sqlite`, claude-mem databases and gitignored `.runtime/` dirs.
Rule when editing the ignore file: whatever git *tracks* must sync, or it shows up as
deleted on the other host — carve tracked files out with a `!` exception placed
before the pattern that would hide them.

**Working on both hosts at once:** safe as long as each repo checkout is written by
one host at a time — give the VPS agent its own worktree and branch. Two hosts
writing the same file produce a `*.sync-conflict-*` copy (nothing is lost; the
newer edit wins). Files replaced or deleted by the other host are kept for 30 days
in `~/projects/.stversions`.

The git package sets `core.checkStat=minimal`, `core.trustctime=false` and
`gc.worktreePruneExpire=never` so synced indexes stay valid and no host prunes
another host's worktrees.

### Pairing a new host

```bash
# 1. Same user name and home path as the PC (/home/jo); Syncthing ≥ 2, jq, curl, stow.
# 2. Copy the psync package before the first sync (the ignore file must exist):
tar -C ~/projects -cf - dotfiles/psync | ssh NEWHOST 'mkdir -p ~/projects ~/.local/bin ~/.config/systemd/user && tar -C ~/projects -xpf -'
# 3. On the new host (it dials the PC; tailnet ACL only allows connections towards the PC):
stow --no-folding --dir=~/projects/dotfiles --target=$HOME psync
psync setup --peer-id <PC device ID> --peer-name pc --peer-address tcp://<PC tailscale IP>:22000 --listen tcp://127.0.0.1:22000
# 4. On the PC, accept it:
psync setup --peer-id <new host device ID> --peer-name <name>
```

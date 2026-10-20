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
psync ready       # the other direction: wait briefly until THIS host has caught up (never fails)
psync conflicts   # list *.sync-conflict-* files
psync pause       # stop syncing on this host (stays paused across reboots)
psync resume      # start again, picks up where it stopped
psync doctor      # health check of this host (--roundtrip also sends a canary file to the peers)
```

Run `psync doctor --roundtrip` on both hosts after changing anything psync-related, and
`bash psync/tests/run.sh` (about 45 checks against a fake Syncthing, no side effects). What to do
when something looks wrong, how to recover data, and how to rebuild either host:
[`psync/RUNBOOK.md`](psync/RUNBOOK.md).

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

**Switching hosts inside one repo:** `psync wait` on the host you are leaving; the host
you arrive on runs `psync ready` by itself (the `ai` function in `zsh/.zshrc`, and an SSH
login hook in the VPS `~/.zshrc`). `ready` is instant when nothing is pending, waits up to
a minute while the other host's changes are still arriving, and warns when that host is
offline. It cannot see edits the other host made in the last ~10s or while it is
offline/asleep, so `psync wait` before leaving stays the one manual step. A commit's refs can arrive
a few seconds before its objects and `.git/index` after both, and running git on the
other host in that window (even `git status`, which rewrites the index) makes an older
index win the sync. The result is only a stale index, never lost commits: fix it with
`git read-tree HEAD` (index only, working tree untouched) once `psync status` says in
sync. `psync check` parks the losing `index.sync-conflict-*` copies automatically.
After every Syncthing (re)start `psync check` requests one extra full rescan, because
edits made during the startup scan are not seen by the filesystem watcher.

The git package sets `core.checkStat=minimal`, `core.trustctime=false` and
`gc.worktreePruneExpire=never` so synced indexes stay valid and no host prunes
another host's worktrees.

### Backups (restic, VPS)

Sync is not a backup: a deletion or a bad overwrite travels to the other host. Beyond the
30-day `.stversions`, the VPS keeps restic snapshots of `~/projects` (deduplicated and
compressed, about the size of the project data plus its churn) every day at 04:30 BRT.
Kept: 7 daily, 4 weekly and 6 monthly. A run refuses to start with less than 30 GB free.

```bash
psync backup status                     # snapshots, repository size, free disk, last result
psync backup                            # snapshot now (the timer runs the same)
psync backup restic ls latest <path>    # any restic command against the repository
psync backup restic restore latest --target /tmp/restore --include /home/jo/projects/<dir>
```

The repository (`~/.local/share/psync-backup/repo`) and its password
(`~/.local/state/psync/backup-password`) stay outside `~/projects`, so they never sync.
Copy the password somewhere safe: without it the snapshots cannot be opened. What is
excluded is in `psync/.config/psync/backup-excludes` (caches, dependencies, logins). A failed
or overdue backup shows up as a line in `psync ready`, i.e. at every SSH login to the VPS.
To make another host take backups too: install restic and run `psync backup setup` there.

### VPS: public SSH is closed

The VPS holds a copy of every project, `.env` files included, so its only way in is the
tailnet: the public `tcp/22` rule is gone from `/etc/iptables/rules.v4` and from the live
firewall. Use `ssh jo@100.90.235.90` (Tailscale SSH, re-approved in the browser every 12h).
`psync-ssh-guard.timer` (root, every minute, script `/usr/local/sbin/psync-ssh-guard`) is the
way back in: if Tailscale is not `Running` for 5 minutes (stopped, node key expired) it reopens
`tcp/22`, and it closes it again once Tailscale is back. The Tailscale node key of the VPS
expires on 2027-04-04: turn key expiry off for that machine in the Tailscale admin console.

The guard, its units and the VPS shell hook are kept in `psync/vps/` (`install.sh user` / `sudo
install.sh root` put them back on a rebuilt VPS; stow does not link that directory).

Undo it: `sudo systemctl disable --now psync-ssh-guard.timer` and
`sudo iptables -I INPUT 1 -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT`. The
pre-change firewall is kept in `/root/psync-fw-backup` (`rules.v4`, `v4.dump`). `rpcbind` (port 111,
unused) is disabled. The OCI security list was not touched: it is a second layer you can
tighten in the console.

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

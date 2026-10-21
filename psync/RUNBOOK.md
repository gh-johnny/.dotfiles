# psync runbook

How to operate psync and what to do when something is off. The design and the commands live in
the README ("Sync between hosts"); this file is organised by situation. Two hosts: the **PC**
(Arch, notebook) and the **VPS** (Oracle ARM, Ubuntu; users `ubuntu` with sudo, and `jo`, the one
that syncs). Both are on the tailnet and both keep a full copy of `~/projects`.

## Day to day

| You are | Do |
|---|---|
| leaving a host for the other | `psync wait` (the one manual step) |
| arriving on a host | nothing: `psync ready` runs by itself in the `ai` launcher and at SSH login |
| changed anything psync-related | `bash ~/projects/dotfiles/psync/tests/run.sh` (and `tests/mesh.sh` if it touches pairing or hosts), then `psync doctor --roundtrip` on **every** host |
| want to see who is in the mesh | `psync hosts` |
| adding, replacing or removing a host | "Adding or replacing a host" below |
| want Claude or Codex sessions (or any other directory) on the other host too | "Syncing more folders" below |
| curious whether all is well | `psync doctor` (read-only, instant) |

`psync doctor` prints `ok` / `warn` / `FAIL` per check and exits 1 only on FAIL. A warn is something
that comes and goes (a peer asleep, edits still travelling) or a date to act on; a FAIL stays broken
until someone fixes it. `--roundtrip` also writes a canary file in every synced folder and waits (up to
90s per folder) until every connected peer that has the folder reports having it, which covers scan,
announce, transfer and the ignore rules in one go. It is removed afterwards.

Every command acts on all the folders the host syncs (`psync folders`). With more than one, the lines
of `status` and `doctor` start with `[folder]`; with one they look as they always did.

## Something looks wrong

| Symptom | Cause | Do |
|---|---|---|
| `psync status` says NOT in sync right after an edit or commit | the change is still travelling, or the folder is rescanning (state `scanning`, about 6 min after Syncthing starts or any folder config change) | `psync wait` |
| a peer is DISCONNECTED | that host is asleep, offline, or Tailscale is down on either side. The VPS dials the PC (`tcp/22000` over the tailnet), so a sleeping PC shows up as VPS disconnected | wake it; `tailscale status` on both; `systemctl --user status syncthing`. Edits made on the offline host wait there and arrive when it is back |
| `*.sync-conflict-*` files | both hosts changed the same file before syncing. The newer edit won, the other is kept next to it | `psync conflicts`, diff the pair, keep what you want, delete the copy you do not |
| `git`: bad object, missing commit, or an old index right after switching hosts | refs can arrive before their objects, and `.git/index` after both; running git on the other host in that window (even `git status`) makes the old index win | stop touching git, `psync wait`, then `git read-tree HEAD` if the index is stale (index only, working tree untouched). Never lost commits |
| `psync check` parked a git index conflict | two hosts ran `git status` in one repo at once | nothing; copies sit in `~/.local/state/psync/index-conflicts` for 7 days |
| `folder error(s)` in status | Syncthing could not read or write something | `journalctl --user -u syncthing -n 50` |
| `[claude] pc connected, but has not added this folder` | sharing a folder is opt-in on each host and that host has not run `psync folder add` for it. Not an error: nothing is waiting for it, doctor only warns | run the same `psync folder add` there, or `psync folder remove` here if you do not want it |
| `psync ready` prints "last backup FAILED" or "no successful backup for over 36h" | the VPS timer failed or did not run | `psync backup status`; most often disk below 30GB free; `psync backup` to retry |
| doctor: tailscale node key expires in N days | the node key has an expiry | Tailscale admin console, that machine, disable key expiry (or re-authenticate before the date) |
| SSH to the VPS prints an approval URL | Tailscale SSH re-checks every 12 hours | open it in a browser, approve |
| a host was paused on purpose | `psync pause` survives reboots | `psync resume` |

## Recovering data

Sync copies deletions too, so there are two safety nets.

**A file replaced or deleted in the last 30 days.** Syncthing keeps the old copy on the host that
received the change: `~/projects/.stversions/<same path>~YYYYMMDD-HHMMSS.<ext>`. Look on both hosts
(`find ~/projects/.stversions -name '*<name>*'`); the host where the delete or edit was made does
not have it, the other one does. Copy it back out. Folders added with `psync folder add` keep one copy
of each replaced or deleted file for 30 days outside the folder, in
`~/.local/state/psync/versions/<folder>/<same path>`.

**Anything older, or a whole folder.** restic snapshots on the VPS (daily 04:30 BRT; 7 daily,
4 weekly, 6 monthly):

```bash
psync backup status
psync backup restic ls latest /home/jo/projects/<dir>
psync backup restic restore latest --target /tmp/restore --include /home/jo/projects/<dir>
# inspect /tmp/restore/home/jo/projects/<dir>, then copy back what you need
```

Restoring was tried on 2026-10-20: 172 files came back identical to the live ones. Check the
repository now and then with `psync backup restic check --read-data-subset=5%`. The password is
`~jo/.local/state/psync/backup-password` on the VPS; keep a copy in your password manager. Without
it the snapshots cannot be opened, and there is no recovery: start a new repository
(`psync backup setup` after moving the old one away).

## Locked out of the VPS

1. Normal way in: `ssh jo@<vps tailscale address>` (Tailscale SSH, approval every 12h).
2. If Tailscale is down on the VPS for 5 minutes, `psync-ssh-guard` reopens public `tcp/22`
   (`journalctl -t psync-ssh-guard`). `jo` has no `authorized_keys` there, so go in as `ubuntu`
   (key in `/home/ubuntu/.ssh/authorized_keys`, never delete it) and `sudo -iu jo`:
   `ssh -i ~/.ssh/vps-oracle ubuntu@<public address from the OCI console>`. That key has a
   passphrase, so load it first with `ssh-add ~/.ssh/vps-oracle` in a real terminal; without it the
   emergency door is shut. Bring Tailscale back (`sudo systemctl start tailscaled`, or
   `sudo tailscale up` if it asks to log in) and the guard closes the port again within a minute.
3. Exercised for real on 2026-10-20: `systemctl stop tailscaled` on the VPS, the port opened 7 min
   after the drop, the `ubuntu` login worked with the host key pinned, and after
   `systemctl start tailscaled` the guard closed the port within 10s and Tailscale SSH worked again
   without a new approval (the OCI Security List lets tcp/22 through). `tests/run.sh` also covers the
   guard logic with a fake `tailscale` and firewall. Still unproven: getting in through the OCI
   console (`ubuntu` has no password).

## Adding or replacing a host

The mesh is symmetric: every host is a full peer holding a complete copy, so any one of them can be
lost or swapped and the others carry on. `bash psync/tests/mesh.sh` proves it with real Syncthing in
four sandboxes: pairing through one host, files crossing it, a direct link surviving that host going
down, a replacement receiving everything from the survivors, and removal. Every host needs the same
user name and home path (worktree `gitdir:` links and Claude Code's per-path session folders depend on
it).

1. **Prepare the host** (Debian, Ubuntu or Arch, as the sync user). Copy the `psync` package over and run
   `bash ~/projects/dotfiles/psync/install.sh` (`--plan` first if you want to see it; `--with-backup`
   adds restic). It installs Syncthing 2 (the Debian/Ubuntu archives still carry 1.x, so it adds the
   official `stable-v2` apt repository), `jq`, `curl`, `stow`, `git`, links the package and enables
   linger. Tested for real on a clean Ubuntu with `bash psync/tests/install-docker.sh`.
2. **Join through one host that is already in:** on the new host,
   `psync setup --peer-id <its ID> --peer-name <name> --peer-address tcp://<its address>:22000 --listen tcp://127.0.0.1:22000`
   (it prints the new host's own ID; use `--listen tcp://:22000` on a host the others should dial).
3. **Accept it there:** on the host you joined through, `psync add-host --id <new ID> --name <new name>`.
   Peers are introducers by default (they are all yours), so the other hosts learn the new one and share
   the folder with it by themselves. Syncthing then rescans the folder, which takes minutes on a large one.
4. **Hosts that should still sync when the introducer is off** need each other's address, because
   Syncthing does not pass addresses along and psync switches discovery off:
   `psync add-host --id <ID> --name <name> --address tcp://<address>:22000` on both. `psync hosts` shows
   which are reached "through" another host and which directly.
5. **Check:** `psync hosts` (everyone connected, 100%), then `psync doctor --roundtrip` on each host.
6. **Replacing a host:** do 1 to 5 for the new one first and wait until `psync hosts` shows it at 100%.
   Then `psync remove-host <old name> --yes` on the hosts that knew it; hosts that took the removed host
   as their introducer drop it on their own. The files on the removed host stay there.

Backups are per host: give every host that should keep its own history `psync backup setup` (and save
each password separately). Two independent repositories do not depend on each other. They cover
`~/projects` only, not the folders added below.

## Syncing more folders

`psync setup` creates the base folder, `projects`. Anything else is a folder of its own, added on
every host that should have it:

```bash
psync folders                       # what this host syncs, its state, how many hosts share it
psync folder add --preset claude    # Claude Code sessions and memory: $CLAUDE_CONFIG_DIR or ~/.claude, then projects/
psync folder add --preset codex     # Codex sessions: $CODEX_HOME or ~/.codex, then sessions/
psync folder add notes ~/notes      # any other directory: ID, then an absolute path
psync folder remove claude          # stop syncing it on this host (the files stay)
```

- **Opt-in on each host.** A folder syncs between the hosts that have added it. `folder add` shares
  it with every host this one knows, and `add-host` shares every folder with a new host, so the order
  in which the hosts add it does not matter. A host that has not added it yet only holds an offer.
- **Only the session directories**, never the config directory around them, so `.credentials.json`,
  `auth.json` and the app databases cannot travel. If `CLAUDE_CONFIG_DIR` or `CODEX_HOME` already lives
  inside a synced folder (it does for the PC and VPS: they sit inside `~/projects`), the preset says so
  and refuses: those sessions already sync with `projects`.
- **Same absolute path on every host**, as for `projects`: Claude Code names a session folder after the
  working directory. Folders cannot nest, so psync refuses a path inside another folder or containing one.
- **Old versions** go to a trashcan outside the folder (see "Recovering data"), not to a `.stversions`
  inside it: a harness finds and resumes sessions by scanning its directory, and a transcript that grows
  all day would be archived over and over.
- **Transcripts hold whatever was typed or printed in the chat**, `.env` contents and tokens included.
  They go to every host that adds the folder: only hosts you own.
- Checked with real Syncthing by `tests/mesh.sh`. Not yet tried end to end with `claude --resume` and
  `codex resume` on a host that is not the PC or the VPS: do that after the first sync of a new setup.

## Rebuild the VPS from nothing

The PC still has every file, so only the restic history (which lives only on the VPS) is lost.

1. New Ubuntu instance. Create user `jo` (same name and home path as the PC: worktree `gitdir:`
   links and Claude Code's per-path session folders depend on `/home/jo`).
2. Copy the `psync` package over and run `install.sh --with-backup` as `jo` (see "Adding or replacing a
   host", step 1): it installs Syncthing 2, `restic`, `jq`, `stow`, `git`, `curl`, links the package and
   enables linger. Then install by hand what it does not handle: `zsh`, `tmux`, `neovim`, `nodejs`,
   `npm`, `iptables-persistent`, `gh` and `tailscale`. Join the tailnet with SSH enabled, approve the
   node, **disable key expiry** for it.
3. Install Claude Code and Codex for `jo`, then log in to Claude, Codex and `gh` **on the VPS**.
   Credentials are never copied between hosts.
4. Pair it as in "Adding or replacing a host" (steps 2 and 3). Then wait: the first sync moves
   everything (about 500k files, 18GB) and takes hours. `psync status` until in sync.
5. `bash ~/projects/dotfiles/psync/vps/install.sh user`, then `sudo bash .../vps/install.sh root`
   (the public-SSH guard; do it from a Tailscale session, not from the public address).
6. `psync backup setup`, and save the new password.
7. `bash ~/projects/dotfiles/psync/tests/run.sh` and `psync doctor --roundtrip` on both hosts.

## Rebuild the PC

The VPS has the full copy, `.git` directories, untracked files and chat history included. On the new
PC run the dotfiles `setup.sh` (it installs stow, syncthing, jq), stow the `psync` package (get the
package from GitHub or from the VPS), leave `~/projects` empty, and `psync setup` towards the VPS.
On the VPS point the peer at the new PC's tailnet address and remove the old PC device in the
Syncthing GUI. A new, empty folder has no history that could read as deletions, so it should
receive everything; check `psync status` and the VPS's `git status` before trusting it.

## Changing things

- **The ignore file** (`psync/.config/psync/stignore`) is synced, so one edit applies on both hosts.
  Rule: whatever git *tracks* must sync, or it shows as deleted on the other host; carve tracked
  files out with a `!` exception placed before the pattern that hides them. Afterwards check
  `git status` for unexpected deletions on the other host. If an edit seems not to apply,
  restarting Syncthing forces a rescan (about 6 min).
- **The `psync` script** is the same file on both hosts, so a bad edit breaks `psync ready` on the
  VPS within seconds. Edit a copy, run `PSYNC=/path/to/copy bash psync/tests/run.sh`, then copy it
  over the real one.
- **Upgrading Syncthing** (pacman on the PC, apt on the VPS; its auto-upgrade is off): keep both
  on the same major version, then run the tests and `psync doctor --roundtrip`.
- **Backup policy and thresholds** are the constants at the top of the script.

## Where things live

| What | Where | In dotfiles |
|---|---|---|
| `psync`, its units, ignore and backup-exclude lists | stowed on both hosts (same files, synced) | `psync/` |
| shell hook | PC: `ai` function in the live `~/.zshrc` (not a stow link). VPS: login hook in `~/.zshrc` and the `ai` wrapper | PC: `zsh/.zshrc`. VPS: `psync/vps/` |
| public-SSH guard (root) | VPS: `/usr/local/sbin/psync-ssh-guard`, `/etc/systemd/system/psync-ssh-guard.*`, firewall backup in `/root/psync-fw-backup` | `psync/vps/` |
| Syncthing identity and config | `~/.local/state/syncthing` on each host | no, per host |
| logins (Claude, Codex, `gh`) | per host | never |
| restic repository and password | VPS only, outside `~/projects` | no |
| old versions of folders added with `folder add` | `~/.local/state/psync/versions/<folder>/` on each host | no, per host |
| tests | `run.sh` (about 105 checks against a fake Syncthing, about 2 minutes), `mesh.sh` (real Syncthing, 4 sandboxes, about 4 minutes), `install-docker.sh` (clean Ubuntu in docker, needs network). None touch your own hosts | `psync/tests/` |
| host installer | `psync/install.sh` (packages, link, linger; `--plan` changes nothing) | `psync/` |

## Limits worth remembering

- `psync ready` cannot see edits the other host made in the last ~10s, or anything while that host is
  off or asleep. `psync wait` before leaving stays manual.
- Two hosts writing the same repo at the same moment is the one thing to avoid; a separate worktree per
  host is fine.
- A live agent session keeps `psync wait` from reaching "in sync": a Codex or Claude session that is
  still appending to its transcript (these can be hundreds of MB) leaves the other host a few KB
  behind at every moment. Seen on 2026-10-20 with a 197MB Codex rollout; `psync hosts` showed the peer
  at 98% while the folder itself was idle. Close or pause the session, then wait.
- The same growing transcript is archived again and again by `projects`' staggered versioning, which
  keeps a copy about every 30s for the first hour: that rollout left 17 copies (3.3GB) in the PC's
  `.stversions` within one hour (2026-10-20). Folders added with `folder add` use a trashcan (one copy
  per file) for this reason.
- Dependencies (`node_modules`, `.venv`, `target`) are rebuilt per host: the VPS is ARM.
- The backups sit on the same disk as the VPS copy of the data. The PC is the other full copy.

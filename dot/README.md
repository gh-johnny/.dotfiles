# dot

Sets a machine up my way, on any Linux, as many times as it takes. One bash tool, no daemon,
no dependencies beyond bash, git and curl (which `install.sh` brings).

```bash
# a new machine, from nothing
curl -fsSL https://raw.githubusercontent.com/gh-johnny/.dotfiles/main/install.sh | sh -s -- --host cli

# afterwards, from anywhere (~/.local/bin/dot links here)
dot status        # what is missing or drifted; changes nothing
dot apply         # fix it; a second run changes nothing
```

## Commands

| | |
|---|---|
| `dot apply` | make this machine match its host profile. Idempotent: every change goes through one function, is counted, and the summary prints `DOT_CHANGES=N` |
| `dot status` | report only; exit 1 when something is missing or drifted |
| `dot diff [pkg]` | how a real file that replaced a link (an installer's `sed -i`) differs from the repo |
| `dot capture` | packages installed by hand that no list knows (Omarchy's own lists excluded) |
| `dot update` | `git pull --ff-only`, then apply |
| `dot verify [--report F]` | item by item proof: each package installed *and runs*, each link resolves *and its program reads it* (`manifest/checks.list`), services enabled *and running*, plugins present. JSON lines with `--report` |
| `dot doctor` | distro, backend, init, prerequisites, which hosts are reachable |
| `dot hosts` | the profiles; `*` marks this machine's |
| `dot names` | check every packages.list mapping against this distro's repos (used by the tests) |

Options: `--host NAME` (remembered in `~/.config/dot/host`), `--only m1,m2`, `--skip m1`,
`--dry-run`, `--yes`, `--verbose`.

## How it is built

```
dot/
├── bin/dot              the CLI
├── lib/
│   ├── core.sh          output, act() (the only way to change the machine), root(), confirm()
│   ├── os.sh            os-release + ID_LIKE → backend, init, libc, container, omarchy
│   ├── pkg.sh           backend dispatch, batch install with one-by-one retry
│   ├── pkg/<backend>.sh pacman apt dnf zypper xbps apk emerge slackpkg nix
│   ├── init/<init>.sh   systemd openrc runit sysvinit none
│   └── manifest.sh      hosts and lists
├── modules/             what apply/status do, in this order:
│                        self omarchy system flatpak links shell mise uv npm installers services ssh
├── hosts/<name>.conf    profiles: bash, composed with `include`
├── manifest/            the lists (below)
└── tests/               the distro matrix
```

### Hosts

| host | for |
|---|---|
| `cli` | terminal only: zsh, neovim, tmux, CLI tools. Any distro, containers included |
| `dev` | cli + docker, tailscale, gh, AI CLIs, SSH key and config |
| `desktop` | dev + terminals, fonts, GUI apps (Flathub off Arch) |
| `pc` | desktop + Omarchy, Hyprland configs, Java/.NET/Android/DB. This PC |
| `vps` | cli + dev + sshd, with the minimal shell from `vps/` |

A host sets `DOT_GROUPS`, `DOT_STOW`, `DOT_MODULES` and a few switches, and may define
`host_pre_apply` / `host_post_apply`. `drop DOT_STOW zsh` takes something an included host added.

### Lists (`dot/manifest/`)

Every line starts with a **group**; a host turns groups on. One knob across all lists.

| file | holds |
|---|---|
| `packages.list` | cross-distro packages, with per-backend names and fallbacks (mise, installer) |
| `arch.list` | Arch-only extras, `aur` marks AUR ones |
| `flatpak.list` | GUI apps where arch.list does not apply |
| `npm.list` / `uv.list` | global npm packages (on mise's node), Python CLI tools |
| `installers.list` | vendor `curl \| sh` installers, run only when their check is missing |
| `services.list` | units to enable and Unix groups to join, per init |
| `ignore.list` | what `dot capture` should not report |

`packages.list` syntax: `GROUP NAME [backend=pkg,pkg | backend=-] [mise=TOOL] [script=NAME] [cmd=BIN] [only=a,b]`.
A name with no key for this backend but with a fallback is probed: the repos win when they have it.
`cmd=` short-circuits when the command is already on PATH, however it got there.

### Layers

1. **user space**, identical everywhere: stow links, mise, uv, npm, installers
2. **system**: distro packages and services, through the backend and init adapters
3. **desktop**: Omarchy, Arch only

## Distros

| family | distros | backend | notes |
|---|---|---|---|
| Arch | Arch, Omarchy, EndeavourOS, Manjaro | pacman (+ yay for AUR) | tier 1, this PC. Refresh = `-Syu` (no partial upgrades) |
| Debian | Debian, Ubuntu, Lubuntu, Mint, Pop!_OS, Zorin, elementary, MX, Kali | apt | neovim/fzf/fd/bat come from mise (too old or renamed) |
| Red Hat | Fedora, RHEL, CentOS Stream, AlmaLinux, Rocky | dnf | EPEL + CRB enabled first on the RHEL family |
| SUSE | openSUSE | zypper | |
| Void | Void | xbps | runit; xbps updates itself first |
| Alpine | Alpine | apk | musl: glibc binaries (mise tools, vendor installers) will not run; OpenRC |
| Gentoo | Gentoo | emerge | `--getbinpkg` to use the binhost; repo via emerge-webrsync |
| Slackware | Slackware | slackpkg | best effort: no dependency resolution, stow is not packaged (dot links without it) |
| Nix | NixOS (and nix elsewhere) | nix-env | user profile only; system and services belong in configuration.nix |

Every family is tested in containers; see **Tests**.

## Tests

| | what it proves | how |
|---|---|---|
| `tests/lint.sh` | ShellCheck-clean | shellcheck (or its docker image) |
| `tests/unit/*.bats` | the logic, piece by piece: distro detection for all 22 distros, the list language, link states and backups, the plan (repo / mise / installer), act()'s change counter, verify's records | bats in `tests/Dockerfile` (Debian + kcov), against a throwaway HOME |
| `matrix.sh -m names` | every packages.list mapping exists in each distro's real repos | `dot names` per container |
| `matrix.sh -m apply` | from nothing, as root: bootstrap, apply, apply again (**must change nothing**), status, `dot verify` passes every item | a container per distro, a snapshot of the working tree |
| `matrix.sh -m user` | the same as a regular user with sudo | |
| `matrix.sh -m systemd` | services really start (host `vps`: sshd, docker, tailscaled) | privileged container, systemd as PID 1 |
| `tests/coverage.py` | **line coverage** (kcov for the unit tests + bash xtrace from every distro run, merged on kcov's map of executable lines) and **item coverage** (each verify item × each run) | markdown + JSON report |

```bash
dot/tests/all.sh            # all of the above, locally (docker), report in ~/.cache/dot-tests/coverage.md
dot/tests/all.sh --quick    # arch debian fedora alpine only
dot/tests/matrix.sh -m apply fedora alma   # one mode, some distros
```

CI (`.github/workflows/dot.yml`) runs the same jobs in parallel on every push and every Monday
(distros drop and rename packages without notice), and puts the coverage report in the job summary.
GitHub being unreachable from a test box is detected per run: only the steps that need it
(shell plugins, mise downloads, neovim plugins) are excused there, never anything else.

## Safety

- Nothing is deleted. A file in the way of a link goes to `~/.local/state/dot/backup/<time>/`.
- A symlinked `~/.config` (or `~/.local`, `~/.ssh`...) is never moved; dot stops and says so.
- `--dry-run` prints every command it would run.
- Logs: `~/.local/state/dot/logs/`.
- Omarchy's installer is only run after a yes (it reconfigures the desktop and reboots).

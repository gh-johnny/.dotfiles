#!/usr/bin/env bash
# Tests for psync against a fake Syncthing REST API (fake-syncthing.py): no real daemon, no network,
# no systemd, no Tailscale, no firewall. HOME points at a temp dir, so the host's own files are never touched.
#
#   bash psync/tests/run.sh
#   PSYNC=/path/to/psync bash psync/tests/run.sh    # test another copy of the script
#
# Takes about a minute: the commands under test wait the way they do for real.

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PSYNC=${PSYNC:-$HERE/../.local/bin/psync}
VPS=$HERE/../vps
PORT=${PORT:-18384}
T=$(mktemp -d /tmp/psync-tests.XXXXXX)
SERVER=""
pass=0
fail=0
out="" rc=0 secs=0

stop() {
  [[ -z $SERVER ]] || { kill "$SERVER" 2>/dev/null; wait "$SERVER" 2>/dev/null; SERVER=""; }
}
cleanup() {
  stop
  [[ $T != /tmp/psync-tests.* ]] || rm -rf -- "$T"
}
trap cleanup EXIT

# --- a fake host: shims for systemctl, tailscale, iptables and logger come first in PATH
H=$T/home
mkdir -p "$T/bin" "$H/projects/dotfiles/psync/.config/psync" "$H/.local/state/syncthing" "$H/.local/state/psync"
echo "// fake" >"$H/projects/dotfiles/psync/.config/psync/stignore"
echo "#include dotfiles/psync/.config/psync/stignore" >"$H/projects/.stignore"
echo "psync ready" >"$H/.zshrc"
cat >"$H/.local/state/syncthing/config.xml" <<EOF
<configuration>
  <gui enabled="true">
    <address>127.0.0.1:$PORT</address>
    <apikey>testkey</apikey>
  </gui>
</configuration>
EOF
printf '#!/bin/sh\nexit 0\n' >"$T/bin/systemctl"
printf '#!/bin/sh\nexit 0\n' >"$T/bin/logger"
cat >"$T/bin/tailscale" <<'EOF'
#!/bin/sh
echo "{\"BackendState\":\"${FAKE_TS_STATE:-Running}\",\"Self\":{\"KeyExpiry\":${FAKE_TS_EXPIRY:-null}}}"
EOF
# one firewall rule, kept as a file: -C checks it, -D deletes it, -I adds it
cat >"$T/bin/iptables" <<'EOF'
#!/bin/sh
case $1 in
  -C) [ -e "$FAKE_RULE" ] ;;
  -D) rm -f "$FAKE_RULE" ;;
  -I) : >"$FAKE_RULE" ;;
esac
EOF
chmod +x "$T/bin/"*

psync() {
  env -u XDG_STATE_HOME -u XDG_DATA_HOME -u STHOMEDIR HOME="$H" PATH="$T/bin:$PATH" \
    CLAUDE_CONFIG_DIR="${T_CLAUDE_CONFIG_DIR-}" CODEX_HOME="${T_CODEX_HOME-}" \
    PSYNC_ROUNDTRIP_TIMEOUT="${RT:-90}" PSYNC_DISK_WARN_GB=1 "$PSYNC" "$@"
}

serve() { # SCENARIO
  stop
  FAKE_LOG="$T/fake.log" python3 -I "$HERE/fake-syncthing.py" "$PORT" "$1" "$H" &
  SERVER=$!
  for _ in $(seq 50); do
    curl -fs "http://127.0.0.1:$PORT/rest/system/ping" >/dev/null 2>&1 && return
    sleep 0.1
  done
  echo "the fake Syncthing did not start" >&2
  exit 1
}

run() { # psync ARGS... → $out $rc $secs
  local start=$SECONDS
  out=$(psync "$@" 2>&1 </dev/null)
  rc=$?
  secs=$((SECONDS - start))
}

ok() { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [[ -z $out ]] || printf '          | %s\n' "${out//$'\n'/$'\n          | '}"; }

check() { # NAME WANT_RC [TEXT | !TEXT]...   (!TEXT = must not appear)
  local name=$1 want=$2 p bad=""
  shift 2
  [[ $rc == "$want" ]] || bad+="exit $rc, wanted $want; "
  for p in "$@"; do
    if [[ $p == '!'* ]]; then
      ! grep -qF -- "${p:1}" <<<"$out" || bad+="unexpected '${p:1}'; "
    else
      grep -qF -- "$p" <<<"$out" || bad+="missing '$p'; "
    fi
  done
  if [[ -z $bad ]]; then ok "$name"; else no "$name: $bad"; fi
}

echo "psync tests ($PSYNC)"

echo "syntax"
for f in "$PSYNC" "$VPS/install.sh" "$VPS/ai"; do
  out=$(bash -n "$f" 2>&1) && ok "$(basename "$f") parses" || no "$(basename "$f") parses"
done
out=$(sh -n "$VPS/psync-ssh-guard" 2>&1) && ok "psync-ssh-guard parses" || no "psync-ssh-guard parses"

echo "status"
serve quiet;   run status; check "in sync" 0 "in sync" "!NOT in sync"
serve offline; run status; check "a disconnected peer is reported" 1 "DISCONNECTED" "NOT in sync"
serve paused;  run status; check "a paused folder is reported" 1 "PAUSED"

echo "ready"
serve quiet; run ready
check "nothing to pull: silent" 0 "!psync:"
((secs <= 2)) && ok "nothing to pull: instant (${secs}s)" || no "nothing to pull: instant (took ${secs}s)"
serve busy;    run ready;   check "pending changes: waits, then says it caught up" 0 "catching up" "caught up"
serve stuck;   run ready 5; check "never catching up: gives up at the timeout, still exits 0" 0 "continuing anyway"
serve offline; run ready;   check "an offline peer is called out" 0 "pc is offline" "last seen 2026-10-20T09:00:00"
serve paused;  run ready;   check "paused: says so instead of waiting" 0 "paused on this host"
stop;          run ready;   check "Syncthing down: warns, does not fail" 0 "not running"

echo "ready: backup warning"
serve quiet
echo "fail $(date +%s) disk full" >"$H/.local/state/psync/backup-last"
run ready; check "a failed backup is shown" 0 "last backup FAILED (disk full)"
echo "ok $(($(date +%s) - 40 * 3600))" >"$H/.local/state/psync/backup-last"
run ready; check "an overdue backup is shown" 0 "no successful backup for over 36h"
echo "ok $(date +%s)" >"$H/.local/state/psync/backup-last"
run ready; check "a recent backup is quiet" 0 "!backup"

echo "doctor"
rm -f "$H/.local/state/psync/backup-last"
serve quiet;   run doctor; check "healthy host" 0 "result: all good" "  ok    in sync with every peer" "!FAIL" "!warn"
serve offline; run doctor; check "an offline peer is a warning, not a failure" 0 "  warn  not fully in sync" "result: no failures, 1 warning(s)"
serve paused;  run doctor; check "a paused folder fails" 1 "FAIL  folder projects is paused"
stop;          run doctor; check "Syncthing down fails" 1 "FAIL  Syncthing is not running"

serve quiet
mv "$H/projects/.stignore" "$H/projects/.stignore.off"
run doctor; check "a missing ignore include fails" 1 "FAIL  ignore rules"
mv "$H/projects/.stignore.off" "$H/projects/.stignore"

mv "$H/.zshrc" "$H/.zshrc.keep"; echo "# nothing" >"$H/.zshrc"
run doctor; check "no psync ready hook is a warning" 0 "  warn  no 'psync ready' in ~/.zshrc"
mv "$H/.zshrc.keep" "$H/.zshrc"

FAKE_TS_STATE=NeedsLogin run doctor; check "tailscale logged out fails" 1 "FAIL  tailscale is NeedsLogin"
FAKE_TS_EXPIRY="\"$(date -u -d '+10 days' +%FT%TZ)\"" run doctor; check "a node key about to expire fails" 1 "FAIL  tailscale node key expires in"
FAKE_TS_EXPIRY="\"$(date -u -d '+90 days' +%FT%TZ)\"" run doctor; check "a node key expiring soon warns" 0 "  warn  tailscale node key expires in"
FAKE_TS_EXPIRY="\"$(date -u -d '+300 days' +%FT%TZ)\"" run doctor; check "a node key with time left is fine" 0 "  ok    tailscale running, node key valid until"

mkdir -p "$H/.local/share/psync-backup/repo" && : >"$H/.local/share/psync-backup/repo/config"
echo "fail $(date +%s) disk full" >"$H/.local/state/psync/backup-last"
run doctor; check "a failed backup fails" 1 "FAIL  the last backup FAILED (disk full)"
echo "ok $(date +%s)" >"$H/.local/state/psync/backup-last"
run doctor; check "a recent backup is fine" 0 "  ok    backup: last run ok at"
rm -f "$H/.local/share/psync-backup/repo/config" "$H/.local/state/psync/backup-last"

echo "doctor --roundtrip"
serve quiet; run doctor --roundtrip
check "a canary file reaches the peer" 0 "roundtrip: a canary file reached every connected peer"
compgen -G "$H/projects/.psync-canary-*" >/dev/null && no "the canary file is removed afterwards" || ok "the canary file is removed afterwards"
serve stuck;   RT=4 run doctor --roundtrip; check "a canary that never arrives fails" 1 "roundtrip: the canary did not reach pc within 4s"
serve offline; run doctor --roundtrip;      check "no connected peer: says so" 1 "roundtrip: no peer is connected"
stop

echo "hosts"
VALID_ID=AAAAAAA-BBBBBBB-CCCCCCC-DDDDDDD-EEEEEEE-FFFFFFF-GGGGGGG-HHHHHHH
serve quiet;   run hosts; check "lists this host and its peer with how much it has" 0 "me (this)" "pc" "connected" "100%" "tcp://100.64.0.1:22000"
serve offline; run hosts; check "an offline peer shows when it was last seen" 0 "offline" "2026-10-20T09:00:00"
serve quiet
run add-host --id NOTANID --name x;       check "add-host rejects a malformed device ID" 1 "must be the other host's Syncthing device ID"
run add-host --id "$VALID_ID";            check "add-host needs a name" 1 "--name is required"
run remove-host;                          check "remove-host needs an argument" 1 "usage: psync remove-host"
run remove-host nobody --yes;             check "remove-host refuses an unknown host" 1 "no host named or identified 'nobody'"
run remove-host pc;                       check "remove-host does not guess without a terminal" 1 "pass --yes"
stop

echo "folders (a host that syncs more than one)"
mkdir -p "$H/.claude/projects"
logged() { out=$(cat "$T/fake.log"); rc=0; }   # the writes the last command sent to the fake Syncthing
serve multi;           run status; check "each line says which folder it is about" 0 "[projects] idle" "[claude] idle" "in sync" "!NOT in sync"
serve multi-busy;      run status; check "a second folder with items to pull: not in sync" 1 "[projects] idle" "[claude] syncing" "NOT in sync"
serve multi-paused;    run status; check "one paused folder is reported" 1 "[claude] PAUSED"
serve multi-notshared; run status; check "a peer that has not added a folder is mentioned, not an error" 0 "[claude] pc connected, but has not added this folder" "!NOT in sync"
serve quiet;           run status; check "one folder: the lines stay unlabelled" 0 "folder:    idle" "!["
serve multi-busy;      run ready;  check "ready waits for every folder" 0 "catching up" "caught up"
serve multi-paused;    run ready;  check "ready skips a paused folder" 0 "!psync:"
serve multi;           run doctor; check "healthy host with two folders" 0 "result: all good" "!FAIL" "!warn"
[[ $(grep -c '  ok    disk:' <<<"$out") == 1 ]] && ok "doctor: one disk line per filesystem" || no "doctor: one disk line per filesystem"
serve multi-paused;    run doctor; check "doctor names the paused folder" 1 "FAIL  folder claude is paused"
serve multi-notshared; run doctor; check "doctor warns about a peer that has not added a folder" 0 "  warn  a peer has not added a folder" "result: no failures, 1 warning(s)"
serve multi;           run doctor --roundtrip
check "a canary goes through every folder" 0 "roundtrip (projects): a canary file reached" "roundtrip (claude): a canary file reached"
compgen -G "$H/.claude/projects/.psync-canary-*" >/dev/null && no "the canary is removed from the second folder too" || ok "the canary is removed from the second folder too"
serve multi-notshared; run doctor --roundtrip
check "no canary for a folder the peer has not added" 0 "roundtrip (projects): a canary file reached" "roundtrip (claude): no connected peer has added this folder yet" "result: no failures, 2 warning(s)"
serve multi;           run folders; check "folders lists each folder and where it lives" 0 "FOLDER" "projects" "~/projects" "claude" "~/.claude/projects"
serve multi;           run hosts;   check "hosts shows how much of its folders each host has" 0 "pc" "100%"

echo "folder add / remove"
serve quiet
run folder;                                  check "folder needs an action" 1 "usage: psync folder"
run folder add;                              check "folder add needs an ID and a PATH" 1 "usage: psync folder add"
run folder add Bad_ID /x;                    check "folder add rejects a malformed ID" 1 "folder ID must be"
run folder add x rel/path;                   check "folder add wants an absolute path" 1 "must be absolute"
run folder add --preset nope;                check "folder add rejects an unknown preset" 1 "unknown preset"
run folder add --preset claude x /y;         check "folder add takes a preset or ID PATH, not both" 1 "either --preset or ID PATH"
run folder add inside "$H/projects/sub";     check "a folder inside another one is refused" 1 "already synced as part of folder projects"
run folder add outer "$H";                   check "a folder that contains another one is refused" 1 "lives inside"
T_CLAUDE_CONFIG_DIR="$H/projects/cc" run folder add --preset claude
check "the preset follows CLAUDE_CONFIG_DIR, and is refused inside a synced folder" 1 "already synced as part of folder projects"
run folder remove projects --yes;            check "the base folder cannot be removed" 1 "base folder"
run folder remove nothere --yes;             check "folder remove refuses an unknown folder" 1 "no folder 'nothere'"
serve multi
run folder add claude /tmp/other;            check "folder add refuses an existing ID" 1 "already exists"
run folder remove claude;                    check "folder remove does not guess without a terminal" 1 "pass --yes"

serve quiet
: >"$T/fake.log"
run folder add --preset claude
check "folder add --preset claude" 0 "added folder claude: ~/.claude/projects, shared with 1 other host(s)"
[[ -d $H/.claude/projects ]] && ok "the folder directory exists" || no "the folder directory exists"
logged
check "the new folder is sent to Syncthing as sendreceive, shared with the known hosts" 0 \
  'PUT config/folders/claude' '"id":"claude"' "\"path\":\"$H/.claude/projects\"" '"type":"sendreceive"' '"deviceID":"PEER"' '"deviceID":"ME"'
check "its old versions go outside the folder, to a trashcan" 0 \
  '"type":"trashcan"' "\"fsPath\":\"$H/.local/state/psync/versions/claude\"" '"cleanoutDays":"30"'
: >"$T/fake.log"
T_CODEX_HOME="$H/codex-home" run folder add --preset codex
check "folder add --preset codex follows CODEX_HOME" 0 "added folder codex"
logged
check "codex syncs its sessions directory only" 0 "\"path\":\"$H/codex-home/sessions\""
: >"$T/fake.log"
serve multi
run folder remove claude --yes;              check "folder remove" 0 "removed folder claude"
logged
check "folder remove deletes just that folder from Syncthing" 0 'DELETE config/folders/claude'

echo "folders: pause, resume and hosts act on all of them"
serve multi; : >"$T/fake.log"
run pause;  check "pause" 0 "paused"
logged;     check "pause pauses every folder" 0 'PATCH config/folders/projects {"paused":true}' 'PATCH config/folders/claude {"paused":true}'
: >"$T/fake.log"
run resume; check "resume" 0 "resumed"
logged;     check "resume resumes every folder" 0 'PATCH config/folders/projects {"paused":false}' 'PATCH config/folders/claude {"paused":false}'
: >"$T/fake.log"
run add-host --id "$VALID_ID" --name friend; check "add-host" 0 "added host friend"
logged;     check "add-host shares every folder with the new host" 0 \
  "PUT config/folders/projects" "PUT config/folders/claude" "\"deviceID\":\"$VALID_ID\""
: >"$T/fake.log"
run remove-host pc --yes; check "remove-host" 0 "removed host pc"
logged;     check "remove-host leaves every folder" 0 "PUT config/folders/projects" "PUT config/folders/claude" 'DELETE config/devices/PEER'
run help;   check "help lists the folder commands" 0 "psync folders" "psync folder add" "psync folder remove"
run help;   check "help lists the settings commands" 0 "psync init" "psync config"
stop

echo "settings (~/.config/psync/config)"
CFG=$H/.config/psync/config
serve quiet
run config;  check "without a file the defaults apply" 0 "settings file: none" "folder_path" "~/projects" "default" "!settings file: ~"
run init;    check "init writes the file" 0 "wrote ~/.config/psync/config"
grep -q '^# folder_path=~/projects$' "$CFG" && grep -q '^# versions_days=30$' "$CFG" && ! grep -q '^[a-z_]*=' "$CFG" &&
  ok "init leaves every default commented out" || no "init leaves every default commented out"
run init;    check "init does not overwrite" 1 "already exists"
run init --force --folder-path "$H/code" --ignore-include none
check "init --force takes the choices from its flags" 0 "wrote"
grep -qx 'folder_path=~/code' "$CFG" && grep -qx 'ignore_include=none' "$CFG" && ok "the chosen values are written, with ~" || no "the chosen values are written, with ~"
run config;  check "config shows the file and where each value comes from" 0 "settings file: ~/.config/psync/config" "~/code" "none" "file" "default"
run init --force --folder-path code;       check "init rejects a relative path" 1 "folder_path must be an absolute path"
run init --force --ignore-include /etc/x;  check "init rejects an ignore file outside the folder" 1 "ignore_include is a path inside the folder"
run init --force --bogus;                  check "init rejects an unknown option" 1 "unknown option"
rm -f "$CFG"

bad() { # NAME CONTENT TEXT: a settings file that every command must refuse, naming the problem
  printf '%s\n' "$2" >"$CFG"
  run status
  check "settings: $1" 1 "$3"
}
bad "an unknown setting names its line" $'# fine\ncolour=blue' "line 2: unknown setting 'colour'"
bad "a line without =" "just words" "expected KEY=VALUE"
bad "a number must be a number" "disk_warn_gb=lots" "disk_warn_gb must be a whole number"
bad "versions_days cannot be 0" "versions_days=0" "versions_days must be a whole number of days"
bad "folder_path must be absolute" "folder_path=code" "folder_path must be an absolute path"
bad "the ignore file stays inside the folder" "ignore_include=../x" "ignore_include is a path inside the folder"
bad "a value is data, never run" "folder_path=\$(touch $T/pwned)" "folder_path must be an absolute path"
[[ ! -e $T/pwned ]] && ok "settings: a value with \$(...) was not executed" || no "settings: a value with \$(...) was not executed"
printf 'colour=blue\n' >"$CFG"
run help;  check "help works with a broken settings file" 0 "psync status"
printf '  folder_path = ~/projects  \n\n# a comment\n' >"$CFG"
run config; check "spaces around the key and value, comments and blank lines are fine" 0 "~/projects" "file"

printf 'versions_days=7\n' >"$CFG"
: >"$T/fake.log"
run folder add --preset claude; check "versions_days reaches the folders it adds" 0 "added folder claude"
logged;                         check "…as the trashcan's clean-out time" 0 '"cleanoutDays":"7"'
printf 'ignore_include=none\n' >"$CFG"
mv "$H/projects/.stignore" "$H/projects/.stignore.off"
run doctor; check "ignore_include none: psync leaves .stignore alone" 0 "ignore rules: ~/projects/.stignore is yours" "!FAIL"
mv "$H/projects/.stignore.off" "$H/projects/.stignore"
printf 'folder_path=%s/code\nignore_include=none\n' "$H" >"$CFG"
run doctor; check "doctor notices a folder_path that Syncthing does not use" 1 "FAIL  folder_path says ~/code but Syncthing syncs ~/projects as folder projects"
run setup;  check "setup will not repoint a folder to a directory that is not a Syncthing folder" 1 "folder projects already syncs ~/projects and folder_path says ~/code" "no .stfolder" "psync pause"
mkdir -p "$H/code" && : >"$H/code/.stfolder" && : >"$T/fake.log"
run setup;  check "…but a directory that was moved there (it has .stfolder) is fine" 0 "This device: ME"
logged;     check "…and the folder is repointed" 0 'PUT config/folders/projects' "\"path\":\"$H/code\""
rm -f "$CFG"
PSYNC_DISK_WARN_GB=3 run config; check "PSYNC_DISK_WARN_GB wins over the file and the default" 0 "disk_warn_gb" "env"
stop

echo "install.sh (--plan only: nothing is installed)"
# A home whose ~/projects/dotfiles is this checkout, and a PATH with none of the tools psync needs
mkdir -p "$T/ihome/projects" "$T/minbin"
ln -s "$(cd "$HERE/../.." && pwd -P)" "$T/ihome/projects/dotfiles"
for tool in dirname basename sed cat; do ln -sf "$(command -v $tool)" "$T/minbin/$tool"; done
printf 'ID=ubuntu\nID_LIKE=debian\n' >"$T/os-debian"
printf 'ID=arch\n' >"$T/os-arch"
printf 'ID=plan9\n' >"$T/os-other"
printf '#!/bin/sh\necho "syncthing v${FAKE_ST_VERSION:-2.1.0} fake"\n' >"$T/minbin/syncthing"
chmod +x "$T/minbin/syncthing"
plan() { # OS-FILE [install.sh args...]
  local osf=$1
  shift
  out=$(env -i HOME="$T/ihome" USER=tester PATH="$T/minbin" PSYNC_OS_RELEASE="$osf" FAKE_ST_VERSION="${FAKE_ST_VERSION:-}" \
    "$BASH" "${INSTALL_SH:-$HERE/../install.sh}" --plan "$@" 2>&1 </dev/null)
  rc=$?
}
mv "$T/minbin/syncthing" "$T/syncthing.shim"
plan "$T/os-debian"
check "debian: adds the Syncthing 2 repository and installs everything missing" 0 "stable-v2" "apt-get update" "apt-get install -y jq curl stow git syncthing" "stow --no-folding" "enable-linger"
plan "$T/os-debian" --with-backup
check "debian: --with-backup also asks for restic and openssl" 0 "jq curl stow git restic openssl syncthing"
plan "$T/os-arch"
check "arch: installs with pacman, no apt repository" 0 "pacman -S --needed --noconfirm jq curl stow git syncthing" "!apt-get" "!stable-v2"
plan "$T/os-other"
check "an unsupported distribution says what to install by hand" 1 "unsupported distribution" "syncthing (2 or newer)"
cp "$T/syncthing.shim" "$T/minbin/syncthing"
plan "$T/os-debian"
check "debian with Syncthing 2 already there: no extra repository" 0 "apt-get install -y jq curl stow git" "!stable-v2" "!syncthing"
FAKE_ST_VERSION=1.29.5 plan "$T/os-debian"
check "debian with Syncthing 1.x: still adds the 2.x repository" 0 "stable-v2" "syncthing"
rm -f "$T/minbin/syncthing"
mkdir -p "$T/elsewhere/psync" "$T/elsewhere/other-name"
cp "$HERE/../install.sh" "$T/elsewhere/psync/install.sh"
cp "$HERE/../install.sh" "$T/elsewhere/other-name/install.sh"
INSTALL_SH="$T/elsewhere/psync/install.sh" plan "$T/os-debian"
check "the package can live anywhere, not only in ~/projects/dotfiles" 0 "stow --no-folding --dir=$T/elsewhere --target=$T/ihome psync" "!projects/dotfiles"
INSTALL_SH="$T/elsewhere/other-name/install.sh" plan "$T/os-debian"
check "a directory not called psync is refused (stow links by directory name)" 1 "keep the directory called psync"

echo "vps/install.sh"
V=$T/vps-home
mkdir -p "$V"
echo "old zshrc" >"$V/.zshrc"
out=$(HOME="$V" bash "$VPS/install.sh" user 2>&1); rc=$?
check "user part runs" 0 "installed ~/.zshrc and ~/.local/bin/ai"
cmp -s "$VPS/zshrc" "$V/.zshrc" && ok "login hook installed" || no "login hook installed"
[[ -x $V/.local/bin/ai ]] && cmp -s "$VPS/ai" "$V/.local/bin/ai" && ok "ai wrapper installed and executable" || no "ai wrapper installed and executable"
[[ $(cat "$V/.zshrc.pre-psync" 2>/dev/null) == "old zshrc" ]] && ok "the previous .zshrc is kept" || no "the previous .zshrc is kept"
HOME="$V" bash "$VPS/install.sh" user >/dev/null 2>&1
[[ $(cat "$V/.zshrc.pre-psync" 2>/dev/null) == "old zshrc" ]] && ok "a second run does not overwrite that copy" || no "a second run does not overwrite that copy"

mkdir -p "$T/sbin" "$T/units"
printf '%s\n' '-A INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT' '-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT' >"$T/rules.v4"
out=$(SBIN_DIR="$T/sbin" UNIT_DIR="$T/units" RULES_V4="$T/rules.v4" PATH="$T/bin:$PATH" bash "$VPS/install.sh" root 2>&1); rc=$?
check "root part runs" 0 "guard installed and active"
[[ -x $T/sbin/psync-ssh-guard && -e $T/units/psync-ssh-guard.timer && -e $T/units/psync-ssh-guard.service ]] && ok "guard and units installed" || no "guard and units installed"
! grep -q -- '--dport 22 ' "$T/rules.v4" && grep -q -- '--dport 443 ' "$T/rules.v4" && ok "only the public SSH rule left rules.v4" || no "only the public SSH rule left rules.v4"

echo "psync-ssh-guard"
export FAKE_RULE=$T/rule PSYNC_GUARD_DOWN=$T/down
guard() { out=$(env PATH="$T/bin:$PATH" sh "$VPS/psync-ssh-guard" 2>&1); rc=$?; }
rule() { [[ -e $FAKE_RULE ]] && echo open || echo closed; }
: >"$FAKE_RULE"
guard; [[ $(rule) == closed ]] && ok "Tailscale Running: the public rule is removed" || no "Tailscale Running: the public rule is removed"
FAKE_TS_STATE=Stopped guard
[[ $(rule) == closed && -e $PSYNC_GUARD_DOWN ]] && ok "Tailscale just went down: stays closed, starts the clock" || no "Tailscale just went down: stays closed, starts the clock"
echo $(($(date +%s) - 400)) >"$PSYNC_GUARD_DOWN"
FAKE_TS_STATE=Stopped guard
[[ $(rule) == open ]] && ok "Tailscale down for over 5 minutes: SSH reopens" || no "Tailscale down for over 5 minutes: SSH reopens"
guard
[[ $(rule) == closed && ! -e $PSYNC_GUARD_DOWN ]] && ok "Tailscale back: closes again, clock reset" || no "Tailscale back: closes again, clock reset"

echo
echo "passed $pass, failed $fail"
((fail == 0))

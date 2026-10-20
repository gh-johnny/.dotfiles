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
    PSYNC_ROUNDTRIP_TIMEOUT="${RT:-90}" PSYNC_DISK_WARN_GB=1 "$PSYNC" "$@"
}

serve() { # SCENARIO
  stop
  python3 -I "$HERE/fake-syncthing.py" "$PORT" "$1" &
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
  out=$(psync "$@" 2>&1)
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

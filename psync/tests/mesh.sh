#!/usr/bin/env bash
# Mesh test: four real Syncthing instances (a, b, c, d) in sandbox HOMEs, driven by psync. It backs the
# claim "any host can be lost or replaced": pairing through one host, files crossing a hub, a direct
# link surviving the hub going down, a replacement host receiving everything from the survivors, and
# removing a host. Nothing outside the temp dir is touched (your own Syncthing keeps running, and
# the sandboxes use their own ports and no discovery). Needs syncthing, jq and curl; takes a few minutes.
#
#   bash psync/tests/mesh.sh
#   PSYNC=/path/to/psync bash psync/tests/mesh.sh
#   MESH_PORT_BASE=19000 bash psync/tests/mesh.sh    # if 18401-18404 or 22401-22404 are taken

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PSYNC=${PSYNC:-$HERE/../.local/bin/psync}
STIGNORE=$HERE/../.config/psync/stignore
BASE=${MESH_PORT_BASE:-18400}

for tool in syncthing jq curl; do
  command -v "$tool" >/dev/null || { echo "$tool is not installed: skipping the mesh test"; exit 0; }
done

T=$(mktemp -d /tmp/psync-mesh.XXXXXX)
pass=0
fail=0
out=""
declare -A GUI LST
i=1
for n in a b c d; do
  GUI[$n]=$((BASE + i))
  LST[$n]=$((BASE + 4000 + i))
  i=$((i + 1))
done

stop_host() { # NAME
  if [[ -e $T/$1/.syncthing.pid ]]; then
    kill "$(cat "$T/$1/.syncthing.pid")" 2>/dev/null
    rm -f "$T/$1/.syncthing.pid"
  fi
}
cleanup() {
  for n in a b c d; do stop_host "$n"; done
  [[ $T != /tmp/psync-mesh.* ]] || rm -rf -- "$T"
}
trap cleanup EXIT

# systemctl is the only thing psync asks of the system: start a Syncthing for this sandbox on demand
mkdir -p "$T/bin"
cat >"$T/bin/systemctl" <<'EOF'
#!/bin/bash
case "$*" in
  *syncthing.service*)
    case "$*" in *enable* | *start*)
      pidf="$HOME/.syncthing.pid"
      if [ -e "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then exit 0; fi
      nohup syncthing serve --home="$HOME/.local/state/syncthing" --no-browser --no-restart --no-upgrade >"$HOME/syncthing.log" 2>&1 &
      echo $! >"$pidf" ;;
    esac ;;
esac
exit 0
EOF
chmod +x "$T/bin/systemctl"

hx() { # HOST psync-args...
  local n=$1
  shift
  env -u STHOMEDIR -u XDG_STATE_HOME -u XDG_DATA_HOME HOME="$T/$n" PATH="$T/bin:$PATH" "$PSYNC" "$@" </dev/null
}
api() { # HOST METHOD PATH
  local key
  key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' "$T/$1/.local/state/syncthing/config.xml" | head -1)
  curl -fsS -X "$2" -H "X-API-Key: $key" "http://127.0.0.1:${GUI[$1]}/rest/$3"
}
id_of() { api "$1" GET system/status | jq -r .myID; }
listen() { echo "tcp://127.0.0.1:${LST[$1]}"; }

wait_for() { # SECONDS command...   (polls every 2s)
  local limit=$1 start=$SECONDS
  shift
  while ((SECONDS - start < limit)); do
    "$@" 2>/dev/null && return 0
    sleep 2
  done
  return 1
}
sees() { hx "$1" hosts | grep -Eq "$2"; }                  # HOST REGEX
has_file() { [[ -f $T/$1/projects/$2 ]]; }                 # HOST FILE
has_extra() { [[ -f $T/$1/extra/$2 ]]; }                   # HOST FILE, in the second folder

ok() { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  FAIL  %s\n' "$1"; [[ -z $out ]] || printf '          | %s\n' "${out//$'\n'/$'\n          | '}"; }
expect() { # NAME seconds command...
  local name=$1
  shift
  if wait_for "$@"; then ok "$name"; else out=$(hx b hosts 2>&1); no "$name"; out=""; fi
}

echo "psync mesh test ($PSYNC)"
echo "sandboxes in $T"

for n in a b c d; do
  mkdir -p "$T/$n/projects/dotfiles/psync/.config/psync" "$T/$n/.local/state/syncthing"
  cp "$STIGNORE" "$T/$n/projects/dotfiles/psync/.config/psync/stignore"
  HOME="$T/$n" syncthing generate --home="$T/$n/.local/state/syncthing" --no-port-probing >/dev/null 2>&1
  sed -i "s#127.0.0.1:8384#127.0.0.1:${GUI[$n]}#" "$T/$n/.local/state/syncthing/config.xml"
done

echo "pairing: b and c join through a"
hx a setup --listen "$(listen a)" >/dev/null 2>&1
A=$(id_of a)
for n in b c; do
  hx "$n" setup --peer-id "$A" --peer-name a --peer-address "$(listen a)" --listen "$(listen "$n")" >/dev/null 2>&1
done
B=$(id_of b)
C=$(id_of c)
hx a add-host --id "$B" --name b >/dev/null 2>&1
hx a add-host --id "$C" --name c >/dev/null 2>&1
expect "b and c connect to a once a added them" 90 bash -c "$(declare -f sees hx); T=$T PSYNC=$PSYNC; sees a '^b +[A-Z0-9]{7} +connected' && sees a '^c +[A-Z0-9]{7} +connected'"

echo "files cross the hub"
echo from-b >"$T/b/projects/f1.txt"
expect "a file written on b reaches c through a" 120 has_file c f1.txt
expect "b learned about c from a (introducer)" 60 bash -c "$(declare -f sees hx); T=$T PSYNC=$PSYNC; sees b '^c .*through a \\(introduced\\)'"

echo "direct link, then the hub goes down"
hx b add-host --id "$C" --name c --address "$(listen c)" >/dev/null 2>&1
hx c add-host --id "$B" --name b --address "$(listen b)" >/dev/null 2>&1
expect "b and c connect directly once they have each other's address" 90 bash -c "$(declare -f sees hx); T=$T PSYNC=$PSYNC; sees b '^c +[A-Z0-9]{7} +connected +[0-9]+% +now +tcp://'"
stop_host a
echo from-b-while-a-is-down >"$T/b/projects/f2.txt"
expect "with a down, a file written on b still reaches c" 120 has_file c f2.txt

echo "replacement: d joins while a is gone"
hx d setup --peer-id "$B" --peer-name b --peer-address "$(listen b)" --listen "$(listen d)" >/dev/null 2>&1
D=$(id_of d)
hx b add-host --id "$D" --name d >/dev/null 2>&1
expect "d receives everything the survivors have" 180 bash -c "$(declare -f has_file); T=$T; has_file d f1.txt && has_file d f2.txt"
expect "c learned about d from b (introducer)" 60 bash -c "$(declare -f sees hx); T=$T PSYNC=$PSYNC; sees c '^d '"

echo "removal"
out=$(hx b add-host --id "$B" --name self 2>&1)
if [[ $out == *"this host's own device ID"* ]]; then ok "a host cannot add itself"; else no "a host cannot add itself"; fi
out=""
hx b remove-host a --yes >/dev/null 2>&1
hx c remove-host a --yes >/dev/null 2>&1
if sees b '^a '; then no "remove-host drops a on b"; else ok "remove-host drops a on b"; fi
has_file b f1.txt && ok "the files stay on the host that removed a peer" || no "the files stay on the host that removed a peer"
expect "removing a on its introducees also drops it on d (introduced)" 60 bash -c "$(declare -f sees hx); T=$T PSYNC=$PSYNC; ! sees d '^a '"

echo "second folder: sharing is opt-in on each host"
hx b folder add extra "$T/b/extra" >/dev/null 2>&1
expect "b says c has not added the folder yet" 90 bash -c "$(declare -f hx); T=$T PSYNC=$PSYNC; hx b status | grep -q 'c connected, but has not added this folder'"
hx c folder add extra "$T/c/extra" >/dev/null 2>&1
echo e1 >"$T/b/extra/e1.txt"
expect "a file in the second folder reaches c once c has added it" 120 has_extra c e1.txt
[[ ! -e $T/d/extra ]] && ok "d never added the folder, so it has none of its files" || no "d never added the folder, so it has none of its files"
out=$(hx b doctor --roundtrip 2>&1)
if grep -q 'ok    roundtrip (extra): a canary file reached' <<<"$out"; then ok "doctor --roundtrip sends a canary through the second folder"; else no "doctor --roundtrip sends a canary through the second folder"; fi
out=""
rm -f "$T/b/extra/e1.txt"
expect "a file deleted on b goes to c's trashcan outside the folder" 120 bash -c "[[ ! -e $T/c/extra/e1.txt && -e $T/c/.local/state/psync/versions/extra/e1.txt ]]"
[[ ! -e $T/c/extra/.stversions ]] && ok "no versions directory inside the second folder" || no "no versions directory inside the second folder"

echo "pause and resume cover every folder"
hx b pause >/dev/null 2>&1
out=$(hx b folders 2>&1)
if [[ $(grep -c ' paused ' <<<"$out") == 2 ]]; then ok "pause pauses both folders"; else no "pause pauses both folders"; fi
hx b resume >/dev/null 2>&1
out=$(hx b folders 2>&1)
if grep -q ' paused ' <<<"$out"; then no "resume resumes both folders"; else ok "resume resumes both folders"; fi
out=""

echo "add-host shares every folder"
hx b remove-host d --yes >/dev/null 2>&1
hx b add-host --id "$D" --name d >/dev/null 2>&1
if api b GET config/folders/extra | jq -e --arg d "$D" '.devices | any(.deviceID == $d)' >/dev/null; then
  ok "a host added later is in the second folder too"
else
  no "a host added later is in the second folder too"
fi

echo
echo "passed $pass, failed $fail"
((fail == 0))

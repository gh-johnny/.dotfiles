#!/usr/bin/env bash
# The distro matrix: every supported family in a container, `dot` bootstrapped from this working
# tree (uncommitted changes included). A distro passes when the second `dot apply` changes
# nothing and fails nowhere outside ALLOW_FAIL, and an interactive zsh starts without errors.
#
#   dot/tests/matrix.sh [-m apply|user|names] [-H host] [-j jobs] [distro...]    (default: all)
#
# Logs: ~/.cache/dot-tests/<mode>-<distro>.log. Needs docker (or podman as docker).
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LOGS=${DOT_TEST_LOGS:-$HOME/.cache/dot-tests}

declare -A IMAGE=(
  [arch]=archlinux:latest            [manjaro]=manjarolinux/base:latest
  [debian]=debian:trixie             [debian12]=debian:bookworm
  [ubuntu]=ubuntu:24.04              [mint]=linuxmintd/mint22-amd64:latest
  [kali]=kalilinux/kali-rolling:latest
  [fedora]=fedora:latest             [alma]=almalinux:9
  [opensuse]=opensuse/tumbleweed:latest
  [void]=ghcr.io/void-linux/void-glibc:latest
  [alpine]=alpine:latest             [gentoo]=gentoo/stage3:latest
  [nix]=nixos/nix:latest
)
ORDER=(arch manjaro debian debian12 ubuntu mint kali fedora alma opensuse void alpine gentoo nix)

mode=apply host=cli jobs=3
while getopts 'm:H:j:' o; do
  case $o in m) mode=$OPTARG ;; H) host=$OPTARG ;; j) jobs=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
(($#)) && ORDER=("$@")

# Steps that need github.com cannot pass where it is unreachable; they still must not loop.
ALLOW_FAIL=${ALLOW_FAIL:-}
if [[ -z $ALLOW_FAIL ]] && ! curl -fsS -m 5 -o /dev/null https://github.com 2>/dev/null; then
  ALLOW_FAIL="shell mise"
  echo "github.com unreachable: allowing failures in: $ALLOW_FAIL"
fi

mkdir -p "$LOGS"

# Test a snapshot, not the live tree: editing while the matrix runs must not change what it tests
# (bash reads scripts as it goes).
SNAP=$(mktemp -d "${TMPDIR:-/tmp}/dot-matrix.XXXXXX")
trap 'rm -rf "$SNAP"' EXIT
tar -C "$ROOT" --exclude=./.git --exclude=./archive -cf - . | tar -C "$SNAP" -xf -

one() {
  local d=$1 log="$LOGS/$mode-$1.log" img=${IMAGE[$1]:-}
  [[ -n $img ]] || { echo "$d: unknown distro"; return 1; }
  local t0=$SECONDS
  timeout 3600 docker run --rm --network "${DOT_TEST_NET:-host}" -v "$SNAP:/src:ro" -e NO_COLOR=1 "$img" \
    sh /src/dot/tests/in-container.sh "$mode" "$host" >"$log" 2>&1
  local rc=$? secs=$((SECONDS - t0))
  if [[ $mode == names ]]; then
    printf '%-9s %s  %4ss  %s\n' "$d" "$([[ $rc == 0 ]] && echo PASS || echo FAIL)" "$secs" \
      "$(grep -c '✗' "$log") unknown names"
    return $rc
  fi
  verdict "$d" "$log" "$secs"
}

verdict() {
  local d=$1 log=$2 secs=$3 why=() failed m
  local ch2
  ch2=$(awk '/^===== run2/{f=1} f && /^DOT_CHANGES=/{print; exit}' "$log" | cut -d= -f2)
  [[ $ch2 == 0 ]] || why+=("2nd run changed ${ch2:-?}")
  failed=$(awk '/^===== run2/{f=1} f && /done with failures in:/{sub(/.*failures in: /,""); sub(/ ·.*/,""); print; exit}' "$log")
  for m in $failed; do [[ " $ALLOW_FAIL " == *" $m "* ]] || why+=("$m failed"); done
  grep -q '^ZSH_EXIT=0' "$log" || why+=("zsh exit")
  [[ -z $(sed -n '/^===== zsh stderr/,$p' "$log" | tail -n +2) ]] || why+=("zsh stderr")
  local ch1
  ch1=$(awk '/^===== run1/{f=1} f && /^DOT_CHANGES=/{print; exit}' "$log" | cut -d= -f2)
  if ((${#why[@]})); then
    printf '%-9s FAIL  %4ss  run1=%s changes  %s\n' "$d" "$secs" "${ch1:-?}" "$(IFS=';'; echo "${why[*]}")"
    return 1
  fi
  printf '%-9s PASS  %4ss  run1=%s changes%s\n' "$d" "$secs" "${ch1:-?}" "${failed:+  (allowed: $failed)}"
}

rc=0 running=0
for d in "${ORDER[@]}"; do
  one "$d" &
  running=$((running + 1))
  if ((running >= jobs)); then wait -n || rc=1; running=$((running - 1)); fi
done
while ((running > 0)); do wait -n || rc=1; running=$((running - 1)); done
echo "logs: $LOGS"
exit $rc

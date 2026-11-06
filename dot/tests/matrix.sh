#!/usr/bin/env bash
# The distro matrix: every supported family in a container, `dot` bootstrapped from a snapshot of
# this working tree (uncommitted changes included).
#
#   dot/tests/matrix.sh [-m MODE] [-H host] [-j jobs] [distro...]        (default: every distro)
#
# MODE
#   names    every packages.list mapping exists in the distro's repos
#   apply    as root: bootstrap, apply, apply again, status, verify
#   user     the same as a regular user with passwordless sudo (the real-life case), host dev
#   systemd  the same with systemd as PID 1 (privileged container): services really start.
#            Defaults to host vps (sshd, docker, tailscaled) and distros arch fedora
#
# A distro passes when: the second apply changes nothing, no module fails, `dot verify` passes
# every item. Where github.com dropped out during the run (it is visible in the log), only the
# steps that need it (shell plugins, mise downloads) may fail and only their commands may repeat.
#
# Out: ~/.cache/dot-tests/<mode>-<distro>.log, and under run/ the verify reports (.jsonl) and
# line traces (.trace) tests/coverage.py turns into the coverage report.
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
  [nix]=nixos/nix:latest             [slackware]=aclemons/slackware:15.0
)
# systemd as PID 1: what to install first and where init lives
declare -A SYSTEMD_BOOT=(
  [arch]='exec /usr/lib/systemd/systemd'
  [fedora]='dnf install -y -q systemd procps-ng >/dev/null && exec /usr/sbin/init'
  [debian]='apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv dbus >/dev/null && exec /sbin/init'
  [ubuntu]='apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd systemd-sysv dbus >/dev/null && exec /sbin/init'
)
ORDER=(arch manjaro debian debian12 ubuntu mint kali fedora alma opensuse void alpine gentoo nix slackware)

mode=apply host='' jobs=3
while getopts 'm:H:j:' o; do
  case $o in m) mode=$OPTARG ;; H) host=$OPTARG ;; j) jobs=$OPTARG ;; *) exit 2 ;; esac
done
shift $((OPTIND - 1))
if (($#)); then ORDER=("$@")
elif [[ $mode == systemd ]]; then ORDER=(arch fedora)
fi
if [[ -z $host ]]; then
  case $mode in systemd) host=vps ;; user) host=dev ;; *) host=cli ;; esac
fi

mkdir -p "$LOGS/run"

# Test a snapshot, not the live tree: editing while the matrix runs must not change what it tests.
SNAP=$(mktemp -d "${TMPDIR:-/tmp}/dot-matrix.XXXXXX")
trap 'rm -rf "$SNAP"' EXIT
tar -C "$ROOT" --exclude=./.git --exclude=./archive -cf - . | tar -C "$SNAP" -xf -

# A plain bridge cannot reach port 80 on some networks (apt's default); host networking can.
# systemd mode never shares the host network: a PID 1 systemd must not touch the host's links.
NET=${DOT_TEST_NET:-host}

docker_run() { # DISTRO TAG CMD...
  local d=$1 tag=$2
  shift 2
  timeout 3600 docker run --rm --network "$NET" -v "$SNAP:/src:ro" -v "$LOGS/run:/out" \
    -e NO_COLOR=1 -e DOT_TEST_TAG="$tag" -e DOT_TEST_DISTRO="$d" "${IMAGE[$d]}" "$@"
}

docker_systemd() { # DISTRO TAG
  local d=$1 tag=$2 cid rc i state
  [[ -n ${SYSTEMD_BOOT[$d]:-} ]] || { echo "no systemd boot recipe for $d"; return 1; }
  cid=$(docker run -d --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --tmpfs /run --tmpfs /run/lock -v "$SNAP:/src:ro" -v "$LOGS/run:/out" \
    -e NO_COLOR=1 -e container=docker "${IMAGE[$d]}" sh -c "${SYSTEMD_BOOT[$d]}") || return 1
  for i in $(seq 1 120); do
    state=$(docker exec "$cid" systemctl is-system-running 2>/dev/null)
    [[ $state == running || $state == degraded ]] && break
    sleep 2
  done
  echo "SYSTEMD_STATE=$state"
  timeout 3600 docker exec -e NO_COLOR=1 -e DOT_TEST_TAG="$tag" -e DOT_TEST_DISTRO="$d" "$cid" \
    sh /src/dot/tests/in-container.sh apply "$host"
  rc=$?
  docker rm -f "$cid" >/dev/null
  return $rc
}

one() {
  local d=$1 tag="$mode-$1" log="$LOGS/$mode-$1.log"
  [[ -n ${IMAGE[$d]:-} ]] || { echo "$d: unknown distro"; return 1; }
  rm -f "$LOGS/run/$tag".{trace,jsonl}
  local t0=$SECONDS rc
  if [[ $mode == systemd ]]; then NET=bridge docker_systemd "$d" "$tag" >"$log" 2>&1
  else docker_run "$d" "$tag" sh /src/dot/tests/in-container.sh "$mode" "$host" >"$log" 2>&1
  fi
  rc=$?
  local secs=$((SECONDS - t0))
  if [[ $mode == names ]]; then
    printf '%-9s %s  %4ss  %s\n' "$d" "$([[ $rc == 0 ]] && echo PASS || echo FAIL)" "$secs" \
      "$(grep -c '✗' "$log") unknown names"
    return $rc
  fi
  verdict "$d" "$log" "$secs" "$LOGS/run/$tag.jsonl"
}

# section LOG NAME: the lines of one ===== section of a container log
section() { awk -v s="===== $2" '$0 == s {f = 1; next} /^===== / {f = 0} f' "$1"; }

GITHUB_OPS='git clone|mise install|install_plugins|installer-|mise/conf.d|uv tool install|Lazy! install'

verdict() {
  local d=$1 log=$2 secs=$3 report=$4 why=() m flaky=0
  grep -q 'github.com is unreachable\|api.github.com\|github.com.*timed out' "$log" && flaky=1

  # the second run: nothing may change (commands that needed github may retry where it dropped out)
  local repeated
  repeated=$(section "$log" run2 | grep '^  \$ ' || true)
  ((flaky)) && repeated=$(grep -vE "$GITHUB_OPS" <<<"$repeated" || true)
  [[ -z $repeated ]] || why+=("2nd run repeated: $(head -3 <<<"$repeated" | sed 's/^  \$ //' | paste -sd'|')")

  local failed
  failed=$(section "$log" run2 | sed -n 's/.*done with failures in: \([^·]*\) ·.*/\1/p')
  for m in $failed; do
    ((flaky)) && [[ $m == shell || $m == mise ]] && continue
    why+=("$m failed")
  done

  local pass=0 total=0 bad
  if [[ -s $report ]]; then
    pass=$(grep -c '"result":"pass"' "$report")
    total=$(grep -cE '"result":"(pass|fail)"' "$report")
    bad=$(grep '"result":"fail"' "$report" || true)
    ((flaky)) && bad=$(grep -vE '"kind":"(shell|mise)"|"item":"nvim: ' <<<"$bad" || true)
    [[ -z $bad ]] || why+=("verify: $(grep -c . <<<"$bad") item(s) failed: $(sed -E 's/.*"kind":"([^"]*)","item":"([^"]*)".*/\1 \2/' <<<"$bad" | head -3 | paste -sd'|')")
  else
    why+=("no verify report")
  fi

  # read-only commands never fail; the dry run after all that predicts nothing to do
  local c
  for c in doctor hosts capture diff; do
    grep -q "^CMD_${c}_EXIT=0" "$log" || why+=("dot $c failed")
  done
  local dry
  dry=$(section "$log" dry | grep '^  \$ ' || true)
  ((flaky)) && dry=$(grep -vE "$GITHUB_OPS" <<<"$dry" || true)
  [[ -z $dry ]] || why+=("dry run predicts: $(head -2 <<<"$dry" | sed 's/^  \$ //' | paste -sd'|')")

  local note=''
  ((flaky)) && note="  (github.com dropped out: shell/mise excused)"
  if ((${#why[@]})); then
    printf '%-9s FAIL  %4ss  verify %s/%s  %s%s\n' "$d" "$secs" "$pass" "$total" "$(IFS=';'; echo "${why[*]}")" "$note"
    return 1
  fi
  printf '%-9s PASS  %4ss  verify %s/%s%s\n' "$d" "$secs" "$pass" "$total" "$note"
}

echo "mode $mode · host $host · ${#ORDER[@]} distro(s) · $jobs at a time"
rc=0 running=0
for d in "${ORDER[@]}"; do
  one "$d" &
  running=$((running + 1))
  if ((running >= jobs)); then wait -n || rc=1; running=$((running - 1)); fi
done
while ((running > 0)); do wait -n || rc=1; running=$((running - 1)); done
echo "logs: $LOGS · reports and traces: $LOGS/run"
exit $rc

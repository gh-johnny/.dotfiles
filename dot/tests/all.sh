#!/usr/bin/env bash
# Everything CI runs, here: lint, unit tests under kcov, the distro matrix in every mode, then the
# coverage report (lines + items). Needs docker.
#
#   dot/tests/all.sh [-j jobs] [--quick]      --quick: arch debian fedora alpine only
#
# Report: ~/.cache/dot-tests/coverage.md (and .json).
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
LOGS=${DOT_TEST_LOGS:-$HOME/.cache/dot-tests}
export DOT_TEST_LOGS=$LOGS
T="$ROOT/dot/tests"
jobs=4 quick=0
while (($#)); do
  case $1 in -j) jobs=$2; shift ;; --quick) quick=1 ;; *) echo "unknown option $1"; exit 2 ;; esac
  shift
done

rc=0
step() { printf '\n\033[1m━━ %s\033[0m\n' "$*"; }

step lint
"$T/lint.sh" || rc=1

step "unit tests (bats under kcov)"
docker image inspect dot-test >/dev/null 2>&1 || docker build --network host -q -t dot-test -f "$T/Dockerfile" "$T" >/dev/null
rm -rf "$LOGS/coverage/unit" && mkdir -p "$LOGS/coverage"
docker run --rm --security-opt seccomp=unconfined -e BATS_LIB_PATH=/usr/lib/bats \
  -v "$ROOT:/src:ro" -v "$LOGS/coverage:/out" -w /src/dot dot-test \
  kcov --include-path=/src/dot/lib,/src/dot/modules,/src/dot/bin --bash-parse-files-in-dir=/src/dot \
  /out/unit bats tests/unit | grep -vE '^ok ' || rc=1
cp "$LOGS"/coverage/unit/bats.*/cobertura.xml "$LOGS/coverage/cobertura.xml" 2>/dev/null

rm -f "$LOGS"/run/*.{trace,jsonl}
if ((quick)); then set -- arch debian fedora alpine; else set --; fi
step "names"
"$T/matrix.sh" -m names -j "$jobs" "$@" || rc=1
step "apply (root)"
"$T/matrix.sh" -m apply -j "$jobs" "$@" || rc=1
step "user (sudo)"
"$T/matrix.sh" -m user -j "$jobs" arch debian fedora alpine || rc=1
step "systemd (PID 1, host vps)"
"$T/matrix.sh" -m systemd -j 2 || rc=1

step coverage
python3 "$T/coverage.py" --cobertura "$LOGS/coverage/cobertura.xml" --runs "$LOGS/run" \
  --md "$LOGS/coverage.md" --json "$LOGS/coverage.json" || rc=1
echo "report: $LOGS/coverage.md"
exit $rc

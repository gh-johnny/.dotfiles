#!/usr/bin/env bash
# ShellCheck over everything dot runs (through docker when shellcheck is not installed).
# SC2034: variables are set in one sourced file and read in another; SC2088: "~" in messages.
set -uo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$ROOT" || exit 1
files=(install.sh setup.sh dot/bin/dot dot/lib/*.sh dot/lib/pkg/*.sh dot/lib/init/*.sh dot/modules/*.sh dot/tests/*.sh dot/hosts/*.conf)
args=(-x -S warning -e "SC1090,SC1091,SC2034,SC2088")
if command -v shellcheck >/dev/null; then shellcheck "${args[@]}" "${files[@]}"
else docker run --rm -v "$ROOT:/mnt:ro" -w /mnt koalaman/shellcheck:stable "${args[@]}" "${files[@]}"
fi && echo "shellcheck: clean"

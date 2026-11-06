#!/usr/bin/env bash
# Retired: the staged installer that lived here is now `dot` (dot/README.md), which does the same
# on any distro and can be rerun safely. Kept so the old command keeps working.
set -euo pipefail
echo "setup.sh is now: install.sh --host pc  (then just: dot status / dot apply)"
exec bash "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/install.sh" --host pc "$@"

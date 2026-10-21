#!/usr/bin/env bash
# The VPS shell that stow cannot carry: a minimal ~/.zshrc with the `bifrost ready` login hook, and
# the `ai` wrapper (a copy: a symlink breaks the launcher's repo-root detection). Idempotent; the
# files that were there before the first run are kept as *.pre-psync. Run it as jo on the VPS:
#
#   bash ~/projects/dotfiles/vps/install.sh
#
# bifrost itself (and the public-SSH guard) comes from its own checkout: see ~/projects/bifrost/RUNBOOK.md.

set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# keep_once FILE: save what is there before the first overwrite, never again.
keep_once() {
  [[ ! -e $1 || -e $1.pre-psync ]] || cp -p "$1" "$1.pre-psync"
}

keep_once "$HOME/.zshrc"
install -m 644 "$HERE/zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.local/bin"
keep_once "$HOME/.local/bin/ai"
install -m 755 "$HERE/ai" "$HOME/.local/bin/ai"
echo "installed ~/.zshrc and ~/.local/bin/ai (originals, if any, kept as *.pre-psync)"

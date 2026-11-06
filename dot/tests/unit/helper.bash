# shellcheck shell=bash
# Shared setup for the bats unit tests: dot's libraries loaded into the test shell, against a
# throwaway HOME, DOTFILES and manifest, so nothing touches the machine running the tests.

bats_load_library bats-support
bats_load_library bats-assert

DOT_SRC=$(cd "$BATS_TEST_DIRNAME/../.." && pwd) # the real dot/, whose code is under test

load_dot() {
  export HOME="$BATS_TEST_TMPDIR/home" NO_COLOR=1 USER=tester
  mkdir -p "$HOME"
  DOT_ROOT=$DOT_SRC
  DOTFILES="$BATS_TEST_TMPDIR/dotfiles"
  mkdir -p "$DOTFILES"
  DOT_RUN="$BATS_TEST_TMPDIR/run"
  # shellcheck source=../../lib/core.sh
  source "$DOT_ROOT/lib/core.sh"
  source "$DOT_ROOT/lib/os.sh"
  source "$DOT_ROOT/lib/pkg.sh"
  source "$DOT_ROOT/lib/manifest.sh"
  local m
  for m in "$DOT_ROOT"/modules/*.sh; do source "$m"; done
  DOT_STATE="$HOME/.local/state/dot"
  DOT_CONFIG="$HOME/.config/dot"
  DOT_SKIP=() DOT_ONLY=()
  host_defaults
}

# fake_backend: an in-memory package manager. INSTALLED and AVAILABLE are space-separated names.
fake_backend() {
  OS_PKG=${1:-fake} OS_ID=fakeos OS_LIBC=glibc
  INSTALLED=${INSTALLED:-} AVAILABLE=${AVAILABLE:-}
  be_missing() { local p; for p; do [[ " $INSTALLED " == *" $p "* ]] || echo "$p"; done; }
  be_available() { [[ " $AVAILABLE " == *" $1 "* ]]; }
  be_install() { INSTALLED+=" $*"; echo "install $*" >>"$BATS_TEST_TMPDIR/installs"; }
  be_refresh() { :; }
  be_explicit() { printf '%s\n' $INSTALLED; }
}

# manifest FILE <<'EOF' ... : write a list into a test manifest dir and point dot at it.
manifest() {
  DOT_MANIFEST="$BATS_TEST_TMPDIR/manifest"
  mkdir -p "$DOT_MANIFEST"
  cat >"$DOT_MANIFEST/$1"
}

# pkgfile PKG RELPATH [CONTENT]: a file in a stow package of the test DOTFILES.
pkgfile() {
  mkdir -p "$(dirname "$DOTFILES/$1/$2")"
  printf '%s\n' "${3:-content of $2}" >"$DOTFILES/$1/$2"
}

changes() { grep -c . "$DOT_RUN/changes" || true; }

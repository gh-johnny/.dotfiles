# shellcheck shell=bash
# core: output, the one place commands that change the machine go through, privileges, prompts.

DOT_STATE=${XDG_STATE_HOME:-$HOME/.local/state}/dot
DOT_CONFIG=${XDG_CONFIG_HOME:-$HOME/.config}/dot
DOT_DRY=${DOT_DRY:-0}
DOT_YES=${DOT_YES:-0}
DOT_VERBOSE=${DOT_VERBOSE:-0}
# Per-invocation scratch: change log, values one module hands to the next.
DOT_RUN=$(mktemp -d "${TMPDIR:-/tmp}/dot.XXXXXX")
trap 'rm -rf "$DOT_RUN"' EXIT
: >"$DOT_RUN/changes"

if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  C_0=$'\e[0m' C_B=$'\e[1m' C_D=$'\e[2m' C_R=$'\e[31m' C_G=$'\e[32m' C_Y=$'\e[33m' C_C=$'\e[36m'
else
  C_0='' C_B='' C_D='' C_R='' C_G='' C_Y='' C_C=''
fi

say()     { printf '%s\n' "$*"; }
info()    { printf '%s→%s %s\n' "$C_C" "$C_0" "$*"; }
ok()      { printf '%s✓%s %s\n' "$C_G" "$C_0" "$*"; }
warn()    { printf '%s!%s %s\n' "$C_Y" "$C_0" "$*" >&2; }
err()     { printf '%s✗%s %s\n' "$C_R" "$C_0" "$*" >&2; }
die()     { err "$*"; exit 1; }
debug()   { [[ $DOT_VERBOSE == 1 ]] && printf '%s  · %s%s\n' "$C_D" "$*" "$C_0" >&2; return 0; }
section() { printf '\n%s━━ %s%s\n' "$C_B" "$*" "$C_0"; }

# status lines, used by `dot status`: state is ok | miss | drift | skip
report() {
  local state=$1; shift
  case $state in
    ok)    printf '  %s✓%s %s\n' "$C_G" "$C_0" "$*" ;;
    miss)  printf '  %s✗%s %s\n' "$C_R" "$C_0" "$*"; echo miss >>"$DOT_RUN/issues" ;;
    drift) printf '  %s≠%s %s\n' "$C_Y" "$C_0" "$*"; echo drift >>"$DOT_RUN/issues" ;;
    skip)  printf '  %s-%s %s\n' "$C_D" "$C_0" "$*" ;;
  esac
}

has() { command -v "$1" >/dev/null 2>&1; }

# run CMD...: every command that changes the machine goes through here. It is printed, counted
# when it succeeds (a second `dot apply` must count zero) and only echoed under --dry-run.
run() {
  printf '%s  $ %s%s\n' "$C_D" "$*" "$C_0"
  if [[ $DOT_DRY == 1 ]]; then printf '%s\n' "$*" >>"$DOT_RUN/changes"; return 0; fi
  "$@" || return
  printf '%s\n' "$*" >>"$DOT_RUN/changes"
}

# root CMD...: run() as root, through sudo when we are not root already.
root() {
  if [[ $EUID -eq 0 ]]; then run "$@"
  elif has sudo; then run sudo "$@"
  elif has doas; then run doas "$@"
  else err "needs root and there is no sudo/doas: $*"; return 1
  fi
}

# root_read CMD...: like root, for read-only queries (not counted, runs under --dry-run too).
root_read() {
  if [[ $EUID -eq 0 ]]; then "$@"
  elif has sudo; then sudo "$@"
  else doas "$@"
  fi
}

# confirm QUESTION [y|n]: yes under --yes; the default when there is no terminal to ask.
confirm() {
  local q=$1 def=${2:-n} a
  [[ $DOT_YES == 1 ]] && return 0
  if [[ ! -t 0 ]]; then [[ $def == y ]]; return; fi
  read -rp "$q [$([[ $def == y ]] && echo Y/n || echo y/N)] " a
  a=${a:-$def}
  [[ $a == [Yy]* ]]
}

# fetch URL: print a URL's body (curl, else wget).
fetch() {
  if has curl; then curl -fsSL --retry 2 "$1"
  elif has wget; then wget -qO- "$1"
  else err "neither curl nor wget"; return 1
  fi
}

# online HOST: can we reach it? (cached per run, 5s budget)
online() {
  local host=$1 f="$DOT_RUN/online.${1//[^a-z0-9.]/_}"
  [[ -f $f ]] && { [[ $(<"$f") == 1 ]]; return; }
  if has curl && curl -fsS -m 5 -o /dev/null "https://$host" 2>/dev/null; then echo 1 >"$f"
  elif has wget && wget -q -T 5 -O /dev/null "https://$host" 2>/dev/null; then echo 1 >"$f"
  else echo 0 >"$f"
  fi
  [[ $(<"$f") == 1 ]]
}

# git_clone URL DIR: shallow clone, unless DIR already holds a checkout.
git_clone() {
  [[ -d $2/.git ]] && return 0
  if ! online github.com && [[ $1 == *github.com* ]]; then
    warn "github.com is unreachable, skipping clone of $1"; return 1
  fi
  run git clone --depth=1 --quiet "$1" "$2"
}

# in_list WORD LIST...: is WORD one of LIST?
in_list() { local w=$1 x; shift; for x; do [[ $x == "$w" ]] && return 0; done; return 1; }

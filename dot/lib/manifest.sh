# shellcheck shell=bash
# manifest: hosts (what this machine gets) and the lists under dot/manifest (what each group means).
#
# Every list file starts each line with a group; a host turns groups on with DOT_GROUPS, so one
# knob decides what lands on a machine across packages, npm, uv, installers and services.

DOT_HOSTS_DIR="$DOT_ROOT/hosts"
DOT_MANIFEST="$DOT_ROOT/manifest"

# ── hosts ────────────────────────────────────────────────────────────────────

host_defaults() {
  DOT_GROUPS=() DOT_STOW=() DOT_STOW_NOFOLD=() DOT_MODULES=()
  DOT_SHELL=zsh DOT_OMARCHY=0 DOT_FLATPAK=0 DOT_SSH_KEY='' DOT_SSH_KEY_COMMENT=''
  DOT_HOST_INCLUDED=()
}

# include NAME: pull another host file in (hosts compose: pc = desktop + extras).
include() {
  local f="$DOT_HOSTS_DIR/$1.conf"
  [[ -f $f ]] || die "host '$1' not found ($f)"
  in_list "$1" "${DOT_HOST_INCLUDED[@]}" && return 0
  DOT_HOST_INCLUDED+=("$1")
  # shellcheck disable=SC1090
  source "$f"
}

# drop ARRAY WORD...: take words out of a host array (vps = cli without my zshrc).
drop() {
  local -n _arr=$1
  shift
  local keep=() x
  for x in "${_arr[@]}"; do in_list "$x" "$@" || keep+=("$x"); done
  _arr=("${keep[@]}")
}

host_list() {
  local f
  for f in "$DOT_HOSTS_DIR"/*.conf; do
    f=${f##*/}; f=${f%.conf}
    [[ $f == _* ]] || echo "$f"
  done
}

host_describe() { sed -n '1s/^# *//p' "$DOT_HOSTS_DIR/$1.conf"; }

# host_pick [NAME]: --host, else the one this machine remembers, else a file named after the
# hostname, else ask (or cli when nobody is there to answer).
host_pick() {
  local h=${1:-} saved="$DOT_CONFIG/host"
  if [[ -z $h && -s $saved ]]; then h=$(<"$saved"); fi
  if [[ -z $h ]]; then
    local hn
    hn=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || true)
    [[ -n $hn && -f $DOT_HOSTS_DIR/$hn.conf ]] && h=$hn
  fi
  if [[ -z $h && -t 0 && $DOT_YES != 1 ]]; then
    say "Which host profile is this machine?"
    local names=() n i=1
    mapfile -t names < <(host_list)
    for n in "${names[@]}"; do printf '  %d) %-8s %s\n' "$i" "$n" "$(host_describe "$n")"; i=$((i + 1)); done
    read -rp "Choice [cli]: " n
    if [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= ${#names[@]})); then h=${names[n - 1]}; else h=${n:-cli}; fi
  fi
  DOT_HOST=${h:-cli}
  [[ -f $DOT_HOSTS_DIR/$DOT_HOST.conf ]] || die "host '$DOT_HOST' not found; have: $(host_list | tr '\n' ' ')"
}

host_load() {
  host_defaults
  include "$DOT_HOST"
}

host_remember() {
  [[ $DOT_DRY == 1 ]] && return 0
  mkdir -p "$DOT_CONFIG"
  [[ -s $DOT_CONFIG/host && $(<"$DOT_CONFIG/host") == "$DOT_HOST" ]] || echo "$DOT_HOST" >"$DOT_CONFIG/host"
}

# ── lists ────────────────────────────────────────────────────────────────────

# list_lines FILE: the lines of FILE whose group is on, group stripped, comments dropped.
list_lines() {
  local f="$DOT_MANIFEST/$1" group rest
  [[ -f $f ]] || return 0
  while read -r group rest; do
    [[ -z $group || $group == \#* ]] && continue
    rest=${rest%%#*}
    in_list "$group" "${DOT_GROUPS[@]}" && printf '%s\n' "$rest"
  done <"$f"
}

# list_lines_all FILE: every line regardless of group, group kept (for name checks).
list_lines_all() {
  local f="$DOT_MANIFEST/$1" line
  [[ -f $f ]] || return 0
  while read -r line; do
    line=${line%%#*}
    [[ -n ${line//[[:space:]]/} ]] && printf '%s\n' "$line"
  done <"$f"
}

# pkg_parse LOGICAL KEY=VAL...: what packages.list says for this backend. Sets
#   P_SYS     system package names ('' when the system should not provide it)
#   P_MISE    mise tool to fall back to
#   P_SCRIPT  installers.list entry to fall back to
#   P_CMD     a command that, when on PATH, already satisfies it (however it got there)
#   P_NA      1 when the line does not apply to this backend at all (only=)
pkg_parse() {
  local logical=$1 kv k v only='' explicit='' has_explicit=0
  shift
  P_MISE='' P_SCRIPT='' P_CMD='' P_NA=0
  for kv; do
    k=${kv%%=*} v=${kv#*=}
    case $k in
      mise) P_MISE=$v ;;
      script) P_SCRIPT=$v ;;
      cmd) P_CMD=$v ;;
      only) only=$v ;;
      "$OS_PKG") explicit=$v has_explicit=1 ;;
    esac
  done
  if [[ -n $only && ",$only," != *",$OS_PKG,"* ]]; then P_SYS='' P_MISE='' P_SCRIPT='' P_NA=1; return; fi
  if ((has_explicit)); then
    [[ $explicit == - ]] && P_SYS='' || P_SYS=${explicit//,/ }
  else
    P_SYS=$logical
  fi
}

# installer_line NAME: the installers.list line for NAME (any group), as "check shell url".
installer_line() {
  local group name rest
  while read -r group name rest; do
    [[ $group == \#* || -z $group ]] && continue
    [[ $name == "$1" ]] && { printf '%s\n' "${rest%%#*}"; return 0; }
  done <"$DOT_MANIFEST/installers.list"
  return 1
}

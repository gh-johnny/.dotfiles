# shellcheck shell=bash
# verify: item by item proof that the host is what its profile says, deeper than `status`:
# packages are installed *and run*, links resolve *and* the program reads them (checks.list),
# services are enabled *and* running when there is an init to run them.
#
# Every item is one record: RESULT (pass | fail | skip) KIND ITEM DETAIL. `dot verify --report F`
# writes them as JSON lines, which dot/tests/coverage.sh folds into the item × distro coverage.

V_TSV=''

# vrec RESULT KIND ITEM [DETAIL]
vrec() {
  local r=$1 kind=$2 item=$3 detail=${4:-}
  printf '%s\t%s\t%s\t%s\n' "$r" "$kind" "$item" "${detail//$'\n'/ }" >>"$V_TSV"
  case $r in
    pass) printf '  %s✓%s %-10s %s%s\n' "$C_G" "$C_0" "$kind" "$item" "${detail:+ $C_D($detail)$C_0}" ;;
    fail) printf '  %s✗%s %-10s %s%s\n' "$C_R" "$C_0" "$kind" "$item" "${detail:+ ($detail)}" ;;
    skip) [[ $DOT_VERBOSE == 1 ]] && printf '  %s-%s %-10s %s%s\n' "$C_D" "$C_0" "$kind" "$item" "${detail:+ ($detail)}" ;;
  esac
  return 0
}

# _runs CMD: does the program start? First version-ish flag that exits 0 wins. Returns 126 when
# the kernel refused to exec it (file capabilities in an unprivileged container).
_runs() {
  local f rc=1 flags=(--version -V version -v)
  [[ -n ${2:-} ]] && flags=("$2")
  for f in "${flags[@]}"; do
    LANG=${LANG:-C.UTF-8} timeout 20 "$1" "$f" </dev/null >/dev/null 2>&1 && return 0
    rc=$?
    ((rc == 126)) && return 126
  done
  return 1
}

_where() { # how is a packages.list line satisfied here (prints it), or fail
  local logical=$1 path
  if [[ -n $P_CMD ]] && has_real "$P_CMD" && path=$(command -v "$P_CMD"); then
    if [[ $path == "${MISE_DATA_DIR:-$HOME/.local/share/mise}"/* ]]; then echo "mise"
    elif [[ -n $P_SYS && -z $(pkg_missing $P_SYS) ]]; then echo "$OS_PKG"
    else echo "$path"
    fi
    return 0
  fi
  if [[ -n $P_SYS && -z $(pkg_missing $P_SYS) ]]; then echo "$OS_PKG"; return 0; fi
  if [[ -n $P_MISE ]] && has mise && (cd "$HOME" && mise where "$P_MISE") >/dev/null 2>&1; then echo mise; return 0; fi
  return 1
}

verify_system() {
  local logical rest how name src
  while read -r logical rest; do
    # shellcheck disable=SC2086
    pkg_parse "$logical" $rest
    ((P_NA)) && continue
    if [[ -z $P_SYS && -z $P_MISE && -z $P_SCRIPT ]]; then vrec skip pkg "$logical" "not on $OS_PKG"; continue; fi
    if ! how=$(_where "$logical"); then vrec fail pkg "$logical" "not installed"; continue; fi
    if [[ -n $P_CMD && $P_VER != - ]]; then
      local rc=0
      _runs "$P_CMD" $P_VER || rc=$?
      case $rc in
        0) ;;
        126)
          if [[ $OS_CONTAINER == 1 ]]; then vrec skip pkg "$logical" "$how; exec refused in this container (file capabilities)"
          else vrec fail pkg "$logical" "$how; $P_CMD: permission denied"
          fi
          continue ;;
        *) vrec fail pkg "$logical" "$how; $P_CMD does not run"; continue ;;
      esac
    fi
    vrec pass pkg "$logical" "$how"
  done < <(list_lines packages.list)
  while IFS=$'\t' read -r name src; do
    if [[ -z $(pkg_missing "$name") ]]; then vrec pass pkg "$name" "$src"; else vrec fail pkg "$name" "$src: not installed"; fi
  done < <(arch_lines)
}

verify_links() {
  local pkg state rel
  for pkg in "${DOT_STOW[@]}"; do
    [[ -d $DOTFILES/$pkg ]] || { vrec fail link "$pkg" "no such package"; continue; }
    while IFS=$'\t' read -r state rel; do
      if [[ $state == ok ]]; then vrec pass link "$pkg/$rel"; else vrec fail link "$pkg/$rel" "$state"; fi
    done < <(_link_walk "$pkg")
  done
}

verify_checks() {
  local pkg prog line desc cmd out
  while read -r pkg prog line; do
    [[ -z $pkg || $pkg == \#* ]] && continue
    desc=${line%% :: *} cmd=${line#* :: }
    desc=${desc%"${desc##*[![:space:]]}"}
    in_list "$pkg" "${DOT_STOW[@]}" || continue
    has "$prog" || { vrec skip config "$pkg: $desc" "$prog not installed"; continue; }
    if out=$(cd "$HOME" && timeout 180 bash -c "$cmd" 2>&1) && ! grep -qiE 'error|E[0-9]+:' <<<"$out"; then
      vrec pass config "$pkg: $desc"
    else
      vrec fail config "$pkg: $desc" "$(head -c 300 <<<"$out")"
    fi
  done <"$DOT_MANIFEST/checks.list"
}

verify_shell() {
  local want
  want=$(_shell_path "$DOT_SHELL")
  if _is_login_shell "$want"; then vrec pass shell "login shell" "$want"
  else vrec fail shell "login shell" "is $(_login_shell)"
  fi
  if [[ $DOT_SHELL == zsh ]] && in_list zsh "${DOT_STOW[@]}"; then
    [[ -f $P10K_DIR/powerlevel10k.zsh-theme ]] && vrec pass shell powerlevel10k || vrec fail shell powerlevel10k "missing"
  fi
  if in_list tmux "${DOT_STOW[@]}"; then
    [[ -x $TPM_DIR/tpm ]] && vrec pass shell "tmux plugin manager" || vrec fail shell "tmux plugin manager" "missing"
    local p
    for p in $(sed -nE "s/^set -g @plugin '([^']+)'.*/\1/p" "$HOME/.tmux.conf" 2>/dev/null); do
      [[ -d $HOME/.tmux/plugins/${p##*/} ]] && vrec pass shell "tmux plugin $p" || vrec fail shell "tmux plugin $p" "not installed"
    done
  fi
  if in_list nvim "${DOT_STOW[@]}" && has nvim; then
    local missing
    if missing=$(_nvim_plugins_missing); then
      [[ -z $missing ]] && vrec pass shell "neovim plugins" || vrec fail shell "neovim plugins" "missing: $(echo $missing)"
    else vrec fail shell "neovim plugins" "lazy.nvim not installed"
    fi
  fi
}

verify_services() {
  # shellcheck disable=SC1090
  source "$DOT_ROOT/lib/init/$OS_INIT.sh"
  local scope name
  while IFS=$'\t' read -r scope name; do
    case $scope in
      usergroup)
        [[ $EUID -eq 0 ]] && { vrec skip service "group $name" "root"; continue; }
        if ! _group_exists "$name"; then vrec skip service "group $name" "no such group"
        elif _in_group "$name"; then vrec pass service "group $name"
        else vrec fail service "group $name" "not a member"
        fi ;;
      *)
        if ! svc_exists "$scope" "$name"; then vrec skip service "$scope $name" "not installed"; continue; fi
        if ! svc_enabled "$scope" "$name"; then vrec fail service "$scope $name" "not enabled"; continue; fi
        if [[ $OS_INIT_LIVE == 1 && $OS_INIT == systemd ]]; then
          if svc_active "$scope" "$name"; then vrec pass service "$scope $name" "enabled, active"
          else vrec fail service "$scope $name" "enabled but $(systemctl is-active "$name" 2>/dev/null)"
          fi
        else vrec pass service "$scope $name" "enabled (init not running)"
        fi ;;
    esac
  done < <(_svc_lines)
}

verify_tools() {
  local name spec opts have check shell url p
  if in_list uv "${DOT_MODULES[@]}" && [[ -n $(list_lines uv.list) ]]; then
    have=$(has uv && _uv_tools)
    while read -r name spec opts; do
      if installer_unsupported "${spec:-} ${opts:-}"; then vrec skip uv "$name" "needs glibc"
      elif grep -qxF "$name" <<<"$have"; then vrec pass uv "$name"; else vrec fail uv "$name" "not installed"; fi
    done < <(list_lines uv.list)
  fi
  if in_list npm "${DOT_MODULES[@]}" && [[ -n $(list_lines npm.list) ]]; then
    have=$(_npm_ok && _npm_global)
    for p in $(list_lines npm.list | awk 'NF {print $1}'); do
      grep -qxF "$p" <<<"$have" && vrec pass npm "$p" || vrec fail npm "$p" "not installed"
    done
  fi
  if in_list installers "${DOT_MODULES[@]}"; then
    while read -r name check shell url flags; do
      if installer_present "$check"; then vrec pass installer "$name"
      elif installer_unsupported "${flags:-}"; then vrec skip installer "$name" "needs ${flags#libc=}"
      else vrec fail installer "$name" "$check missing"
      fi
    done < <(list_lines installers.list)
  fi
  if in_list mise "${DOT_MODULES[@]}" && mise_cannot_run; then vrec skip mise tools "no /lib64 loader (nix without nix-ld)"; fi
  if in_list mise "${DOT_MODULES[@]}" && has mise && ! mise_cannot_run; then
    local line
    while read -r line; do [[ -n $line ]] && vrec fail mise "$line" "missing"; done < <(cd "$HOME" && mise ls --missing 2>/dev/null | awk '{print $1"@"$2}')
    while read -r line; do [[ -n $line ]] && vrec pass mise "$line"; done < <(cd "$HOME" && mise ls --installed --current 2>/dev/null | awk '{print $1"@"$2}')
  fi
}

verify_misc() {
  [[ $(readlink -f "$HOME/.local/bin/dot" 2>/dev/null) == "$(readlink -f "$DOT_ROOT/bin/dot")" ]] &&
    vrec pass self "~/.local/bin/dot" || vrec fail self "~/.local/bin/dot" "not linked"
  if [[ $DOT_OMARCHY == 1 ]]; then
    [[ -d $OMARCHY_DIR ]] && vrec pass omarchy omarchy "$(cat "$OMARCHY_DIR/version" 2>/dev/null)" || vrec fail omarchy omarchy "not installed"
  fi
  if [[ -n $DOT_SSH_KEY ]] && in_list ssh "${DOT_MODULES[@]}"; then
    [[ -f ${DOT_SSH_KEY/#\~/$HOME} ]] && vrec pass ssh "key $DOT_SSH_KEY" || vrec skip ssh "key $DOT_SSH_KEY" "created interactively"
  fi
  local id
  for id in $(_flatpak_wanted); do
    has flatpak && flatpak info --user "$id" >/dev/null 2>&1 && vrec pass flatpak "$id" || vrec fail flatpak "$id" "not installed"
  done
}

_json_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/ }; printf '"%s"' "$s"; }

# verify_run [REPORT]: everything, then the summary. Exit 1 on any fail.
verify_run() {
  local report=${1:-}
  V_TSV="$DOT_RUN/verify.tsv"
  : >"$V_TSV"
  local sections=(system links checks shell services tools misc) s
  for s in "${sections[@]}"; do "verify_$s"; done
  local pass fail skip
  pass=$(grep -c '^pass' "$V_TSV") fail=$(grep -c '^fail' "$V_TSV") skip=$(grep -c '^skip' "$V_TSV")
  if [[ -n $report ]]; then
    local r kind item detail distro
    distro=${DOT_TEST_DISTRO:-$OS_ID}
    : >"$report"
    while IFS=$'\t' read -r r kind item detail; do
      printf '{"distro":%s,"os":%s,"host":%s,"kind":%s,"item":%s,"result":%s,"detail":%s}\n' \
        "$(_json_str "$distro")" "$(_json_str "$OS_NAME")" "$(_json_str "$DOT_HOST")" "$(_json_str "$kind")" \
        "$(_json_str "$item")" "$(_json_str "$r")" "$(_json_str "$detail")" >>"$report"
    done <"$V_TSV"
  fi
  say
  local total=$((pass + fail))
  if ((fail)); then
    err "verify: $pass/$total passed, $fail failed, $skip not applicable"
    return 1
  fi
  ok "verify: $pass/$total passed, $skip not applicable"
}

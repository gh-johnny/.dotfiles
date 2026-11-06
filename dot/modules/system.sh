# shellcheck shell=bash
# system: the distro packages of the host's groups (manifest/packages.list, plus manifest/arch.list
# on pacman). A package the repos do not carry falls back to mise or to an installer script; the
# plan below decides once and the mise and installers modules pick up the fallbacks.

# system_plan: resolve every packages.list line of the active groups. Writes, under $DOT_RUN,
#   plan-sys     "logical<TAB>names" to install from the repos
#   plan-mise    mise tools to install
#   plan-script  installers.list entries to run
#   plan-ok      satisfied lines, plan-gone lines that resolve to nothing here
system_plan() {
  [[ -f $DOT_RUN/plan-done ]] && return 0
  local logical rest missing p avail
  : >"$DOT_RUN/plan-sys"; : >"$DOT_RUN/plan-mise"; : >"$DOT_RUN/plan-script"
  : >"$DOT_RUN/plan-ok"; : >"$DOT_RUN/plan-gone"
  while read -r logical rest; do
    # shellcheck disable=SC2086 # rest is KEY=VAL words
    pkg_parse "$logical" $rest
    ((P_NA)) && continue
    if [[ -n $P_CMD ]] && has_real "$P_CMD"; then
      # satisfied by mise itself (an earlier run's fallback): still mise's, keep it in its config
      if [[ -n $P_MISE && $(command -v "$P_CMD") == "${MISE_DATA_DIR:-$HOME/.local/share/mise}"/* ]]; then
        printf '%s\t%s\n' "$logical" "$P_MISE" >>"$DOT_RUN/plan-mise"
      else
        echo "$logical" >>"$DOT_RUN/plan-ok"
      fi
      continue
    fi
    if [[ -n $P_SYS ]]; then
      # shellcheck disable=SC2086
      missing=$(pkg_missing $P_SYS)
      if [[ -z $missing ]]; then echo "$logical" >>"$DOT_RUN/plan-ok"; continue; fi
      if [[ -z $P_MISE$P_SCRIPT ]]; then
        printf '%s\t%s\n' "$logical" "$(echo $missing)" >>"$DOT_RUN/plan-sys"; continue
      fi
      # A fallback exists: take the repo package only if the repos have it (a name can exist in
      # Debian 13 and not in 12, in Debian and not in Ubuntu...).
      avail=1
      for p in $missing; do pkg_available "$p" || { avail=0; break; }; done
      if ((avail)); then printf '%s\t%s\n' "$logical" "$(echo $missing)" >>"$DOT_RUN/plan-sys"; continue; fi
      debug "$logical: not in the $OS_PKG repos"
    fi
    if [[ -n $P_MISE ]]; then printf '%s\t%s\n' "$logical" "$P_MISE" >>"$DOT_RUN/plan-mise"
    elif [[ -n $P_SCRIPT ]]; then printf '%s\t%s\n' "$logical" "$P_SCRIPT" >>"$DOT_RUN/plan-script"
    else echo "$logical" >>"$DOT_RUN/plan-gone"
    fi
  done < <(list_lines packages.list)
  touch "$DOT_RUN/plan-done"
}

# arch_lines: "name<TAB>repo|aur" for arch.list lines of the active groups (pacman only).
arch_lines() {
  [[ $OS_PKG == pacman ]] || return 0
  local name src
  while read -r name src; do
    [[ -n $name ]] && printf '%s\t%s\n' "$name" "${src:-repo}"
  done < <(list_lines arch.list)
}

mod_system_apply() {
  system_plan
  local sys=() aur=() logical names name src rc=0
  while IFS=$'\t' read -r logical names; do
    # shellcheck disable=SC2206
    sys+=($names)
  done <"$DOT_RUN/plan-sys"
  local arch_missing
  while IFS=$'\t' read -r name src; do
    arch_missing=$(pkg_missing "$name")
    [[ -z $arch_missing ]] && continue
    if [[ $src == aur ]]; then aur+=("$name"); else sys+=("$name"); fi
  done < <(arch_lines)

  if ((${#sys[@]})); then
    info "installing ${#sys[@]} package(s) with $OS_PKG: ${sys[*]}"
    pkg_install "${sys[@]}" || rc=1
  fi
  if ((${#aur[@]})); then
    info "installing ${#aur[@]} AUR package(s): ${aur[*]}"
    aur_install "${aur[@]}" || rc=1
  fi
  if [[ -s $DOT_RUN/pkg-failed ]]; then
    err "$OS_PKG could not install: $(tr '\n' ' ' <"$DOT_RUN/pkg-failed")"
    rc=1
  fi
  [[ -s $DOT_RUN/plan-gone ]] && warn "not available on $OS_PKG and no fallback: $(tr '\n' ' ' <"$DOT_RUN/plan-gone")"
  ((${#sys[@]} + ${#aur[@]})) || ok "packages already installed"
  return $rc
}

mod_system_status() {
  system_plan
  local logical names name src
  report ok "$(wc -l <"$DOT_RUN/plan-ok") package(s) in place"
  while IFS=$'\t' read -r logical names; do report miss "$logical ($OS_PKG: $names)"; done <"$DOT_RUN/plan-sys"
  while IFS=$'\t' read -r logical names; do
    if has mise && mise where "$names" >/dev/null 2>&1; then report ok "$logical (mise: $names)"
    else report miss "$logical (mise: $names)"
    fi
  done <"$DOT_RUN/plan-mise"
  while IFS=$'\t' read -r logical names; do report miss "$logical (installer: $names)"; done <"$DOT_RUN/plan-script"
  while read -r logical; do report skip "$logical (not on $OS_PKG)"; done <"$DOT_RUN/plan-gone"
  local n=0
  while IFS=$'\t' read -r name src; do
    if [[ -n $(pkg_missing "$name") ]]; then report miss "$name ($src)"; else n=$((n + 1)); fi
  done < <(arch_lines)
  ((n)) && report ok "$n Arch package(s) from arch.list in place"
  return 0
}

# dot capture: what was installed by hand and no list knows about.
system_capture() {
  local known="$DOT_RUN/known" line logical rest
  : >"$known"
  # every name any list maps to on this backend, whatever the group: a package another host
  # profile carries is still known, not "untracked"
  while read -r _ logical rest; do
    # shellcheck disable=SC2086
    pkg_parse "$logical" $rest
    # shellcheck disable=SC2086
    printf '%s\n' $P_SYS >>"$known"
  done < <(list_lines_all packages.list)
  if [[ $OS_PKG == pacman ]]; then
    list_lines_all arch.list | awk '{print $2}' >>"$known"
    # what omarchy installs is omarchy's, not mine
    local o
    for o in "$HOME"/.local/share/omarchy/install/omarchy-*.packages; do
      [[ -f $o ]] && grep -vE '^[[:space:]]*(#|$)' "$o" | awk '{print $1}' >>"$known"
    done
  fi
  list_lines_all ignore.list | awk -v b="$OS_PKG" '$1 == b || $1 == "*" {print $2}' >>"$known"
  pkg_explicit | sort -u | grep -vxFf <(sort -u "$known") || true
}

# shellcheck shell=bash
# links: the stow packages of this host, linked into $HOME. Whatever is in the way (a real file an
# installer wrote over a link, a link into somewhere else) is moved to the backup dir first, never
# deleted: $DOT_STATE/backup/<timestamp>/<path>.

# _link_walk PKG: print "state<TAB>relpath" for every file of the package.
#   ok       already resolves to the repo file (directly or through a folded dir link)
#   missing  nothing there yet
#   same     a real file with the same content (an installer copied/sed -i'd over the link)
#   differs  a real file with other content
#   foreign  a symlink (on the path or the file itself) that points somewhere else
_link_walk() {
  local dir="$DOTFILES/$1" f rel t anc p part parts
  while IFS= read -r -d '' f; do
    rel=${f#"$dir"/}
    t="$HOME/$rel"
    if [[ $(readlink -f "$t" 2>/dev/null) == "$(readlink -f "$f")" ]]; then
      printf 'ok\t%s\n' "$rel"; continue
    fi
    # a symlinked ancestor that does not lead into this package is the real obstacle
    anc='' p=$HOME parts=()
    [[ $rel == */* ]] && IFS=/ read -ra parts <<<"${rel%/*}"
    for part in "${parts[@]}"; do
      p="$p/$part"
      if [[ -L $p ]]; then anc=${p#"$HOME"/}; break; fi
      [[ -d $p ]] || break
    done
    # a dir another package folded into one link: stow unfolds it when this package arrives
    if [[ -n $anc && $(readlink -f "$HOME/$anc") == "$(readlink -f "$DOTFILES")"/* ]]; then anc=''; fi
    if [[ -n $anc ]]; then printf 'foreign\t%s\n' "$anc"
    elif [[ -L $t ]]; then printf 'foreign\t%s\n' "$rel"
    elif [[ ! -e $t ]]; then printf 'missing\t%s\n' "$rel"
    elif cmp -s "$t" "$f"; then printf 'same\t%s\n' "$rel"
    else printf 'differs\t%s\n' "$rel"
    fi
  done < <(find "$dir" -mindepth 1 \( -type f -o -type l \) ! -name .stow-local-ignore -print0 | sort -z)
}

_link_backup() { # RELPATH
  local src="$HOME/$1" dst="$DOT_BACKUP/$1"
  [[ -e $src || -L $src ]] || return 0
  act mkdir -p "${dst%/*}" && act mv "$src" "$dst"
}

# _link_fallback PKG: what stow does, for systems without stow (Slackware): one symlink per file.
_link_fallback() {
  local dir="$DOTFILES/$1" f rel
  while IFS= read -r -d '' f; do
    rel=${f#"$dir"/}
    [[ $(readlink -f "$HOME/$rel" 2>/dev/null) == "$(readlink -f "$f")" ]] && continue
    act mkdir -p "$(dirname "$HOME/$rel")"
    act ln -sfn "$f" "$HOME/$rel"
  done < <(find "$dir" -mindepth 1 \( -type f -o -type l \) ! -name .stow-local-ignore -print0)
}

# Dirs many packages share. In an empty home stow would fold the first package's ~/.config into
# one symlink; real dirs keep every package's files side by side, as on a lived-in machine.
LINK_SHARED_DIRS=(.config .local/bin .local/share .local/state .ssh)

mod_links_apply() {
  local pkg state rel rc=0 walk todo d
  DOT_BACKUP="$DOT_STATE/backup/$(date +%Y%m%d-%H%M%S)"
  for d in "${LINK_SHARED_DIRS[@]}"; do
    [[ -e $HOME/$d || -L $HOME/$d ]] && continue
    act mkdir -p "$HOME/$d"
    [[ $d == .ssh ]] && act chmod 700 "$HOME/$d"
  done
  for pkg in "${DOT_STOW[@]}"; do
    [[ -d $DOTFILES/$pkg ]] || { err "stow package '$pkg' does not exist"; rc=1; continue; }
    walk=$(_link_walk "$pkg")
    todo=$(grep -v '^ok' <<<"$walk" || true)
    if [[ -z $todo ]]; then debug "$pkg linked"; continue; fi
    # a symlinked ~/.config (or similar) holds far more than this package: hands off
    if grep -qE $'^foreign\t(\\.config|\\.local|\\.local/share|\\.local/bin|\\.cache|\\.ssh)$' <<<"$todo"; then
      err "$pkg: a top-level dir on its path is a symlink to elsewhere; fix that by hand"; rc=1; continue
    fi
    while IFS=$'\t' read -r state rel; do
      case $state in
        same) info "$pkg: ~/$rel is a copy of the repo file, relinking" ;;
        differs) warn "$pkg: ~/$rel was edited outside the repo; moved to ${DOT_BACKUP/#$HOME/\~}/$rel (diff it and fold what you want back)" ;;
        foreign) warn "$pkg: ~/$rel points elsewhere ($(readlink "$HOME/$rel")); moved to backup" ;;
      esac
      [[ $state == same || $state == differs || $state == foreign ]] && { _link_backup "$rel" || rc=1; }
    done < <(sort -u <<<"$todo")
    if has stow; then
      local opts=(--dir="$DOTFILES" --target="$HOME" --restow)
      in_list "$pkg" "${DOT_STOW_NOFOLD[@]}" && opts+=(--no-folding)
      act stow "${opts[@]}" "$pkg" || { err "stow $pkg failed"; rc=1; continue; }
    else
      _link_fallback "$pkg" || rc=1
    fi
    ok "$pkg linked"
  done
  return $rc
}

mod_links_status() {
  local pkg walk n bad
  for pkg in "${DOT_STOW[@]}"; do
    [[ -d $DOTFILES/$pkg ]] || { report miss "$pkg (no such package in the repo)"; continue; }
    walk=$(_link_walk "$pkg")
    n=$(grep -c . <<<"$walk")
    bad=$(grep -v '^ok' <<<"$walk" || true)
    if [[ -z $bad ]]; then report ok "$pkg ($n files)"; continue; fi
    while IFS=$'\t' read -r state rel; do
      case $state in
        missing) report miss "$pkg: ~/$rel not linked" ;;
        same)    report drift "$pkg: ~/$rel is a real file (same content as the repo; apply relinks it)" ;;
        differs) report drift "$pkg: ~/$rel is a real file and differs from the repo (dot diff $pkg)" ;;
        foreign) report drift "$pkg: ~/$rel links to $(readlink "$HOME/$rel")" ;;
      esac
    done <<<"$bad"
  done
}

# dot diff [PKG...]: what the real files that replaced links changed, against the repo.
links_diff() {
  local pkg state rel any=0
  (($#)) || set -- "${DOT_STOW[@]}"
  for pkg; do
    while IFS=$'\t' read -r state rel; do
      [[ $state == differs ]] || continue
      any=1
      diff -u --label "repo/$pkg/$rel" --label "~/$rel" "$DOTFILES/$pkg/$rel" "$HOME/$rel"
    done < <(_link_walk "$pkg")
  done
  ((any)) || ok "no edited copies in the way"
}

#!/usr/bin/env bats
# links: the stow layer. Each state the walk can report, what apply does with it, and that
# nothing is ever deleted.

setup() {
  load helper; load_dot
  command -v stow >/dev/null || skip "stow not installed"
  pkgfile zsh .zshrc "repo zshrc"
  pkgfile app .config/app/config "repo app"
  pkgfile app .config/app/themes/dark "dark"
  DOT_STOW=(zsh app)
}

state_of() { _link_walk "$1" | awk -F'\t' -v r="$2" '$2 == r {print $1}'; }

@test "nothing there yet: missing, then linked" {
  [[ $(state_of zsh .zshrc) == missing ]]
  run mod_links_apply
  assert_success
  [[ -L $HOME/.zshrc && $(state_of zsh .zshrc) == ok ]]
  [[ $(state_of app .config/app/config) == ok ]]
}

@test "a second apply changes nothing" {
  mod_links_apply >/dev/null
  : >"$DOT_RUN/changes"
  run mod_links_apply
  assert_success
  [[ $(changes) == 0 ]]
}

@test "a real copy with the same content is relinked (and still backed up)" {
  echo "repo zshrc" >"$HOME/.zshrc"
  [[ $(state_of zsh .zshrc) == same ]]
  mod_links_apply >/dev/null
  [[ -L $HOME/.zshrc ]]
  compgen -G "$HOME/.local/state/dot/backup/*/.zshrc" >/dev/null
}

@test "an edited copy goes to the backup with its content, then gets linked" {
  echo "edited by an installer" >"$HOME/.zshrc"
  [[ $(state_of zsh .zshrc) == differs ]]
  run mod_links_apply
  assert_output --partial "edited outside the repo"
  [[ -L $HOME/.zshrc ]]
  grep -rq "edited by an installer" "$HOME/.local/state/dot/backup/"
}

@test "dot diff shows the edited copy against the repo" {
  echo "edited" >"$HOME/.zshrc"
  run links_diff zsh
  assert_output --partial "-repo zshrc"
  assert_output --partial "+edited"
}

@test "a link into somewhere else is foreign and moved aside" {
  echo other >"$BATS_TEST_TMPDIR/other"
  ln -s "$BATS_TEST_TMPDIR/other" "$HOME/.zshrc"
  [[ $(state_of zsh .zshrc) == foreign ]]
  mod_links_apply >/dev/null
  [[ $(readlink -f "$HOME/.zshrc") == "$DOTFILES/zsh/.zshrc" ]]
  [[ $(cat "$BATS_TEST_TMPDIR/other") == other ]]
}

@test "a symlinked ~/.config is never moved" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
  ln -s "$BATS_TEST_TMPDIR/elsewhere" "$HOME/.config"
  run mod_links_apply
  assert_failure
  assert_output --partial "fix that by hand"
  [[ -L $HOME/.config ]]
}

@test "an empty home gets a real ~/.config, so packages do not fold into each other" {
  pkgfile git .config/git/config "[user]"
  DOT_STOW=(git app)
  mod_links_apply >/dev/null
  [[ -d $HOME/.config && ! -L $HOME/.config ]]
  [[ $(state_of git .config/git/config) == ok && $(state_of app .config/app/config) == ok ]]
}

@test "a dir folded by stow for one package is not an obstacle" {
  mkdir -p "$HOME/.config"
  ln -s "$DOTFILES/app/.config/app" "$HOME/.config/app"
  [[ $(state_of app .config/app/themes/dark) == ok ]]
}

@test "no-folding packages get real dirs" {
  DOT_STOW=(app) DOT_STOW_NOFOLD=(app)
  mod_links_apply >/dev/null
  [[ -d $HOME/.config/app && ! -L $HOME/.config/app && -L $HOME/.config/app/config ]]
}

@test "without stow, links are made file by file" {
  DOT_STOW=(app)
  has() { [[ $1 != stow ]] && command -v "$1" >/dev/null; }
  mod_links_apply >/dev/null
  [[ -L $HOME/.config/app/config && $(state_of app .config/app/themes/dark) == ok ]]
}

@test "status reports drift without changing anything" {
  echo "edited" >"$HOME/.zshrc"
  run mod_links_status
  assert_output --partial "differs from the repo"
  [[ ! -L $HOME/.zshrc && $(changes) == 0 ]]
}

@test "an unknown stow package is an error, not a crash" {
  DOT_STOW=(nope)
  run mod_links_apply
  assert_failure
  assert_output --partial "does not exist"
}

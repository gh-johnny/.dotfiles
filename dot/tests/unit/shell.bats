#!/usr/bin/env bats
# shell: login shell detection and the plugin checks that decide whether apply has work to do.

setup() { load helper; load_dot; }

@test "_shell_path prefers what /etc/shells lists" {
  [[ -r /etc/shells ]] || skip "no /etc/shells"
  local first
  first=$(grep -m1 '/bash$' /etc/shells) || skip "bash not in /etc/shells"
  [[ -x $first ]] || skip "listed bash not executable"
  run _shell_path bash
  assert_output "$first"
}

@test "_is_login_shell compares resolved paths" {
  _login_shell() { echo /bin/sh; }
  _is_login_shell "$(readlink -f /bin/sh)"
  ! _is_login_shell /no/such/shell
  ! _is_login_shell ""
}

@test "tmux plugins: missing until every @plugin dir exists" {
  printf "set -g @plugin 'tmux-plugins/tpm'\nset -g @plugin 'catppuccin/tmux'\n" >"$HOME/.tmux.conf"
  mkdir -p "$HOME/.tmux/plugins/tpm"
  _tmux_plugins_missing
  mkdir -p "$HOME/.tmux/plugins/tmux"
  ! _tmux_plugins_missing
}

@test "neovim plugins: lazy.nvim absent is reported as such" {
  run _nvim_plugins_missing
  assert_failure
}

@test "shell status reports a wrong login shell" {
  DOT_SHELL=bash DOT_STOW=()
  _login_shell() { echo /bin/false; }
  run mod_shell_status
  assert_output --partial "want bash"
}

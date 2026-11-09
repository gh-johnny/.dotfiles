#!/usr/bin/env bats
# tools: the generated mise config, installers, uv/npm list handling.

setup() {
  load helper; load_dot
  fake_backend fake
  DOT_GROUPS=(g)
  manifest packages.list </dev/null
}

@test "mise conf: nothing to write on glibc without fallbacks" {
  run _mise_conf
  assert_output ''
}

@test "mise conf lists the fallback tools" {
  manifest packages.list <<'L'
g neovim cmd=nvim fake=- mise=neovim
L
  run _mise_conf
  assert_output --partial '[tools]'
  assert_output --partial '"neovim" = "latest"'
}

@test "mise conf on musl points node at the musl builds" {
  OS_LIBC=musl
  run _mise_conf
  assert_output --partial 'node.flavor = "musl"'
  assert_output --partial 'unofficial-builds.nodejs.org'
  refute_output --partial '[tools]'
}

@test "installer_present: command names and ~ paths" {
  installer_present bash
  ! installer_present no-such-command-here
  mkdir -p "$HOME/.thing"
  installer_present '~/.thing'
}

@test "installer_run skips what is present and does not download" {
  manifest installers.list <<'L'
-  shell  bash  sh  https://example.invalid/install.sh
L
  fetch() { echo "fetched" >>"$BATS_TEST_TMPDIR/fetch"; }
  run installer_run shell
  assert_success
  [[ ! -e $BATS_TEST_TMPDIR/fetch ]]
}

@test "installer_run downloads, then runs with the declared shell" {
  manifest installers.list <<'L'
-  thing  no-such-thing  sh  https://example.invalid/install.sh
L
  online() { return 0; }
  fetch() { echo 'echo ran-installer'; }
  run installer_run thing
  assert_output --partial ran-installer
}

@test "installer_run gives up cleanly when the host is unreachable" {
  manifest installers.list <<'L'
-  thing  no-such-thing  sh  https://example.invalid/install.sh
L
  online() { return 1; }
  run installer_run thing
  assert_failure
  assert_output --partial unreachable
}

@test "uv tool names are read from uv tool list" {
  uv() { printf 'graphifyy v0.8\n- graphify\nheadroom-ai v0.31\n- headroom\n'; }
  run _uv_tools
  assert_line --index 0 graphifyy
  assert_line --index 1 headroom-ai
}

@test "uv skips glibc-only tools on musl and preserves other python options" {
  manifest uv.list <<'L'
g only-glibc only-glibc[proxy]==1 py=3.13 libc=glibc
g portable py=3.12
L
  OS_LIBC=musl DOT_DRY=1
  uv() { :; }
  run mod_uv_apply
  assert_success
  assert_output --partial 'uv only-glibc: needs glibc'
  assert_output --partial 'uv tool install --quiet --python 3.12 portable'
  refute_output --partial 'uv tool install --quiet --python 3.13'
  run mod_uv_status
  assert_output --partial 'uv only-glibc (needs glibc)'
}

@test "npm globals are read from parseable output" {
  _npm() { printf '/x/lib\n/x/lib/node_modules/@openai/codex\n/x/lib/node_modules/eas-cli\n'; }
  run _npm_global
  assert_output --partial '@openai/codex'
  assert_output --partial 'eas-cli'
}

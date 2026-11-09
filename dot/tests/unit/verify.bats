#!/usr/bin/env bats
# verify: records, smoke runs, config checks and the JSON report coverage.sh consumes.

setup() {
  load helper; load_dot
  V_TSV="$DOT_RUN/verify.tsv"; : >"$V_TSV"
  fake_backend fake
  DOT_GROUPS=(g) DOT_HOST=test
  OS_NAME="Test OS"
}

@test "vrec records results; skips stay quiet unless verbose" {
  vrec pass pkg git "fake"
  run vrec skip pkg zz "n/a"
  assert_output ''
  [[ $(grep -c . "$V_TSV") == 2 ]]
}

@test "verify marks a glibc-only uv tool inapplicable on musl" {
  manifest uv.list <<'L'
g only-glibc only-glibc[proxy]==1 py=3.13 libc=glibc
L
  DOT_MODULES=(uv) OS_LIBC=musl
  uv() { :; }
  verify_tools >/dev/null
  run cat "$V_TSV"
  assert_line --regexp $'^skip\tuv\tonly-glibc\tneeds glibc'
}

@test "_runs accepts the first version flag that works" {
  run _runs bash
  assert_success
  run _runs false
  assert_failure
}

@test "verify_system: installed and running passes, missing fails" {
  manifest packages.list <<'L'
g bash cmd=bash
g ghost cmd=ghost-command-xyz
L
  manifest arch.list </dev/null
  INSTALLED="bash"
  verify_system >/dev/null
  run cat "$V_TSV"
  assert_line --regexp $'^pass\tpkg\tbash'
  assert_line --regexp $'^fail\tpkg\tghost\tnot installed'
}

@test "verify_checks runs a check only for stowed packages with their program" {
  DOT_MANIFEST="$BATS_TEST_TMPDIR/m"; mkdir -p "$DOT_MANIFEST"
  cat >"$DOT_MANIFEST/checks.list" <<'L'
a  bash   passes   :: true
a  bash   fails    :: false
a  bash   errors   :: echo "E492: Not an editor command"
b  bash   not here :: true
a  nope-x missing  :: true
L
  DOT_STOW=(a)
  verify_checks >/dev/null
  run cat "$V_TSV"
  assert_line --regexp $'^pass\tconfig\ta: passes'
  assert_line --regexp $'^fail\tconfig\ta: fails'
  assert_line --regexp $'^fail\tconfig\ta: errors'
  assert_line --regexp $'^skip\tconfig\ta: missing'
  refute_output --partial 'not here'
}

@test "the report is one valid JSON object per item, quotes and backslashes escaped" {
  verify_system() { vrec pass pkg 'with "quotes"' 'a\b'; vrec fail link zsh/.zshrc differs; }
  verify_links() { :; }; verify_checks() { :; }; verify_shell() { :; }
  verify_services() { :; }; verify_tools() { :; }; verify_misc() { :; }
  DOT_TEST_DISTRO=testdistro verify_run "$BATS_TEST_TMPDIR/r.jsonl" >/dev/null || true
  [[ $(jq -s length "$BATS_TEST_TMPDIR/r.jsonl") == 2 ]]
  [[ $(jq -r 'select(.kind=="pkg") | .item' "$BATS_TEST_TMPDIR/r.jsonl") == 'with "quotes"' ]]
  [[ $(jq -r '.distro' "$BATS_TEST_TMPDIR/r.jsonl" | sort -u) == testdistro ]]
}

@test "verify_run exits 1 on a failure and reports the counts" {
  verify_system() { vrec pass pkg a; vrec fail pkg b x; vrec skip pkg c y; }
  verify_links() { :; }; verify_checks() { :; }; verify_shell() { :; }
  verify_services() { :; }; verify_tools() { :; }; verify_misc() { :; }
  run verify_run "$BATS_TEST_TMPDIR/r.jsonl"
  assert_failure
  assert_output --partial "1/2 passed, 1 failed, 1 not applicable"
  [[ $(jq -r 'select(.result=="fail") | .item' "$BATS_TEST_TMPDIR/r.jsonl") == b ]]
  [[ $(jq -r '.host' "$BATS_TEST_TMPDIR/r.jsonl" | sort -u) == test ]]
}

@test "the real checks.list is well formed" {
  local pkg prog line
  while read -r pkg prog line; do
    [[ -z $pkg || $pkg == \#* ]] && continue
    [[ $line == *" :: "* ]] || fail "no ' :: ' in check for $pkg"
    [[ -d $DOT_SRC/../$pkg ]] || fail "check for unknown stow package $pkg"
  done <"$DOT_SRC/manifest/checks.list"
}

@test "_runs returns 126 when exec is refused" {
  printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/noexec"; chmod 644 "$BATS_TEST_TMPDIR/noexec"
  run _runs "$BATS_TEST_TMPDIR/noexec"
  assert_failure 126
}

@test "an exec-refused binary in a container is not applicable, outside it a failure" {
  manifest packages.list <<'L'
g capped cmd=capped
L
  manifest arch.list </dev/null
  INSTALLED=capped
  _runs() { return 126; }
  has() { [[ $1 == capped ]] || command -v "$1" >/dev/null; }
  command() { if [[ $1 == -v && $2 == capped ]]; then echo /usr/bin/capped; else builtin command "$@"; fi; }
  OS_CONTAINER=1 verify_system >/dev/null
  OS_CONTAINER=0 verify_system >/dev/null
  run cat "$V_TSV"
  assert_line --index 0 --regexp $'^skip\tpkg\tcapped'
  assert_line --index 1 --regexp $'^fail\tpkg\tcapped\t.*permission denied'
}

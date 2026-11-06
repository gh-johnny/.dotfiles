#!/usr/bin/env bats
# core: act(), the change counter that makes "a second apply changes nothing" checkable.

setup() { load helper; load_dot; }

@test "act executes and counts a successful command" {
  run act touch "$BATS_TEST_TMPDIR/x"
  assert_success
  [[ -f $BATS_TEST_TMPDIR/x ]]
  [[ $(changes) == 1 ]]
}

@test "act does not count a failed command and passes its status on" {
  run act false
  assert_failure
  [[ $(changes) == 0 ]]
}

@test "dry-run prints and counts but does not execute" {
  DOT_DRY=1
  run act touch "$BATS_TEST_TMPDIR/y"
  assert_success
  assert_output --partial "touch"
  [[ ! -e $BATS_TEST_TMPDIR/y && $(changes) == 1 ]]
}

@test "root runs directly when already root, through sudo otherwise" {
  sudo() { echo "SUDO $*"; }
  run root echo hi
  if [[ $EUID -eq 0 ]]; then assert_output --partial "hi"; else assert_output --partial "SUDO echo hi"; fi
}

@test "confirm: yes under --yes, the default without a terminal" {
  DOT_YES=1 run confirm "ok?" n
  assert_success
  DOT_YES=0 run confirm "ok?" n </dev/null
  assert_failure
  DOT_YES=0 run confirm "ok?" y </dev/null
  assert_success
}

@test "qgrep survives pipefail where grep -q does not" {
  set -o pipefail
  seq 1 200000 | qgrep -x 1
  ! (seq 1 200000 | grep -q -x 1) || skip "this grep does not trip SIGPIPE here"
}

@test "in_list" {
  in_list b a b c
  ! in_list d a b c
  ! in_list a
}

@test "online caches its answer for the run" {
  curl() { echo called >>"$BATS_TEST_TMPDIR/calls"; return 0; }
  online example.org
  online example.org
  [[ $(grep -c called "$BATS_TEST_TMPDIR/calls") == 1 ]]
}

@test "git_clone skips an existing checkout" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/.git"
  run git_clone https://github.com/x/y "$BATS_TEST_TMPDIR/repo"
  assert_success
  [[ $(changes) == 0 ]]
}

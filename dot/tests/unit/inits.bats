#!/usr/bin/env bats
# Init adapters against stubbed systemctl and fake /etc trees.

setup() { load helper; load_dot; root() { echo "ROOT $*"; }; act() { echo "ACT $*"; }; }

@test "systemd: enabled/exists ask systemctl" {
  source "$DOT_ROOT/lib/init/systemd.sh"
  systemctl() { case "$*" in "is-enabled -q docker") return 0 ;; "cat docker") return 0 ;; *) return 1 ;; esac; }
  svc_enabled system docker
  ! svc_enabled system nope
  svc_exists system docker
}

@test "systemd: user units need a session bus" {
  source "$DOT_ROOT/lib/init/systemd.sh"
  XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR/nobus" run svc_enable user syncthing
  assert_failure
  assert_output --partial "no user session bus"
}

@test "systemd: svc_active waits through activating" {
  source "$DOT_ROOT/lib/init/systemd.sh"
  sleep() { :; }
  echo 0 >"$BATS_TEST_TMPDIR/n"
  systemctl() { local n; n=$(<"$BATS_TEST_TMPDIR/n"); echo $((n + 1)) >"$BATS_TEST_TMPDIR/n"; ((n < 3)) && echo activating || echo active; }
  svc_active system docker
  systemctl() { echo failed; }
  ! svc_active system docker
}

@test "sysvinit: Slackware's rc.d executable bit" {
  source "$DOT_ROOT/lib/init/sysvinit.sh"
  export DOT_SYSROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$DOT_SYSROOT/etc/rc.d"
  touch "$DOT_SYSROOT/etc/rc.d/rc.sshd"
  svc_exists system sshd
  ! svc_enabled system sshd
  run svc_enable system sshd
  assert_output "ROOT chmod +x $DOT_SYSROOT/etc/rc.d/rc.sshd"
  chmod +x "$DOT_SYSROOT/etc/rc.d/rc.sshd"
  svc_enabled system sshd
}

@test "sysvinit: Debian-style rcN.d links and update-rc.d" {
  source "$DOT_ROOT/lib/init/sysvinit.sh"
  export DOT_SYSROOT="$BATS_TEST_TMPDIR/root"
  mkdir -p "$DOT_SYSROOT/etc/init.d" "$DOT_SYSROOT/etc/rc2.d"
  touch "$DOT_SYSROOT/etc/init.d/ssh"
  svc_exists system ssh
  ! svc_enabled system ssh
  has() { [[ $1 == update-rc.d ]]; }
  run svc_enable system ssh
  assert_output "ROOT update-rc.d ssh defaults"
  touch "$DOT_SYSROOT/etc/rc2.d/S01ssh"
  svc_enabled system ssh
  run svc_enable user x
  assert_failure
}

@test "runit: picks the first service dir that exists" {
  source "$DOT_ROOT/lib/init/runit.sh"
  run _runsvdir
  assert_output --regexp '^/(var/service|run/runit/service|etc/runit/runsvdir/default)$'
}

@test "none: services are skipped, loudly" {
  source "$DOT_ROOT/lib/init/none.sh"
  ! svc_exists system x
  run svc_enable system x
  assert_failure
  assert_output --partial "no init system"
}

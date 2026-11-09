#!/usr/bin/env bats
# services: alternate names per backend, groups, and what each init adapter does.

setup() {
  load helper; load_dot
  DOT_GROUPS=(g)
  manifest services.list <<'L'
g  system     sshd     apt=ssh
g  system     docker
g  usergroup  docker
g  system     gone     apt=-
L
}

@test "alternate names resolve per backend, - drops the line" {
  OS_PKG=apt run _svc_lines
  assert_line --index 0 $'system\tssh'
  refute_output --partial gone
  OS_PKG=pacman run _svc_lines
  assert_line --index 0 $'system\tsshd'
  assert_output --partial $'system\tgone'
}

@test "systemd: enable without --now when systemd is not running" {
  source "$DOT_ROOT/lib/init/systemd.sh"
  OS_INIT_LIVE=0
  root() { echo "ROOT $*"; }
  run svc_enable system docker
  assert_output "ROOT systemctl enable docker"
  OS_INIT_LIVE=1
  run svc_enable system docker
  assert_output "ROOT systemctl enable --now --no-block docker"
}

@test "runit: enabling is a link into the service dir" {
  source "$DOT_ROOT/lib/init/runit.sh"
  root() { echo "ROOT $*"; }
  _runsvdir() { echo /var/service; }
  run svc_enable system sshd
  assert_line --index 1 "ROOT ln -sfn /etc/sv/sshd /var/service/sshd"
}

@test "openrc: rc-update add, user services refused" {
  source "$DOT_ROOT/lib/init/openrc.sh"
  OS_INIT_LIVE=0
  root() { echo "ROOT $*"; }
  run svc_enable system sshd
  assert_output "ROOT rc-update add sshd default"
  run svc_enable user x
  assert_failure
}

@test "services apply skips units that are not installed and enabled ones" {
  OS_PKG=pacman OS_INIT=none OS_NIXOS=0
  run mod_services_apply
  assert_success
  [[ $(changes) == 0 ]]
}

@test "services apply starts enabled but inactive systemd units" {
  manifest services.list <<'L'
g system docker
L
  OS_PKG=pacman OS_INIT=systemd OS_INIT_LIVE=1 OS_NIXOS=0
  systemctl() {
    case "$*" in
      'cat docker'|'is-enabled -q docker') return 0 ;;
      'is-active docker') echo inactive; return 3 ;;
    esac
  }
  root() { echo "ROOT $*"; }
  run mod_services_apply
  assert_success
  assert_output 'ROOT systemctl enable --now --no-block docker'
}

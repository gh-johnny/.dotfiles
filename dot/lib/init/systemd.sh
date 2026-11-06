# shellcheck shell=bash
# systemd. `enable` works without a running systemd (it only writes symlinks), so containers and
# chroots still get the right boot state; --now only when systemd is PID 1.

# svc_active SCOPE NAME: running, giving a unit that is still starting up to 30s
svc_active() {
  local flag=() i state
  [[ $1 == user ]] && flag=(--user)
  for i in $(seq 1 30); do
    state=$(systemctl "${flag[@]}" is-active "$2" 2>/dev/null)
    [[ $state == active ]] && return 0
    [[ $state == activating || $state == reloading ]] || return 1
    sleep 1
  done
  return 1
}

svc_enabled() { # SCOPE NAME
  if [[ $1 == user ]]; then systemctl --user is-enabled -q "$2" 2>/dev/null
  else systemctl is-enabled -q "$2" 2>/dev/null
  fi
}
svc_exists() {
  if [[ $1 == user ]]; then
    systemctl --user cat "$2" >/dev/null 2>&1 && return 0
    compgen -G "/usr/lib/systemd/user/$2*" >/dev/null || compgen -G "$HOME/.config/systemd/user/$2*" >/dev/null
  else
    systemctl cat "$2" >/dev/null 2>&1 && return 0
    compgen -G "/usr/lib/systemd/system/$2*" >/dev/null || compgen -G "/lib/systemd/system/$2*" >/dev/null || compgen -G "/etc/systemd/system/$2*" >/dev/null
  fi
}
svc_enable() {
  local now=()
  # --no-block: docker.service has TimeoutStartSec=0, a daemon that never comes up would hang
  # apply forever; verify is where "is it running" gets answered
  [[ $OS_INIT_LIVE == 1 ]] && now=(--now --no-block)
  if [[ $1 == user ]]; then
    if [[ -z ${XDG_RUNTIME_DIR:-} || ! -S ${XDG_RUNTIME_DIR}/bus ]]; then
      warn "no user session bus, cannot enable user unit $2 (log in graphically or via ssh and rerun)"; return 1
    fi
    act systemctl --user enable "${now[@]}" "$2"
  else
    root systemctl enable "${now[@]}" "$2"
  fi
}

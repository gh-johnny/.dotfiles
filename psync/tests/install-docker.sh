#!/usr/bin/env bash
# Real run of install.sh on a clean Ubuntu in a container (needs docker and network): the host must end
# up with Syncthing 2 from the official repository, the psync package linked and `psync --help` working,
# while tests/, vps/ and RUNBOOK.md stay out of $HOME. systemd does not run in the container, so
# linger and the user services are not covered (the installer says so and goes on).
#
#   bash psync/tests/install-docker.sh
#   IMAGE=ubuntu:24.04 bash psync/tests/install-docker.sh

set -u

IMAGE=${IMAGE:-ubuntu:26.04}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
PKG=$(cd "$HERE/.." && pwd -P)

command -v docker >/dev/null || { echo "docker is not installed: skipping"; exit 0; }

echo "install.sh on a clean $IMAGE"
# DOCKER_ARGS adds docker run options, e.g. DOCKER_ARGS="--network host" when the bridge has no IPv4 egress
# shellcheck disable=SC2086
docker run --rm ${DOCKER_ARGS:-} -v "$PKG:/home/jo/projects/dotfiles/psync:ro" "$IMAGE" bash -c '
  set -eu
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq sudo curl ca-certificates >/dev/null
  useradd -s /bin/bash jo
  echo "jo ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/jo
  chown jo:jo /home/jo /home/jo/projects /home/jo/projects/dotfiles

  echo "--- install.sh --plan"
  su - jo -c "bash ~/projects/dotfiles/psync/install.sh --plan" | head -8
  echo "--- install.sh"
  su - jo -c "bash ~/projects/dotfiles/psync/install.sh --with-backup" >/tmp/install.log 2>&1 || { cat /tmp/install.log; exit 1; }
  tail -4 /tmp/install.log

  echo "--- checks"
  fail=0
  check() { if eval "$2"; then echo "  ok    $1"; else echo "  FAIL  $1"; fail=1; fi; }
  major=$(su - jo -c "syncthing --version" | sed -n "s/^syncthing v\([0-9]*\)\..*/\1/p")
  check "Syncthing $major from the official repository (needs 2 or newer)" "[ \"${major:-0}\" -ge 2 ]"
  check "jq, curl, stow, git, restic, openssl are installed" "su - jo -c \"command -v jq curl stow git restic openssl\" >/dev/null"
  check "~/.local/bin/psync links into the package" "[ \"\$(readlink /home/jo/.local/bin/psync)\" = ../../projects/dotfiles/psync/.local/bin/psync ]"
  check "psync --help runs" "su - jo -c \"PATH=\\\$HOME/.local/bin:\\\$PATH psync --help\" | grep -q \"psync hosts\""
  check "units are linked" "[ -L /home/jo/.config/systemd/user/psync-check.timer ]"
  check "tests/, vps/, RUNBOOK.md and install.sh stay out of \$HOME" "[ ! -e /home/jo/tests ] && [ ! -e /home/jo/vps ] && [ ! -e /home/jo/RUNBOOK.md ] && [ ! -e /home/jo/install.sh ]"
  echo "--- second run is a no-op"
  su - jo -c "bash ~/projects/dotfiles/psync/install.sh --plan" | grep -c "apt-get install" | sed "s/^/apt-get install lines: /"
  exit $fail
'
rc=$?
echo
if ((rc == 0)); then echo "install-docker: passed"; else echo "install-docker: FAILED"; fi
exit $rc

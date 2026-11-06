#!/bin/sh
# Runs inside a test container (see matrix.sh): bootstrap from the mounted repo, apply twice,
# then report. POSIX sh: bash does not exist yet when this starts on Alpine.
#   in-container.sh MODE HOST     MODE = apply (as root) | user (as a sudo user) | names
mode=$1 host=$2
export USER=root
cd /

# user: the real-life case, a regular user with sudo. Make one, then rerun this script as them.
if [ "$mode" = user ]; then
  if command -v pacman >/dev/null; then pacman -Syu --needed --noconfirm sudo >/dev/null
  elif command -v apt-get >/dev/null; then apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sudo >/dev/null
  elif command -v dnf >/dev/null; then dnf install -y -q sudo shadow-utils >/dev/null
  elif command -v zypper >/dev/null; then zypper -n -q install sudo shadow >/dev/null
  elif command -v xbps-install >/dev/null; then xbps-install -Syu xbps >/dev/null 2>&1; xbps-install -Sy sudo shadow >/dev/null
  elif command -v apk >/dev/null; then apk add -q sudo shadow
  fi
  useradd -m -s /bin/sh tester 2>/dev/null || adduser -D -s /bin/sh tester
  mkdir -p /etc/sudoers.d && echo 'tester ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/tester
  exec su tester -c "sh /src/dot/tests/in-container.sh apply-as-user $host"
fi
if [ "$mode" = apply-as-user ]; then
  export USER=tester HOME=/home/tester
  cd "$HOME" || exit 1
  mode=apply
fi
D=$HOME/projects/dotfiles/dot/bin/dot
if [ "$mode" = names ]; then
  sh /src/install.sh --from /src --only self --host "$host" --yes >/tmp/boot.log 2>&1 || { cat /tmp/boot.log; exit 1; }
  exec bash "$D" names
fi

sh /src/install.sh --from /src --host "$host" --yes >/tmp/run1.log 2>&1
echo "RUN1_EXIT=$?"
bash "$D" apply --host "$host" --yes >/tmp/run2.log 2>&1
echo "RUN2_EXIT=$?"
bash "$D" status >/tmp/status.log 2>&1
echo "STATUS_EXIT=$?"
if command -v zsh >/dev/null; then
  # no TTY here: job control and p10k's gitstatus complain about that, not about the config
  POWERLEVEL9K_DISABLE_GITSTATUS=true zsh -i -c 'echo ZSH_OK' </dev/null >/tmp/zsh.out 2>/tmp/zsh.raw
  echo "ZSH_EXIT=$?"
  grep -v "can't change option: monitor" /tmp/zsh.raw >/tmp/zsh.err
fi
for f in run1 run2 status; do echo "===== $f"; cat /tmp/$f.log; done
echo "===== zsh stderr"; cat /tmp/zsh.err 2>/dev/null

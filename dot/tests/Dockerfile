# The unit-test and coverage image: bats (+ assert/support/file helpers) and kcov, from Debian.
#   docker build -t dot-test -f dot/tests/Dockerfile dot/tests
FROM debian:trixie
RUN apt-get update -qq \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      bats bats-assert bats-support bats-file kcov \
      git stow zsh tmux jq python3 ca-certificates curl diffutils bsdutils procps \
 && apt-get clean
WORKDIR /src

# shellcheck shell=bash
# apt (Debian, Ubuntu, Mint, Pop!_OS, Zorin, elementary, MX, Kali, Lubuntu...).

be_missing() {
  local p
  for p; do
    dpkg-query -W -f='${Status}\n' "$p" 2>/dev/null | qgrep 'install ok installed' || echo "$p"
  done
}
be_available() { apt-cache policy "$1" 2>/dev/null | qgrep 'Candidate: [^(]'; }
be_stale()     { ! compgen -G '/var/lib/apt/lists/*_Packages*' >/dev/null; }
be_refresh()   { root apt-get update -qq; }
be_install()   { root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq -o Dpkg::Use-Pty=0 "$@"; }
be_explicit()  { apt-mark showmanual; }

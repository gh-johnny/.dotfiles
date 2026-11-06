# shellcheck shell=bash
# nix (NixOS, or nix on another distro). Installs into the user profile with nix-env, which works
# without flakes and without root. On NixOS the system itself belongs in configuration.nix.

be_missing() {
  local p
  for p; do nix-env -q "$p" >/dev/null 2>&1 || echo "$p"; done
}
be_available() { nix-env -f '<nixpkgs>' -qaA "$1" >/dev/null 2>&1; }
be_stale()     { ! nix-instantiate --find-file nixpkgs >/dev/null 2>&1; }
be_refresh()   { act nix-channel --update; }
be_install()   { act nix-env -f '<nixpkgs>' -iA "$@"; }
be_explicit()  { nix-env -q | sed -E 's/-[0-9][^-]*$//'; }

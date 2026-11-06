# shellcheck shell=bash
# nix (NixOS, or nix on another distro). Installs into a profile of its own, never the user's or
# the system's: rebuilding someone else's profile can drop outputs it was built with (nixos/nix's
# curl loses its binary that way). bin/dot and the zshrc put its bin/ on PATH. On NixOS the
# system itself belongs in configuration.nix.

DOT_NIX_PROFILE=${XDG_STATE_HOME:-$HOME/.local/state}/dot/nix-profile

be_missing() {
  local p
  for p; do nix-env -p "$DOT_NIX_PROFILE" -q "$p" >/dev/null 2>&1 || echo "$p"; done
}
be_available() { nix-env -f '<nixpkgs>' -qaA "$1" >/dev/null 2>&1; }
be_stale()     { ! nix-instantiate --find-file nixpkgs >/dev/null 2>&1; }
be_refresh()   { act nix-channel --update; }
be_install()   { mkdir -p "${DOT_NIX_PROFILE%/*}"; act nix-env -p "$DOT_NIX_PROFILE" -f '<nixpkgs>' -iA "$@"; }
be_explicit()  { nix-env -p "$DOT_NIX_PROFILE" -q | sed -E 's/-[0-9][^-]*$//'; }

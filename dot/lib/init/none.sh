# shellcheck shell=bash
# No init system we know (minimal container): services are skipped.
svc_enabled() { return 1; }
svc_exists()  { return 1; }
svc_enable()  { warn "no init system, skipping $2"; return 1; }

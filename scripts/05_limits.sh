#!/usr/bin/env bash
# 05_limits.sh — set per-user resource limits to stop local DoS. Idempotent.
# Run as root:  sudo bash scripts/05_limits.sh
#
# The fork-bomb TEST (in GUIDE_FR.md 1.3.5) must be run ONLY inside the VM,
# after a snapshot, as a limited test user. Never on the host, never unlimited.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DST="/etc/security/limits.d/90-hardening.conf"

echo "[*] Installing resource limits to $DST…"
install -m 0644 "$REPO/config/limits-hardening.conf" "$DST"

echo "[*] Creating the testlimit group for the demo (if missing)…"
getent group testlimit >/dev/null || groupadd testlimit

echo
echo "[OK] Limits installed. They apply to NEW login sessions."
echo "    Check active limits in a session:   ulimit -a"
echo "    Demo (inside the VM, after snapshot, as a user in group testlimit):"
echo "      The classic fork bomb is blocked by the nproc cap — the machine stays up."
echo "    See GUIDE_FR.md section 1.3.5 for the exact, safe test procedure."

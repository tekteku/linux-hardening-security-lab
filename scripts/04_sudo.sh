#!/usr/bin/env bash
# 04_sudo.sh — install a least-privilege sudo rule for a "support" group. Idempotent.
# Run as root:  sudo bash scripts/04_sudo.sh
#
# A broken sudoers file can lock out sudo. We validate with visudo -c and
# only install if the check passes.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/config/sudoers-support"
DST="/etc/sudoers.d/support"
TMP="$(mktemp)"

echo "[*] Creating the support group (if missing)…"
getent group support >/dev/null || groupadd support

echo "[*] Validating the sudoers file BEFORE installing…"
cp "$SRC" "$TMP"
if visudo -cf "$TMP"; then
  echo "[OK] sudoers syntax valid."
else
  echo "[KO] sudoers syntax INVALID — not installing."
  rm -f "$TMP"; exit 1
fi

echo "[*] Installing to $DST (mode 0440)…"
install -m 0440 "$TMP" "$DST"
rm -f "$TMP"

# Final safety: validate the whole sudoers set.
visudo -c >/dev/null && echo "[OK] Full sudoers set is valid."

echo
echo "[OK] Least-privilege sudo installed for group 'support'."
echo "    Create a test user and add them:  sudo useradd -m -s /bin/bash supuser && sudo usermod -aG support supuser"
echo "    Then prove it:   sudo -l -U supuser          # shows only the allowed commands"
echo "    And prove a denial:  su - supuser -c 'sudo systemctl restart cron'   # must be REFUSED"
echo "    The denial is logged in /var/log/auth.log."

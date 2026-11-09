#!/usr/bin/env bash
# 07_aide.sh — install AIDE file-integrity monitoring and build the baseline.
# Run as root:  sudo bash scripts/07_aide.sh
# The baseline build (aideinit) takes several minutes — this is normal.

set -euo pipefail

echo "[*] Installing AIDE…"
DEBIAN_FRONTEND=noninteractive apt-get install -y aide aide-common >/dev/null

echo "[*] Building the baseline database (this takes a few minutes)…"
aideinit -y -f >/dev/null 2>&1 || aideinit

# aideinit writes the new DB as aide.db.new; promote it to the active DB.
if [[ -f /var/lib/aide/aide.db.new ]]; then
  cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
  echo "[OK] Baseline promoted to /var/lib/aide/aide.db"
fi

echo
echo "[OK] AIDE ready. To demonstrate detection (see GUIDE_FR.md 1.3.7):"
echo "    1) echo '# test change' | sudo tee -a /etc/hosts.allow"
echo "    2) sudo aide --check        # AIDE reports the changed file"
echo "    3) sudo aideinit -y -f && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db   # accept the change"
echo
echo "    Note: AIDE DETECTS changes, it does not prevent them."

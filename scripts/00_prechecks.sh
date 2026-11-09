#!/usr/bin/env bash
# 00_prechecks.sh — record the starting state of the server (read-only).
# Run as root:  sudo bash scripts/00_prechecks.sh
# Writes a snapshot of the current state into output/ (git-ignored).

set -euo pipefail

OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/output"
mkdir -p "$OUT_DIR"
REPORT="$OUT_DIR/prechecks_$(date +%Y%m%d_%H%M%S).txt"

{
  echo "===== PRE-CHECKS $(date) ====="
  echo
  echo "--- OS release ---"
  cat /etc/os-release | grep -E '^(NAME|VERSION)='
  echo
  echo "--- Kernel ---"
  uname -r
  echo
  echo "--- Human accounts (UID >= 1000) ---"
  awk -F: '$3>=1000 && $3<65534 {print $1" (uid "$3", shell "$7")"}' /etc/passwd
  echo
  echo "--- Accounts with UID 0 (should be only root) ---"
  awk -F: '$3==0 {print $1}' /etc/passwd
  echo
  echo "--- SSH effective config (key lines) ---"
  sshd -T 2>/dev/null | grep -Ei 'permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries' || echo "sshd -T unavailable"
  echo
  echo "--- Is ssh socket-activated? ---"
  systemctl is-enabled ssh.socket 2>/dev/null || echo "ssh.socket not enabled"
  echo
  echo "--- Password hashing algorithm in /etc/shadow (root line prefix) ---"
  sudo awk -F: '$1=="root"{print substr($2,1,3)}' /etc/shadow 2>/dev/null || echo "no access"
  echo
  echo "--- Installed security tools ---"
  for pkg in libpam-pwquality aide rkhunter chkrootkit clamav lynis ufw fail2ban; do
    if dpkg -s "$pkg" >/dev/null 2>&1; then echo "$pkg: INSTALLED"; else echo "$pkg: missing"; fi
  done
  echo
  echo "--- Package versions (if installed) ---"
  dpkg-query -W -f='${Package} ${Version}\n' openssh-server libpam-pwquality 2>/dev/null || true
} | tee "$REPORT"

echo
echo "[OK] Pre-check report written to: $REPORT"
echo "     (output/ is git-ignored — it never leaves your machine)"

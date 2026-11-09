#!/usr/bin/env bash
# 01_ssh_hardening.sh — secure SSH access. Idempotent.
# Run as root:  sudo bash scripts/01_ssh_hardening.sh
#
# SAFETY: keep a SECOND ssh session open while you run this. If the new
# config breaks login, the open session lets you undo it.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DROPIN="/etc/ssh/sshd_config.d/10-hardening.conf"

echo "[*] Creating the sshusers group (if missing)…"
getent group sshusers >/dev/null || groupadd sshusers

# Make sure the human who runs this keeps SSH access.
REAL_USER="${SUDO_USER:-$USER}"
if id "$REAL_USER" >/dev/null 2>&1; then
  echo "[*] Adding $REAL_USER to sshusers so you are not locked out…"
  usermod -aG sshusers "$REAL_USER"
else
  echo "[!] Could not detect your user. Add yourself manually:"
  echo "    sudo usermod -aG sshusers <your-user>"
fi

echo "[*] Installing hardened SSH drop-in to $DROPIN…"
install -m 0644 "$REPO/config/sshd_hardening.conf" "$DROPIN"

echo "[*] Testing SSH config syntax…"
if sshd -t; then
  echo "[OK] Syntax is valid."
else
  echo "[KO] Syntax error — NOT reloading. Fix the file first."
  exit 1
fi

echo "[*] Reloading SSH…"
# On Ubuntu 24.04 ssh is socket-activated; reload both to be safe.
systemctl reload ssh 2>/dev/null || true
systemctl restart ssh.socket 2>/dev/null || systemctl restart ssh

echo
echo "[OK] SSH hardened. VERIFY NOW, from your SECOND session or another host:"
echo "     ssh <user>@<server>          # should work with your key"
echo "     ssh -o PubkeyAuthentication=no <user>@<server>   # should be REFUSED"
echo
echo "Reminder: a user must be in the 'sshusers' group to log in."

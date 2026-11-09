#!/usr/bin/env bash
# 09_firewall_fail2ban.sh — BONUS: minimal firewall + brute-force protection.
# Run as root:  sudo bash scripts/09_firewall_fail2ban.sh
#
# SAFETY: we allow SSH BEFORE enabling the firewall, so you are not locked out.

set -euo pipefail

echo "[*] Installing ufw and fail2ban…"
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw fail2ban >/dev/null

echo "[*] Allowing SSH through the firewall FIRST (critical)…"
ufw allow OpenSSH >/dev/null || ufw allow 22/tcp >/dev/null

echo "[*] Default policy: deny incoming, allow outgoing…"
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

echo "[*] Enabling the firewall…"
ufw --force enable
ufw status verbose

echo "[*] Configuring fail2ban for SSH (bans an IP after repeated failures)…"
cat > /etc/fail2ban/jail.d/sshd.local <<'EOF'
[sshd]
enabled  = true
maxretry = 4
findtime = 600
bantime  = 3600
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

echo
echo "[OK] Firewall up, only SSH open. fail2ban guarding SSH."
echo "    Check bans:  sudo fail2ban-client status sshd"

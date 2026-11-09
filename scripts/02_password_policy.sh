#!/usr/bin/env bash
# 02_password_policy.sh — enforce password quality, aging and lockout. Idempotent.
# Run as root:  sudo bash scripts/02_password_policy.sh
#
# DANGER: this touches PAM. A mistake can block ALL logins.
#   1) Take a VMware snapshot first:  avant-pam-<jj-mm>
#   2) Keep a root shell open:  sudo -i   (do NOT close it)
#   3) After running, test a NEW login in another session before closing root.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[*] Installing pam_pwquality if missing…"
DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-pwquality >/dev/null

echo "[*] Installing password complexity policy…"
install -m 0644 "$REPO/config/pwquality.conf" /etc/security/pwquality.conf

echo "[*] Installing account lockout policy…"
install -m 0644 "$REPO/config/faillock.conf" /etc/security/faillock.conf

echo "[*] Setting password aging for NEW accounts in /etc/login.defs…"
set_login_def() {  # key value
  local key="$1" val="$2"
  if grep -qE "^\s*${key}\s" /etc/login.defs; then
    sed -i -E "s|^\s*${key}\s+.*|${key}\t${val}|" /etc/login.defs
  else
    printf '%s\t%s\n' "$key" "$val" >> /etc/login.defs
  fi
}
set_login_def PASS_MAX_DAYS 90
set_login_def PASS_MIN_DAYS 1
set_login_def PASS_WARN_AGE 7

echo "[*] Ensuring pam_faillock is active in /etc/pam.d/common-auth…"
# Ubuntu 24.04 ships these lines already. Add them only if absent.
if ! grep -q 'pam_faillock.so' /etc/pam.d/common-auth; then
  echo "[!] faillock lines not found — add them manually (see GUIDE_FR.md 1.3.2)."
  echo "    Do NOT guess; a wrong edit here locks everyone out."
else
  echo "[OK] pam_faillock already present."
fi

echo
echo "[OK] Password policy applied."
echo "    Test complexity now:  passwd <a-test-user>   (try a weak one — it must be refused)"
echo "    Apply aging to an existing user:  sudo chage -M 90 -m 1 -W 7 <user>"
echo "    Check a locked account:  faillock --user <user>"
echo "    Reset a locked account:  faillock --user <user> --reset"

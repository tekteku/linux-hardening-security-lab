#!/usr/bin/env bash
# 03_accounts.sh — audit and lock down accounts. Reports first, acts only with --apply.
# Audit (read-only):  sudo bash scripts/03_accounts.sh
# Apply fixes:        sudo bash scripts/03_accounts.sh --apply
#
# "Apply" sets nologin shells on system accounts that have a login shell.
# It NEVER touches your own account or root.

set -euo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
REAL_USER="${SUDO_USER:-$USER}"

echo "===== ACCOUNT AUDIT ====="

echo
echo "--- Human accounts (UID >= 1000) ---"
awk -F: '$3>=1000 && $3<65534 {print $1"  uid="$3"  shell="$7}' /etc/passwd

echo
echo "--- Extra UID 0 accounts (a second root — DANGER if any appear) ---"
extra0=$(awk -F: '$3==0 && $1!="root" {print $1}' /etc/passwd || true)
if [[ -n "$extra0" ]]; then echo "$extra0"; else echo "none (good)"; fi

echo
echo "--- Accounts with an empty password field (DANGER) ---"
empty=$(sudo awk -F: '($2==""){print $1}' /etc/shadow || true)
if [[ -n "$empty" ]]; then echo "$empty"; else echo "none (good)"; fi

echo
echo "--- System accounts (UID < 1000) that still have a login shell ---"
risky=$(awk -F: '$3<1000 && $7 ~ /(bash|sh|zsh)$/ && $1!="root" {print $1" ("$7")"}' /etc/passwd || true)
if [[ -n "$risky" ]]; then echo "$risky"; else echo "none (good)"; fi

if [[ "$APPLY" == "1" ]]; then
  echo
  echo "===== APPLYING FIXES ====="
  NOLOGIN="$(command -v nologin || echo /usr/sbin/nologin)"
  awk -F: '$3<1000 && $7 ~ /(bash|sh|zsh)$/ && $1!="root" {print $1}' /etc/passwd | while read -r u; do
    [[ "$u" == "$REAL_USER" ]] && continue
    echo "[*] Setting nologin shell on system account: $u"
    usermod -s "$NOLOGIN" "$u"
  done
  echo "[OK] System accounts locked down. Your account ($REAL_USER) and root untouched."
else
  echo
  echo "(Read-only. Re-run with --apply to set nologin shells on system accounts.)"
fi

echo
echo "Manual actions when needed:"
echo "  Lock a user:    sudo usermod -L <user>"
echo "  Expire a user:  sudo chage -E 0 <user>"
echo "  Unlock:         sudo usermod -U <user>"

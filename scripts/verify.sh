#!/usr/bin/env bash
# verify.sh — check every hardening control. Prints OK / KO per item.
# Run as root:  sudo bash scripts/verify.sh
# Exit code is non-zero if any check fails (useful for CI-style gating).

set -uo pipefail

PASS=0; FAIL=0
ok(){ echo "  [OK] $1"; PASS=$((PASS+1)); }
ko(){ echo "  [KO] $1"; FAIL=$((FAIL+1)); }

echo "===== HARDENING VERIFICATION $(date) ====="

echo
echo "--- 1.3.1 SSH ---"
eff="$(sshd -T 2>/dev/null || true)"
if grep -qi '^permitrootlogin no'        <<<"$eff"; then ok "Root login disabled";   else ko "Root login not disabled"; fi
if grep -qi '^passwordauthentication no' <<<"$eff"; then ok "Password auth disabled"; else ko "Password auth still on"; fi
if grep -qi '^maxauthtries 3'            <<<"$eff"; then ok "MaxAuthTries = 3";        else ko "MaxAuthTries not 3"; fi

echo
echo "--- 1.3.2 Password policy ---"
if [[ -f /etc/security/pwquality.conf ]] && grep -q 'minlen = 14' /etc/security/pwquality.conf; then
  ok "pwquality minlen 14"
else
  ko "pwquality missing/weak"
fi
if grep -q 'pam_faillock.so' /etc/pam.d/common-auth 2>/dev/null; then ok "faillock active"; else ko "faillock not active"; fi
if grep -qE '^\s*PASS_MAX_DAYS\s+90' /etc/login.defs; then ok "Password max age 90"; else ko "Password aging not set"; fi

echo
echo "--- 1.3.3 Accounts ---"
extra0=$(awk -F: '$3==0 && $1!="root"{print $1}' /etc/passwd)
if [[ -z "$extra0" ]]; then ok "Only root has UID 0"; else ko "Extra UID 0 account: $extra0"; fi
empty=$(awk -F: '$2==""{print $1}' /etc/shadow 2>/dev/null)
if [[ -z "$empty" ]]; then ok "No empty passwords"; else ko "Empty password: $empty"; fi

echo
echo "--- 1.3.4 sudo ---"
if [[ -f /etc/sudoers.d/support ]] && visudo -c >/dev/null 2>&1; then ok "support sudoers valid"; else ko "support sudoers missing/invalid"; fi

echo
echo "--- 1.3.5 Limits ---"
if [[ -f /etc/security/limits.d/90-hardening.conf ]]; then ok "Resource limits installed"; else ko "Resource limits missing"; fi

echo
echo "--- 1.3.7 AIDE ---"
if [[ -f /var/lib/aide/aide.db ]]; then ok "AIDE baseline present"; else ko "AIDE baseline missing"; fi

echo
echo "--- 1.3.8 Malware tools ---"
if command -v rkhunter >/dev/null; then ok "rkhunter installed"; else ko "rkhunter missing"; fi
if command -v clamscan >/dev/null; then ok "ClamAV installed";   else ko "ClamAV missing"; fi

echo
echo "===== RESULT: $PASS OK, $FAIL KO ====="
[[ "$FAIL" -eq 0 ]]

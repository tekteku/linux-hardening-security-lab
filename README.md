# Linux Server Hardening Lab

**Hardening an Ubuntu Server 24.04 LTS and proving it with a scored audit.**

This lab takes a fresh Ubuntu Server and applies standard, industry-recognised
hardening controls (SSH, PAM, sudo, resource limits, file integrity, malware
detection), then measures the result with the Lynis audit tool. The goal is a
**before/after hardening index** that can be shown as evidence of the work.

> Built and tested in an isolated VMware lab. No real credentials, hostnames,
> or personal data are included in this repository.

---

## Why this matters

A new server exposes a large **attack surface** (the set of ways an attacker
can get in). Hardening reduces that surface: close what is not needed, limit
privileges, and watch for changes. Every control below maps to a real risk.

| Control | Risk it reduces |
|---|---|
| SSH hardening | Remote brute-force and root login |
| Password policy (PAM) | Weak and guessable passwords |
| Account lockout (faillock) | Password-guessing attacks |
| sudo least-privilege | A compromised user becoming root |
| Resource limits | Local denial-of-service (e.g. fork bomb) |
| AIDE | Undetected tampering with system files |
| rkhunter / ClamAV | Rootkits and malware |

---

## Lab topology

```
          VMnet8 (NAT) ── Internet (package install only)
                │
          ┌─────┴───────┐
          │  SRV-SEC01  │  Ubuntu Server 24.04 LTS  (the hardened host)
          │ 192.168.10.30 (LAB-NET / VMnet2, host-only)
          └─────┬───────┘
                │  LAB-NET  192.168.10.0/24
          ┌─────┴───────┐
          │    KALI     │  192.168.10.66  (password-audit station)
          └─────────────┘
```

- **LAB-NET** is host-only (VMware VMnet2), `192.168.10.0/24`, VMware DHCP off.
- The host PC is `192.168.10.1` and is never scanned.

---

## Repository layout

```
linux-hardening-security-lab/
├── README.md                  # this file
├── docs/
│   └── GUIDE_FR.md            # full step-by-step guide (French)
├── scripts/                   # one idempotent script per control
│   ├── 00_prechecks.sh
│   ├── 01_ssh_hardening.sh
│   ├── 02_password_policy.sh
│   ├── 03_accounts.sh
│   ├── 04_sudo.sh
│   ├── 05_limits.sh
│   ├── 07_aide.sh
│   ├── 08_malware.sh
│   ├── 09_firewall_fail2ban.sh   # bonus
│   └── verify.sh              # checks every control, prints OK/KO
├── config/                    # the config files the scripts install
│   ├── sshd_hardening.conf
│   ├── pwquality.conf
│   ├── faillock.conf
│   ├── limits-hardening.conf
│   └── sudoers-support
├── tests/                     # pytest: validate config files on any machine
│   ├── test_configs.py
│   └── requirements.txt
├── .github/workflows/ci.yml   # ShellCheck + pytest on every push
├── .gitattributes
├── .gitignore
└── .env.example
```

## How to reproduce

1. Clone a fresh Ubuntu Server 24.04 VM, snapshot it.
2. Run `sudo bash scripts/00_prechecks.sh` to record the starting state.
3. Run each `scripts/0X_*.sh` in order (read `docs/GUIDE_FR.md` first).
4. Run `sudo bash scripts/verify.sh` — every line should read `OK`.
5. Run the Lynis audit before and after; record both scores in the table below.

## Results

| Metric | Before | After |
|---|---|---|
| Lynis hardening index | 64 / 100 | 70 / 100 |
| verify.sh checks passing | _fill in_ | _fill in_ |

_Screenshots are blurred and stored outside the repo._

## Limitations

- This lab covers host hardening only; it does not cover network segmentation,
  centralised logging (SIEM), or application-level hardening.
- AIDE, rkhunter and ClamAV **detect**; they do not **prevent**.
- Tested on Ubuntu Server 24.04 LTS; other releases may differ.

## License


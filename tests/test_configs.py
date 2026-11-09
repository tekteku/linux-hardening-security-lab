"""
Validate the hardening config files WITHOUT needing a live server.
These run in CI (GitHub Actions) and locally via WSL/pytest.

They check that the config files encode the policy we claim in the README,
so a reviewer can trust the repo even before deploying it.
"""
from pathlib import Path
import re

CONFIG = Path(__file__).resolve().parent.parent / "config"


def read(name: str) -> str:
    return (CONFIG / name).read_text(encoding="utf-8")


# ---- 1.3.1 SSH ------------------------------------------------------------
def test_ssh_disables_root_login():
    assert re.search(r"^\s*PermitRootLogin\s+no", read("sshd_hardening.conf"), re.M)


def test_ssh_disables_password_auth():
    assert re.search(r"^\s*PasswordAuthentication\s+no", read("sshd_hardening.conf"), re.M)


def test_ssh_limits_auth_tries():
    assert re.search(r"^\s*MaxAuthTries\s+3", read("sshd_hardening.conf"), re.M)


def test_ssh_restricts_group():
    assert re.search(r"^\s*AllowGroups\s+sshusers", read("sshd_hardening.conf"), re.M)


# ---- 1.3.2 Password policy ------------------------------------------------
def test_pwquality_minlen():
    assert re.search(r"^\s*minlen\s*=\s*14", read("pwquality.conf"), re.M)


def test_pwquality_requires_all_classes():
    cfg = read("pwquality.conf")
    for item in ("dcredit", "ucredit", "lcredit", "ocredit"):
        assert re.search(rf"^\s*{item}\s*=\s*-1", cfg, re.M), item


def test_faillock_denies_after_three():
    assert re.search(r"^\s*deny\s*=\s*3", read("faillock.conf"), re.M)


# ---- 1.3.4 sudo -----------------------------------------------------------
def test_sudoers_is_least_privilege():
    cfg = read("sudoers-support")
    # It must scope commands to the support group, not grant ALL=(ALL) ALL.
    assert "%support" in cfg
    assert "ALL=(ALL) ALL" not in cfg
    assert "ALL=(ALL:ALL) ALL" not in cfg


# ---- 1.3.5 Limits ---------------------------------------------------------
def test_limits_caps_nproc():
    assert re.search(r"nproc\s+\d+", read("limits-hardening.conf"))
    assert "hard" in read("limits-hardening.conf")

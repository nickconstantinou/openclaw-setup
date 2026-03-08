# Issue: Security Audit Remediation — Open DM Policies & Trust Boundaries

**Created**: 2026-03-08
**Severity**: 4 CRITICAL · 1 WARN · 1 INFO
**Source**: `openclaw security audit` console output

## Problem

The OpenClaw security audit flagged all 4 messaging channel accounts as CRITICAL:

- 3× Telegram (`default`, `coding`, `marketing`): `dmPolicy="open"`, `allowFrom=["*"]`
- 1× WhatsApp (`family`): `dmPolicy="open"`, `allowFrom=["*"]`
- 1× WARN: Multi-user setup detected — no sandbox defaults configured

Any person could DM any bot and interact with agents that have filesystem/exec access.

## 🏁 Resolution

### 🔄 Before/After

**Before** (`apply-config.py`):
```python
# All accounts hardcoded open access
tg_accounts['default'] = {
    'botToken': _tg_main,
    'dmPolicy': 'open',
    'groupPolicy': 'open',
    'allowFrom': ['*'],
}
```

**After**:
```python
# Env-driven allowlists with fallback to pairing mode
_dm_policy_default = 'allowlist' if _tg_allowed_default else 'pairing'
tg_accounts['default'] = {
    'botToken': _tg_main,
    'dmPolicy': _dm_policy_default,
    'groupPolicy': 'pairing',
    'allowFrom': _tg_allowed_default,
}
```

**New security defaults**:
```python
ds(c, 'agents.defaults.sandbox.mode', 'all')
ds(c, 'tools.fs.workspaceOnly', True)
```

### Changes Applied

| File | Change |
|------|--------|
| `config/apply-config.py` | DM allowlist parsing, sandbox defaults, numeric validation, dead code cleanup |
| `lib/01-env.sh` | Placeholder injection for 4 new allowlist env vars |
| `lib/08-config.sh` | Pass-through of allowlist env vars to apply-config |
| `.env.example` | Security section with allowlist documentation |
| `tests/test_apply_config.py` | 9-case unit test for `parse_allowed_users` |
| `CHANGELOG.md` | Security audit remediation entry |
| `AGENTS.md` | `[OPEN_DM_SURFACE]` self-learning pattern |

### Peer Review Disposition

| # | Verdict | Description |
|---|---------|-------------|
| V-1 | ✅ Accepted | Sandbox defaults added |
| V-2 | 🔴 Rejected | Family agent keeps full tools (workspace-isolated) |
| V-3 | ✅ Accepted | Dead trustedProxies code removed |
| V-4 | ✅ Accepted | Numeric validation added |
| V-5 | ✅ Accepted | Unit test created |

### 🧪 Verification Evidence

```
$ python3 -m py_compile config/apply-config.py
SYNTAX OK

$ python3 -m unittest tests/test_apply_config.py -v
test_empty_string_returns_empty_list ... ok
test_inherit_with_parent_returns_parent ... ok
test_inherit_without_parent_returns_empty ... ok
test_non_numeric_entries_skipped ... ok
test_replace_me_sentinel_returns_empty_list ... ok
test_trailing_commas_ignored ... ok
test_unset_var_returns_empty_list ... ok
test_valid_csv_returns_list ... ok
test_whitespace_stripped ... ok
Ran 9 tests in 0.000s — OK

$ bash tests/verify-repo.sh
[PASS] VERIFICATION COMPLETE.
```

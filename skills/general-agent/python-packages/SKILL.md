---
name: python-packages
description: Guide for correctly invoking Python packages inside the OpenClaw sandbox.
metadata:
  {
    "openclaw":
      {
        "emoji": "🐍",
      },
  }
---

# python-packages Skill

_Reference for invoking Python packages correctly inside the OpenClaw sandbox._

---

## The Core Problem

Packages installed via `pip install --user` land in:
- `~/.local/lib/python3.x/site-packages/`

Executables land in:
- `~/.local/bin/`

The sandbox PATH may not include `~/.local/bin`, so calling `pytest` directly fails with "command not found" even though the package is installed.

**Solution:** Always use `python3 -m <package>` — this bypasses PATH and lets Python find the module directly.

---

## 1. Verify a Package is Installed

Before using any package, confirm it's present:

```bash
python3 -c "import pytest; print(pytest.__version__)"
```

If this fails:
```
ModuleNotFoundError: No module named 'pytest'
```

Then the package is not installed and needs to be installed.

---

## 2. Running pytest Correctly

### ✅ Always Use This

```bash
python3 -m pytest <test_file_or_dir> -v
```

### ❌ Never Use This

```bash
pytest <file>  # Will fail - PATH doesn't resolve it
```

### Full Working Example

```bash
python3 -m pytest ~/.openclaw/workspace/projects/some-repo/test_main.py -v
```

---

## 3. Running Any Installed CLI Tool

General pattern for any pip-installed tool:

```bash
python3 -m <tool_name> [args]
```

### Common Tools and Their Module Names

| Tool | Invocation |
|------|------------|
| pytest | `python3 -m pytest` |
| pip | `python3 -m pip` |
| black | `python3 -m black` |
| mypy | `python3 -m mypy` |
| ruff | `python3 -m ruff` |
| requests (library) | `python3 -c "import requests"` |

---

## 4. Installing a Missing Package at Runtime

If a package is missing:

```bash
# Wait for apt lock if necessary
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 1; done
python3 -m pip install --user --break-system-packages <package>
```

**Important:** The `--break-system-packages` flag is required on Ubuntu 24.04+ (PEP 668).

After installing, verify:

```bash
python3 -c "import <package>"
```

If no error, the package is ready to use.

---

## 5. Listing What is Installed

```bash
python3 -m pip list --user
```

---

## 6. What NOT to Do

| ❌ Never Do | ✅ Instead |
|------------|-----------|
| Call `pytest` directly | `python3 -m pytest` |
| Call `pip` directly | `python3 -m pip` |
| Use `pip install` without flags | `python3 -m pip install --user --break-system-packages` |
| Assume package is present | Always verify with `python3 -c "import <package>"` |
| Use `python` (v2) | Always use `python3` |

---

## 7. Quick-Reference Cheat Sheet

```bash
# Verify package is installed
python3 -c "import pytest; print(pytest.__version__)"

# Run tests
python3 -m pytest ~/.openclaw/workspace/projects/<repo>/test_*.py -v

# Install missing package
python3 -m pip install --user --break-system-packages <package>

# List installed packages
python3 -m pip list --user

# Format code with black
python3 -m black ~/.openclaw/workspace/projects/<repo>/

# Lint with ruff
python3 -m ruff check ~/.openclaw/workspace/projects/<repo>/

# Type check with mypy
python3 -m mypy ~/.openclaw/workspace/projects/<repo>/
```

---

## Summary

1. **Always** use `python3 -m <package>` instead of calling the CLI directly
2. **Always** verify package is installed before using it
3. **Always** use `--user --break-system-packages` when installing
4. **Never** assume PATH includes `~/.local/bin`

---

_Remember: `python3 -m` is your friend — it bypasses PATH entirely._

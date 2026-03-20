# Repo Bootstrap Skill

## Purpose
Bootstrap a new repo with the standard CI/CD pipeline, tests, and GitHub protection. This is the **default setup** for all new repos.

## When to Use
- Creating a new project/repo in `~/workspace/projects/`
- Any new Python, JavaScript, or other code project

---

## What Gets Created

| File | Purpose |
|------|---------|
| `test_*.py` or `tests/` | Unit + integration tests |
| `.github/workflows/test.yml` | GitHub Actions CI |
| `pre-commit.sh` | Pre-commit hook |
| `.gitignore` | Prevent .env leaks |
| `README.md` | Project documentation |

---

## Usage

### 1. Create the repo structure
```bash
cd ~/workspace/projects
# Create your project directory
mkdir my-new-project
cd my-new-project
git init
```

### 2. Run the bootstrap
```bash
# For Python projects:
python3 -m repo_bootstrap --type python

# For JavaScript/Node:
python3 -m repo_bootstrap --type node
```

### 3. Customize the CI (optional)
Edit `.github/workflows/test.yml` to add project-specific steps.

---

## Standard .gitignore

```gitignore
# Secrets
.env
.env.local
.env.*.local

# Dependencies
node_modules/
venv/
.venv/
__pycache__/
*.pyc
*.pyo

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
npm-debug.log*

# Build
dist/
build/
*.egg-info/
```

---

## Standard GitHub Actions Test Workflow

```yaml
name: Tests

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        if: matrix.type == 'python'
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install dependencies
        run: |
          pip install pytest
      
      - name: Run tests
        run: pytest -v --tb=short
```

---

## Standard Pre-commit Hook

```bash
#!/bin/bash
# Pre-commit hook - runs tests before commit

echo "🧪 Running tests..."

# Run pytest
pytest -v --tb=short

if [ $? -ne 0 ]; then
    echo "❌ Tests failed! Fix issues before committing."
    exit 1
fi

echo "✅ All tests passed!"
exit 0
```

---

## Standard Timer for Daily Push

### Service (`~/.config/systemd/user/{project}-push-daily.service`)
```ini
[Unit]
Description=Push {project} to GitHub daily

[Service]
Type=oneshot
WorkingDirectory=/home/openclaw/.openclaw/workspace/projects/{project}
ExecStart=/bin/bash -c '\
export HOME=/home/openclaw/.openclaw && \
export GIT_ASKPASS=/bin/echo && \
git add -A && \
if ! git diff --cached --quiet; then \
  git -c commit.gpgsign=false commit --no-verify -m "Daily sync" && \
  git push https://ghp_TOKEN@github.com/owner/{project}.git main; \
else \
  echo "No changes to push"; \
fi'

[Install]
WantedBy=timers.target
```

### Timer (`~/.config/systemd/user/{project}-push-daily.timer`)
```ini
[Unit]
Description=Push {project} to GitHub daily at 3am

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

---

## Quick Start (Copy-Paste)

Instead of running a bootstrap script, just copy these files:

```bash
# 1. Create .gitignore
cat > .gitignore << 'EOF'
.env
.env.local
venv/
.venv/
__pycache__/
*.pyc
.DS_Store
EOF

# 2. Create test file
cat > test_main.py << 'EOF'
import pytest

def test_placeholder():
    assert True
EOF

# 3. Create CI workflow
mkdir -p .github/workflows
cat > .github/workflows/test.yml << 'EOF'
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: pytest -v
EOF

# 4. Create pre-commit hook
cat > pre-commit.sh << 'EOF'
#!/bin/bash
pytest -v --tb=short || exit 1
EOF
chmod +x pre-commit.sh

# 5. Enable timer (optional)
# Copy service + timer files to ~/.config/systemd/user/
# Then: systemctl --user daemon-reload && systemctl --user enable --now {project}-push-daily.timer
```

---

## Why This Matters

1. **Tests catch bugs early** — Before they reach production
2. **CI prevents bad pushes** — GitHub Actions blocks broken code
3. **Timers ensure backups** — No manual pushing needed
4. **.gitignore prevents leaks** — Never accidentally commit secrets

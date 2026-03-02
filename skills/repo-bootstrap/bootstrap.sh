#!/bin/bash
# Repo Bootstrap - Sets up standard CI/CD for a new project
# Usage: ./bootstrap.sh [python|node]
# Run from the project root directory

set -e

PROJECT_TYPE="${1:-python}"
PROJECT_NAME=$(basename "$(pwd)")

echo "🚀 Bootstrapping $PROJECT_NAME ($PROJECT_TYPE)"

# Create .gitignore
cat > .gitignore << 'EOF'
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

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Build
dist/
build/
*.egg-info/
EOF

echo "✅ Created .gitignore"

# Create test file based on project type
if [ "$PROJECT_TYPE" = "python" ]; then
    cat > test_main.py << 'EOF'
#!/usr/bin/env python3
"""Tests for project"""
import pytest

def test_placeholder():
    """Placeholder test"""
    assert True
EOF
    echo "✅ Created test_main.py"

elif [ "$PROJECT_TYPE" = "node" ]; then
    cat > test_main.test.js << 'EOF'
const assert = require('assert');

describe('Project', () => {
  it('placeholder test', () => {
    assert(true);
  });
});
EOF
    echo "✅ Created test_main.test.js"
fi

# Create GitHub Actions workflow
mkdir -p .github/workflows
cat > .github/workflows/test.yml << EOF
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
      
      - name: Set up $PROJECT_TYPE
        if: "$PROJECT_TYPE == 'python'"
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      
      - name: Install dependencies
        run: |
          if [ "$PROJECT_TYPE" = "python" ]; then
            pip install pytest
          elif [ "$PROJECT_TYPE" = "node" ]; then
            npm install
          fi
      
      - name: Run tests
        run: |
          if [ "$PROJECT_TYPE" = "python" ]; then
            pytest -v --tb=short
          elif [ "$PROJECT_TYPE" = "node" ]; then
            npm test
          fi
EOF
echo "✅ Created .github/workflows/test.yml"

# Create pre-commit hook
cat > pre-commit.sh << 'EOF'
#!/bin/bash
echo "🧪 Running tests..."

if [ -f "test_main.py" ]; then
    pytest -v --tb=short || { echo "❌ Tests failed!"; exit 1; }
elif [ -f "package.json" ]; then
    npm test || { echo "❌ Tests failed!"; exit 1; }
fi

echo "✅ Tests passed!"
exit 0
EOF
chmod +x pre-commit.sh
echo "✅ Created pre-commit.sh"

# Create README
cat > README.md << EOF
# $PROJECT_NAME

TODO: Add description

## Setup

\`\`\`bash
# Install dependencies
pip install -r requirements.txt

# Run tests
pytest -v
\`\`\`

## CI/CD

- **Tests:** Run on every push via GitHub Actions
- **Pre-commit:** Run \`./pre-commit.sh\` before committing
EOF
echo "✅ Created README.md"

echo ""
echo "🎉 Bootstrap complete!"
echo ""
echo "Next steps:"
echo "  1. git add -A && git commit -m 'Initial commit'"
echo "  2. Create repo on GitHub"
echo "  3. git remote add origin https://github.com/yourname/$PROJECT_NAME.git"
echo "  4. git push -u origin main"
echo ""
echo "To set up daily push timer:"
echo "  cp ~/.openclaw/workspace/skills/repo-bootstrap/timer-template.service ~/.config/systemd/user/"
echo "  cp ~/.openclaw/workspace/skills/repo-bootstrap/timer-template.timer ~/.config/systemd/user/"
echo "  systemctl --user daemon-reload"
echo "  systemctl --user enable --now $PROJECT_NAME-push-daily.timer"

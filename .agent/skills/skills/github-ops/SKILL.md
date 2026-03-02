---
name: github-ops
description: Comprehensive management of GitHub repository lifecycle including creation, branching, atomic commits, PRs, issue tracking, and security alerts using git and the GitHub CLI (gh).
---

# GitHub Operations Skill

This skill enforces a clean git history, automated PR workflows, and efficient GitHub CLI utilization for Exam Pulse.

## Core Workflows

### 1. Repository Initialization
- **Create Local/Remote**: `gh repo create [name] --public/--private --source=. --remote=origin`
- **Clone/Fork**: `gh repo clone [repo_name]` or `gh repo fork [repo_name]`
- **Setup**: Always include a `.gitignore` (Node/Expo template) before the initial push.

### 2. The "Feature Branch" Protocol
- **Branching**: Never commit directly to `main`. Always create a feature branch:
  `git checkout -b feat/[feature-name]`
- **Status Check**: `gh pr status` to check the health of current contributions.

### 3. Atomic Commits & Syncing
- **Conventional Commits**: Use `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.
  `git add . && git commit -m "feat: <description>"`
- **Push**: `git push origin [branch-name]`

### 4. Issue & Pull Request Management
- **Issues**:
  - `gh issue list` / `gh issue view [number]`
  - `gh issue create --title "[title]" --body "[body]" --label "[label]"`
  - `gh issue close [number]` / `gh issue comment [number] --body "[text]"`
- **Pull Requests**:
  - `gh pr create --title "feat: <title>" --body "<description of changes>"`
  - `gh pr list` / `gh pr view [number]`
  - `gh pr checks` (Ensure CI/Linting passes before merging).
  - `gh pr review [number] --approve --body "[text]"`
  - `gh pr merge --squash --delete-branch` (Keeps history clean).

### 5. Workflow & Runs (CI/CD)
- **View Runs**: `gh run list` / `gh run view [run_id] --log-failed`
- **Rerun**: `gh run rerun [run_id] --failed`
- **Workflows**: `gh workflow list`

### 6. Security & Dependabot
- **Alerts**: `gh api repos/{owner}/{repo}/dependabot/alerts?state=open`
- **Details**: `gh api repos/{owner}/{repo}/dependabot/alerts/{alert_number}`

## Advanced GH CLI Tools
- **JSON Output**: Use `--json [fields]` for structured data.
- **JQ Integration**: Use `--jq '[query]'` to filter JSON data directly.
- **API Access**: Use `gh api` for endpoints not covered by dedicated commands.

## Constraints & Safety
- **Security**: **NEVER** commit `.env` files. Verify `git status` before every commit.
- **Atomic Commits**: Keep commits small and logically grouped.
- **Conflict Management**: If a merge conflict occurs, halt and output the [CONFLICT_LOG]. Do not attempt to force-push without explicit [OK].
- **Clean History**: Always use `--squash` when merging PRs to keep `main` linear and readable.

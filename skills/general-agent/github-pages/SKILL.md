# GitHub Pages Deployment Skill

Deploy static sites to GitHub Pages. Supports two methods:

## Method 1: Legacy Branch Deploy (Recommended for Simple Sites)

**No workflow needed.** Just push to main/master and enable in settings.

**Steps:**
1. Push all files to the repo's main branch
2. Go to: `https://github.com/{owner}/{repo}/settings/pages`
3. Source: **Deploy from a branch** → Branch: **main**, Folder: **/(root)**
4. Click Save
5. Wait 1-2 mins for deployment
6. Verify: `curl -s -o /dev/null -w "%{http_code}" "https://{username}.github.io/{repo}/"`

**Check status:**
```bash
curl -s "https://api.github.com/repos/{owner}/{repo}/pages" -H "Authorization: Bearer $(gh auth token)"
```

## Method 2: GitHub Actions Workflow (For Automatic Deploys)

**Required when:** Token lacks `workflow` scope to push workflow files.

**If token has `workflow` scope:**
1. Create `.github/workflows/deploy.yml`:
```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
    environment:
      name: github-pages
      url: ${{ steps.deploy.outputs.page_url }}
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Pages
        uses: actions/configure-pages@v4

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: '.'

      - name: Deploy to GitHub Pages
        id: deploy
        uses: actions/deploy-pages@v4
```

2. Push workflow file (requires `workflow` scope on token)
3. Go to Settings → Pages → Source: **GitHub Actions**
4. Wait for workflow to run (~1-2 mins)

**If token LACKS `workflow` scope:**
- Ask user to commit the workflow file manually, OR
- Use Method 1 (Legacy Branch Deploy) instead

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 404 after enabling Pages | Wait 1-2 mins, then check build status |
| "building" status stuck | Check repo has index.html in branch root |
| Token scope error | Use Method 1 or ask user to commit manually |
| Workflow failed | Check Actions tab for error logs |

## ⚠️ SECURITY CHECK - MANDATORY BEFORE EVERY PUSH

**Before any `git push`, always run:**

```bash
# Check for secrets/credentials in staging area
git diff --cached --name-only | grep -E "node_modules|\.env|credentials|secrets" && echo "❌ BLOCKED: Potential secrets!" && exit 1

# Check .gitignore exists
[ -f .gitignore ] || echo "⚠️ WARNING: No .gitignore found"
```

**Never commit:**
- `node_modules/` - Can contain cached credentials from npm packages
- `.env` files - API keys and secrets
- Any file containing `api_key`, `secret`, `password`, `token`

## Quick Commands

```bash
# Check Pages status
curl -s "https://api.github.com/repos/{owner}/{repo}/pages" -H "Authorization: Bearer $(gh auth token)"

# Verify site is live
curl -s -o /dev/null -w "%{http_code}" "https://{username}.github.io/{repo}/"
```

## Examples

**Deploy a new static site:**
```bash
cd /path/to/site
git add -A && git commit -m "Initial commit" && git push
# Then enable Pages in settings (Method 1)
```

**Fix broken deployment:**
```bash
# Check what's in the branch
gh api repos/{owner}/{repo}/contents --method GET

# Check build status
curl -s "https://api.github.com/repos/{owner}/{repo}/pages" -H "Authorization: Bearer $(gh auth token)"
```

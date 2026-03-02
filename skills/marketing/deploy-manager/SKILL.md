---
name: deploy-manager
description: Automates deployment to Vercel/Netlify for staging reviews.
type: skill
version: 1.0.0
dependencies: [vercel-cli]
---

# Skill: Deploy Manager

## Goal
To provide an instant "Verification URL" for the `vibe-critic` and `design-qa` agents to audit. Code living on localhost is not real.

## Prerequisites
1.  **Vercel CLI:** Must be installed (`npm i -g vercel`).
2.  **Auth:** `VERCEL_TOKEN` must be present in `env`.

## Protocols

### 1. Staging Deploy (`@deploy-staging`)
- **Command:** `vercel pull --yes --environment=preview --token=$VERCEL_TOKEN && vercel build --token=$VERCEL_TOKEN && vercel deploy --prebuilt --token=$VERCEL_TOKEN`
- **Output:** Capture the `Preview URL` from stdout.
- **Verification:** Curl the URL to ensure it returns 200 OK.

### 2. Production Ship (`@deploy-prod`)
- **Command:** `vercel --prod --token=$VERCEL_TOKEN`
- **Constraint:** Only run if `vibe_score > 90`.

## Integration
- Used by `vibe_launch.md` after the Build Phase and before the Audit Phase.

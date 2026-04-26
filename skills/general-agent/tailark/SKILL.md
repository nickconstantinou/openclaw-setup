# Tailark Skill

## Purpose
Use Tailark Blocks to build high-quality marketing and landing page UI for projects in the shadcn/ui ecosystem. Drops in as owned code — no runtime dependency.

## When to Use
**Good fit:**
- Marketing surfaces: hero sections, pricing tables, feature grids, FAQ, testimonials, CTA banners, footers
- Pre-launch landing pages for SaaS products (Horizon AI, ExamPulse, etc.)
- Any project already on Next.js + shadcn/ui + Tailwind + TypeScript

**Not a fit:**
- App-specific UI (dashboards, data viz, domain-specific forms) — build those custom
- Projects not using React/Next.js
- Vue or plain HTML projects (primary focus is React)

---

## Stack Requirements
The project must have:
- `tailwindcss`
- `shadcn/ui` (initialised via `npx shadcn@latest init`)
- Next.js or React + TypeScript

---

## Step 1 — Add the Registry (once per project)

Add to `components.json`:

```json
{
  "registries": {
    "@tailark": "https://tailark.com/r/{name}.json"
  }
}
```

---

## Step 2 — Install a Block

```bash
npx shadcn@latest add @tailark/hero-section-1
npx shadcn@latest add @tailark/pricing-section-1
npx shadcn@latest add @tailark/feature-section-1
npx shadcn@latest add @tailark/faq-section-1
npx shadcn@latest add @tailark/footer-section-1
```

The component lands in your repo as editable source code. No CDN, no runtime import. Fully owned.

---

## Step 3 — Browse Available Blocks

**Free blocks:** https://github.com/tailark/blocks  
**Website (filterable):** https://tailark.com — use the "Free" or "Basic" filter

Common free block names:
- `hero-section-1`, `hero-section-2`
- `pricing-section-1`
- `feature-section-1`, `feature-section-2`
- `faq-section-1`
- `footer-section-1`
- `cta-section-1`
- `stats-section-1`
- `testimonial-section-1`

If a block name is unknown, check the GitHub repo first: `https://github.com/tailark/blocks`

---

## Prompting Patterns

```
"Add a hero section from the @tailark registry to app/page.tsx. Use hero-section-1."

"Install a pricing table from @tailark and place it below the hero in app/(marketing)/page.tsx."

"Build a landing page using @tailark blocks: hero-section-1, feature-section-1, pricing-section-1, and footer-section-1."

"Find the closest @tailark block to a 'feature grid with icons' from https://github.com/tailark/blocks and install it."
```

---

## Free vs Paid Boundary

| Namespace | Access | Notes |
|---|---|---|
| `@tailark` | Free (MIT) | Use this |
| `@tailark-pro` | Paid API key required | Do not use without key |

Stick to `@tailark`. If a block install fails with an auth error, it's a pro block — find a free alternative.

---

## Notes for Claude Code Agents
- **No MCP server needed.** The shadcn MCP is for IDEs like Cursor that lack filesystem access. Claude Code reads the repo directly — the registry in `components.json` + a direct prompt is sufficient.
- After installing a block, customise the copy, colours, and data props directly in the component file. The installed code is fully yours.
- Check that `tailwind.config.ts` includes the block's path in `content` if styles aren't applying.

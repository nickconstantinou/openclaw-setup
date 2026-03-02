---
name: offer-architect
type: skill
version: 1.0.0
dependencies: [researcher]
tags: [strategy, monetization, sales]
---

# Skill: Offer Architect

## Goal
To design the "Grand Slam Offer" that makes saying "No" feel stupid. Without an offer, we are just making noise.

## 1. Input Data
- **Source:** `research/raw_intel.json`
- **Key Question:** What is the "Bleeding Neck" problem, and how much is it costing them *not* to solve it?

## 2. The Offer Stack Protocol
Generate a `strategy/offer_stack.json` with these four components:

### A. The Mechanism (The Vehicle)
- What are they actually buying?
- **Rule:** Never sell the "Boat." Sell the "Island."
- *Bad:* "A 10-module course."
- *Good:* " The 'Anti-AI' Content System."

### B. Price Anchor ( The Contrast)
- **Logic:** Price is relative.
- *Example:* "Agency costs $5k/mo. This agent is $49/mo."

### C. Risk Reversal (The Safety Net)
- **Constraint:** If you don't believe in the product enough to guarantee it, don't sell it.
- *Types:* "30-Day Money Back," "Double Your ROI or We Pay You," "Pay After Results."

### D. The Bonuses (The Urgency Drivers)
- **Logic:** Solve the next problem they will have.
- *Example:* If selling a "Website Builder," bonus is "50 High-Converting Headlines."

## 3. Output Format
```json
{
  "mechanism": "The Vibe Marketing Agent",
  "promise": "Launch a full campaign in 10 minutes.",
  "price": "$97/mo",
  "anchor": "Hiring a CMO ($150k/yr)",
  "guarantee": "30-Day Vibe Check (Full Refund)",
  "bonuses": ["The 'Black Book' of Prompts", "10k Email Swipe File"],
  "scarcity": "Beta pricing ends in 48 hours."
}
```

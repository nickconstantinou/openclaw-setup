---
name: visual-producer
type: skill
mcp: [glif, replicate]
version: 2.0.0
---

# Skill 12: Visual Production Engine

## Objective
To generate "stop-the-scroll" assets that look like they cost $5k/shoot.

## 1. Tool Stack & Models
*   **Flux Pro (Replicate):** Best for photorealism and text rendering.
*   **Midjourney V6 (Glif):** Best for "Vibe" and artistic abstraction.
*   **Runway Gen-3 (Web):** For video motion (until API is connected).

## 2. Prompting Framework (The "Camera/Light/Material" Stack)
Do not say "A picture of a cat."
Say:
> "A macro shot of a cybernetic cat, [Camera: 85mm f/1.2 lens], [Lighting: Volumetric god rays, neon rim light], [Material: Brushed aluminum and matte fur], [Vibe: Cyberpunk, high contrast, cinematic grading] --ar 4:5"

## 3. Aspect Ratios
*   **Instagram/TikTok:** 9:16 (Vertical Video) or 4:5 (Portrait Photo).
*   **Twitter/LinkedIn:** 16:9 (Landscape) or 1:1 (Square).
*   **Web Hero:** 21:9 (Cinematic Widescreen).

## 4. Protocol for Asset Generation
1.  **Ingest Content:** Read the copy/landing page text.
2.  **Define Vibe:** Consult `creative-strategist.md`.
3.  **Generate:** Run 4 variations.
4.  **Select:** Pick the one that has the best composition (Rule of Thirds).
5.  **Output:** Save to `public/assets/[campaign_name]/[type]_[id].png`.

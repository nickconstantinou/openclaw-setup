# Editorial Personas — The Anti-Retirement Guide
*Equivalent to SD Review personas for software. Applied to all content review phases.*
*Created: 2026-03-28*

---

## Purpose

Five editorial personas review every piece of output. Each scores independently from 0.00–1.00. All five must reach ≥0.95 before a phase or section is considered complete. If any persona scores below 0.95, they issue specific, actionable fix instructions. The cycle repeats until all five pass.

This is a gate, not a suggestion box. No section ships with a failing score.

---

## The Five Personas

---

### 1. Elite Writer

**Role:** Prose quality and craft standard.

**Mandate:** Apply the Elite Writing Skill in full. Score against the six dimensions (Structure Fit, Clarity, Coherence, Precision, Redundancy, Engagement). Enforce zero AI slop, rhythm rules, concrete anchor rule, and narrative tension rule.

**Hard caps:**
- Any unresolved AI slop: max 0.90
- Any unresolved reader friction: max 0.93
- Weak engagement: max 0.94
- Generic voice or flat rhythm: max 0.94

**Scoring focus:**
- Is every sentence earning its place?
- Is the rhythm varied — no three consecutive sentences of the same length or structure?
- Every abstract claim has a concrete anchor (example, mechanism, specific detail, or named consequence)?
- Does the section feel shaped by a writer or assembled by a template?

**Output format:**
```
ELITE WRITER — [section]
Score: X.XX
Flags: [list specific lines or passages]
Fix instructions: [specific rewrites or compression notes]
```

---

### 2. Developmental Editor

**Role:** Whole-book structural integrity and argument arc.

**Mandate:** Evaluate whether each chapter and section fulfils its role in the book's overall structure. Does the reader contract established in the introduction get kept? Does the argument progress or repeat? Are chapters earning their place?

**Key questions:**
- Does this chapter advance the book's argument or duplicate a point already made?
- Is the chapter's purpose clear from the first paragraph?
- Does the ending create forward momentum or just stop?
- Does the chapter's "Your Turn" section connect specifically to the chapter's argument?
- Does the short chapter (under 1,200 words) stand alone, or should it merge with an adjacent chapter?

**Structural concerns at book level:**
- Introduction makes a specific promise: this is a book about asking a question you've been carefully not asking. Every chapter must serve that promise.
- The memoir register (first-person, honest, specific) must hold across all chapters. If a chapter drifts into generic self-help, flag it.
- Michael's story must reinforce, not repeat, the book's themes.

**Output format:**
```
DEVELOPMENTAL EDITOR — [section]
Score: X.XX
Flags: [structural issues]
Fix instructions: [structural changes needed]
```

---

### 3. Target Reader

**Role:** Simulates Nick's actual reader — a 57-year-old UK professional, probably in a couple, financially ready but emotionally stuck.

**Mandate:** Read each section as this reader. Score for emotional truth, relevance, and trust. Ask: does this feel like it was written for me? Would I feel seen, not lectured?

**Reader profile:**
- Age: 55–63
- Location: UK (knows NI contributions, LPAs, HMRC — not US equivalents)
- Financial status: has enough, roughly. Has run the numbers.
- Emotional state: scared in ways they haven't admitted to their spouse yet
- Work identity: strong. Possibly the main earner. Unsure who they are without the job.
- Reading context: probably reading alone, probably at night, possibly highlighting things they're not ready to say out loud

**Key questions:**
- Would this reader feel seen, not managed?
- Is the specific detail specific enough? (UK detail: NI, LPA, HMRC — not generic)
- Does the author maintain credibility without losing warmth?
- Would this reader trust the author more or less after reading this section?
- Does the section acknowledge both the reader who has enough *and* the reader who isn't sure yet?

**Failure modes to catch:**
- American assumptions (401k, social security, US phrasing)
- Over-optimistic framing that doesn't acknowledge real fear
- Lecturing tone (the reader is intelligent; don't explain what they already know)
- Generic testimonial energy (not specific enough to be believable)

**Output format:**
```
TARGET READER — [section]
Score: X.XX
Flags: [moments that broke trust, felt irrelevant, or missed the reader]
Fix instructions: [how to reconnect with the reader]
```

---

### 4. Copy Editor

**Role:** Mechanical precision and consistency.

**Mandate:** Audit for spelling, grammar, punctuation, house style, UK English conventions, cross-references, terminology consistency, and number formatting. This is the line-level pass — the others handle meaning, this persona handles correctness.

**House style (confirmed):**
- UK English throughout: realise/colour/organise/practise (verb)/practice (noun)
- Single quotes for embedded speech and coined terms in running prose
- Full stops outside closing quotes where not part of the quoted matter
- Em dashes unspaced (or consistently spaced — confirm with Nick; flag if inconsistent)
- Numbers: spell out one to nine; numerals for 10 and above; exception for ages and percentages (always numeral)
- Dates: day month year format (7 April 2026, not April 7)
- "Third Tuesday" — capital T, capital T, no "The" when embedded in sentence
- "I'm 54. I'm still planning." — anchor phrase, preserve verbatim
- "FIRE" vs "fire" — flag any inconsistency for author decision

**Cross-reference checks:**
- Any "as I mentioned in Chapter X" type reference must point to real content
- Michael's name: always "Michael", never "Mike"
- Appendix references must match actual appendix content

**Output format:**
```
COPY EDITOR — [section/file]
Score: X.XX
Flags: [line-by-line issues with line numbers]
Fix instructions: [correct form for each flag]
```

---

### 5. Publisher

**Role:** Commercial readiness and genre positioning.

**Mandate:** Assess the manuscript and collateral as a publisher considering whether this book is ready for market. Would it hold up against comparable UK retirement/life-stage books? Is the brand consistent end-to-end? Are there any legal, reputational, or claims-based risks?

**Key questions:**
- Does the book title and positioning hold up? Does "anti-retirement" land for UK readers?
- Is the author's credibility established early enough?
- Does the back-cover / Amazon listing promise match what the book delivers?
- Are any claims (financial, statistical, health-related) specific enough to be credible but not so prescriptive as to constitute professional advice?
- Does the collateral (website, email sequence, lead magnets) match the book's tone and promise — or is there a gap that would erode trust?
- Is the "Michael" narrative clearly framed as a composite/illustrative character if that's what it is?

**Failure modes to catch:**
- Specific financial figures that could be outdated or wrong
- Implied professional advice (financial planning, medical, legal) without appropriate caveats
- Brand inconsistency between book voice and website voice
- Promises in marketing collateral that the book doesn't fulfil

**Output format:**
```
PUBLISHER — [section/asset]
Score: X.XX
Flags: [readiness or risk issues]
Fix instructions: [changes required before this can go to market]
```

---

### 6. Fact Checker

**Role:** Independent verification of all factual claims, figures, and statistics using live research.

**Mandate:** Every specific claim that could be verified must be verified. This persona does not rely on memory or assumed accuracy — it uses the Tavily search skill, the lightpanda scraper, and gov.uk to check figures against current sources. A claim is only scored as verified when a live source confirms it. An unverified claim is not automatically wrong, but it is flagged and scored accordingly.

**Research tools available:**
- Tavily search: `curl https://api.tavily.com/search -d '{"query":"...","api_key":"$TAVILY_API_KEY"}'`
- LightPanda scraper: `python3 ~/.openclaw/workspace/skills/lightpanda/browser.py https://...`
- gov.uk directly for: State Pension age, NI rates, personal allowance, Pension Credit thresholds, Class 3 contribution costs, LPA fees
- ONS for: care cost statistics, regional rent averages

**What to verify:**
- All UK financial figures (State Pension amount, NI rates, tax thresholds, benefit thresholds)
- All statutory ages and dates (State Pension age, eligibility ages)
- All cited statistics (e.g. "a quarter of adults approaching retirement age have less than £30,000 saved")
- Any legal claims about how rules work (the 25% pension tax-free cash rule, Lump Sum Allowance)
- Historical dates and policy change dates (when the Lump Sum Allowance took effect)

**Hard caps:**
- Any HIGH-priority inaccuracy confirmed by research: max 0.70
- Any MEDIUM figure unverified (no source found or checked): max 0.88
- Any LOW figure unverified: max 0.93
- All figures verified against live sources: eligible for ≥ 0.95

**Scoring focus:**
- Is every specific figure confirmed by a current, authoritative source?
- Are the dates of policy changes accurate?
- Are statistics attributed to a real source, or stated as fact without attribution?
- Are caveats present where figures change annually?

**Output format:**
```
FACT CHECKER — [section/file]
Score: X.XX
Verified: [list of figures confirmed with source URLs]
Unverified: [list of figures not yet checked — need Nick to confirm]
Inaccurate: [list of figures found to be wrong, with correct value and source]
Fix instructions: [specific corrections required]
```

---

## Gate Protocol

### How It Works

```
FOR EACH SECTION OR FILE UNDER REVIEW:

1. All six personas read and score independently
2. Report scores and flags:
   Elite Writer:             X.XX
   Developmental Editor:     X.XX
   Target Reader:            X.XX
   Copy Editor:              X.XX
   Publisher:                X.XX
   Fact Checker:             X.XX
   GATE STATUS: PASS / FAIL

3. If any score < 0.95 → FAIL
   - Failing persona(s) issue specific fix instructions
   - Fixes applied
   - All six personas re-score
   - Repeat until all ≥ 0.95

4. PASS requires ALL SIX at ≥ 0.95
5. Record final scores in phase completion log
```

### Escalation Rules

- If a score stalls (two consecutive iterations without ≥0.02 improvement): the fixing strategy is wrong. Restructure the section, not just the phrasing.
- If Elite Writer and Developmental Editor conflict: Developmental Editor takes precedence on structural decisions; Elite Writer takes precedence on prose quality.
- If Target Reader flags something the Elite Writer doesn't: Trust the Target Reader. The reader's experience is the product.
- If Publisher flags a claims risk: halt and flag to Nick before proceeding. Do not rewrite around a risk you don't have authority to assess.
- If Fact Checker finds a confirmed inaccuracy: halt and flag to Nick immediately — do not continue reviewing the file until the figure is corrected or caveated. A verified inaccuracy in a published book is a reputational risk that overrides all other scoring.

---

## Persona Application by Phase

| Phase | Primary personas | Secondary |
|-------|-----------------|-----------|
| Phase 1 — Manuscript consistency | Developmental Editor, Copy Editor, Fact Checker | Elite Writer, Target Reader |
| Phase 2 — Website content | Elite Writer, Target Reader, Publisher, Fact Checker | Copy Editor |
| Phase 3 — Collateral | Elite Writer, Target Reader, Publisher, Copy Editor, Fact Checker | Developmental Editor |

All five score on every phase. The primary personas carry heavier weight in the iteration instructions.

---

*Version: 1.0 | Created: 2026-03-28*

---

### 7. Book Designer / Typesetter

**Role:** Print layout, typography, and production quality.

**Mandate:** Review the typeset PDF as a professional book designer preparing a manuscript for KDP print publication. Score against industry standards for UK trade nonfiction. Evaluate every aspect of the physical reading experience — not the prose, but how it sits on the page.

**Review domains:**

*Page architecture*
- Margins: are inside/outside/top/bottom margins proportional and KDP-compliant?
- Text block: is the line length comfortable (55–70 characters per line optimal for this font size)?
- Running headers/footers: are they present, correctly placed, and readable?
- Page numbers: are they suppressed correctly on cover, blank, and part-opener pages?

*Typography*
- Body type: is the font, size, and leading appropriate for the reader and genre?
- Heading hierarchy: does h1/h2/h3 create clear, readable structure without being heavy-handed?
- Drop caps or opening ornaments: are chapter openings typographically distinctive?
- Pull quotes and callouts: correctly styled and proportioned?
- Tables: font, border, and cell spacing appropriate?

*Page flow and breaks*
- Part openers: do they fill the full page? Are they visually striking?
- Chapter openings: does each chapter start on a recto (right-hand) page? Is the opening page well-balanced?
- Widows and orphans: are there lines stranded alone at top or bottom of pages?
- Short pages: are there pages with very little content that should be reflowed?

*Special elements*
- Worksheet containers: clearly differentiated from body text?
- Scene breaks (• • •): correctly spaced and rendered?
- Sidenotes / sidebar boxes: visually distinct and not breaking page flow badly?

*Cover and front matter*
- Front cover: professional, text readable, image full-bleed?
- Back cover: typographically consistent with front? All copy accurate?
- TOC: properly formatted with leaders and page numbers?
- Title page: clean and correctly formatted?

**Hard caps:**
- Any part opener failing to fill the page: max 0.82
- Any chapter opening with no typographic distinction (identical to body text): max 0.85
- Any widow/orphan found: max 0.90 per instance
- Table rendering in wrong font: max 0.88
- Running headers missing: max 0.88

**Scoring focus:**
- Would a professional UK book designer approve this for print?
- Does the layout reinforce the book's tone (upscale, thoughtful, practical)?
- Is every page intentional — no accidental whitespace, no broken elements?

**Output format:**
```
BOOK DESIGNER — [section/page range]
Score: X.XX
Critical: [production blockers — must fix before print]
Major: [significant layout degradation]
Minor: [polish items]
Fix instructions: [specific CSS/build changes with file references]
```

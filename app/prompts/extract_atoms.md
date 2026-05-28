# Prompt: Extract atoms from a chunk

You will be given a single text chunk from a financial document (earnings call transcript, news article, SEC filing, or shareholder letter). Extract **1-3 atomic claims** from it. An atom is one self-contained, evidence-backed assertion that would be useful to recall later.

## Definitions

- An **atom** is one factual claim, not a summary. Atoms must be:
  - **Specific** — names entities, numbers, time periods. "Apple beat EPS estimates by $0.12 in Q3 FY25" — yes. "Apple did well" — no.
  - **Verifiable** — supported by a direct quote in `source_quote`.
  - **Useful** — would help answer a future question about this company.
  - **Atomic** — one claim per atom. If the chunk says two things, produce two atoms.

- A **profile** is the atom's size:
  - `lightweight` (≤50 tokens) — simple facts, single assertions
  - `standard` (~100-150 tokens) — most claims, with context
  - `full` (~200-300 tokens) — complex multi-part claims

- **Topics** are short tags (1-3 words each). Include the ticker if known. Examples: `["AAPL", "vision-pro", "guidance", "Q3"]`.

- **Arousal** is 0.0-1.0 — how emotionally intense the language is. Calm earnings language ≈ 0.2. Activist letter calling for CEO removal ≈ 0.9.

- **Valence** is -1.0 to +1.0 — negative for bad news, positive for good news, 0 for neutral.

## Output format

Return ONLY valid JSON. No prose before or after.

```json
{
  "atoms": [
    {
      "content": "The full atomic claim, written in compact prose. Include entities, numbers, dates.",
      "profile": "standard",
      "topics": ["TICKER", "topic-1", "topic-2"],
      "arousal": 0.3,
      "valence": -0.4,
      "source_quote": "A verbatim, contiguous quote from the chunk that backs this claim."
    }
  ]
}
```

## Rules

1. **Never invent.** If you can't quote the source, you can't claim it.
2. **Numbers are sacred.** Preserve them exactly — "$2.5B" not "about 2 billion."
3. **Negations matter.** "Did not beat" ≠ "missed". Quote the original.
4. **Forward-looking language is a flag.** Use topic `"guidance"` or `"forward-looking"`.
5. **No commentary.** The atom states what the document says, not what you think it means.
6. **Zero atoms is acceptable.** If the chunk is boilerplate, headers, or stock disclaimers, return `{"atoms": []}`.

## Examples

### Example 1 — Earnings call

Chunk:
> [Tim Cook — CEO] In the September quarter, we set an all-time record for iPhone revenue. iPhone revenue grew 6% year-over-year, driven by strong demand for iPhone 17 Pro. We also saw inventory normalization in Vision Pro, which we view as a healthy reset before the holiday quarter.

Output:
```json
{
  "atoms": [
    {
      "content": "Apple set an all-time iPhone revenue record in fiscal Q4 2025 with 6% YoY growth, attributed by CEO Tim Cook to strong iPhone 17 Pro demand.",
      "profile": "lightweight",
      "topics": ["AAPL", "iPhone", "Q4", "revenue"],
      "arousal": 0.4, "valence": 0.7,
      "source_quote": "In the September quarter, we set an all-time record for iPhone revenue. iPhone revenue grew 6% year-over-year, driven by strong demand for iPhone 17 Pro."
    },
    {
      "content": "Apple disclosed Vision Pro inventory normalization in fiscal Q4 2025; CEO framed it as a healthy reset ahead of holiday quarter, signaling slower-than-expected demand.",
      "profile": "standard",
      "topics": ["AAPL", "vision-pro", "inventory", "guidance"],
      "arousal": 0.3, "valence": -0.3,
      "source_quote": "We also saw inventory normalization in Vision Pro, which we view as a healthy reset before the holiday quarter."
    }
  ]
}
```

### Example 2 — News article (boilerplate)

Chunk:
> This article was syndicated by Reuters. © 2026 Reuters. All rights reserved. Subscribe to our newsletter for daily market updates.

Output:
```json
{ "atoms": [] }
```

### Example 3 — SEC 8-K Item 8.01 (Other Events)

Chunk:
> On November 10, 2025, the Company entered into a definitive agreement to acquire Skyhook Wireless for $1.4 billion in cash. The transaction is expected to close in Q1 2026, subject to regulatory approval.

Output:
```json
{
  "atoms": [
    {
      "content": "The Company announced an agreement to acquire Skyhook Wireless for $1.4 billion cash, signed November 10, 2025, expected to close Q1 2026 pending regulatory approval.",
      "profile": "lightweight",
      "topics": ["acquisition", "skyhook", "cash-deal", "Q1-2026"],
      "arousal": 0.5, "valence": 0.4,
      "source_quote": "On November 10, 2025, the Company entered into a definitive agreement to acquire Skyhook Wireless for $1.4 billion in cash. The transaction is expected to close in Q1 2026, subject to regulatory approval."
    }
  ]
}
```

---

Now extract atoms from the following chunk. Return ONLY the JSON object.

CHUNK:
{{CHUNK_TEXT}}

CONTEXT (do not include in atoms; use only to disambiguate):
- Document type: {{DOC_TYPE}}
- Company: {{COMPANY_NAME}} ({{COMPANY_TICKER}})
- Document published: {{PUBLISHED_AT}}
- Document title: {{DOCUMENT_TITLE}}

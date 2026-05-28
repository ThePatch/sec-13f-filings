# Prompt: Generate a daily briefing for a user's watchlist

You are generating the user's morning briefing — a 3-5 bullet summary of what changed across their watchlist while they were away.

## Inputs

**WATCHLIST** — companies and filers the user is tracking:

{{WATCHLIST_JSON}}

**EVENTS (last 24h)** — material things that happened. Sources include 13F filings, news, earnings calls, 8-Ks. Pre-filtered for the user's watchlist.

{{EVENTS_JSON}}

**USER PROFILE** — their style preferences (if known):

{{USER_PROFILE_JSON}}

## Output format

HTML, in this exact structure:

```html
<div class="briefing">
  <p class="briefing-lede">{ONE_LINE_TLDR}</p>
  <ul class="briefing-list">
    <li class="briefing-item">{BULLET_1_WITH_CITATION}</li>
    <li class="briefing-item">{BULLET_2_WITH_CITATION}</li>
    <li class="briefing-item">{BULLET_3_WITH_CITATION}</li>
    <!-- Up to 5 bullets total -->
  </ul>
</div>
```

Each bullet must:
1. Start with the most important fact (entity, number, date).
2. Be ≤ 200 chars.
3. End with a clickable inline link to drill in: `<a href="/filers/CIK" data-action="open">Berkshire Q3 13F</a>` or `<a href="/cusips/CUSIP" data-action="open">AAPL company page</a>` or `<a data-action="open-doc" data-doc-id="123">earnings transcript</a>`.

The `briefing-lede` is one sentence summarizing the most important thing.

## Rules

1. **At most 5 bullets.** Less is better. Quality > coverage.
2. **No filler.** "Today in markets..." — don't.
3. **No emojis.**
4. **Group by company when possible.** "Berkshire filed Q1 — added BAM, trimmed CVX" is one bullet, not two.
5. **Flag what's actionable.** Earnings calls *today* matter more than 8-Ks *yesterday*.
6. **Be honest about gaps.** If nothing happened, say "Quiet day — 0 filings, 12 news articles (no material moves)."

## Examples

### Active day

```html
<div class="briefing">
  <p class="briefing-lede">Three of your watched funds filed Q1 13Fs; NVDA earnings tonight.</p>
  <ul class="briefing-list">
    <li class="briefing-item">Berkshire Hathaway filed Q1 2026 — added <b>$1.2B</b> Brookfield position, trimmed CVX 2.0%. <a href="/filers/1067983" data-action="open">Open filer →</a></li>
    <li class="briefing-item">NVDA reports tonight after the bell. 4 funds in your watchlist increased position in Q4. <a href="/cusips/67066G104" data-action="open">Open company page →</a></li>
    <li class="briefing-item">Pershing Square published Q1 letter — mentions "Brookfield" 12 times, first new thesis since 2024. <a data-action="open-doc" data-doc-id="8842">Read letter →</a></li>
  </ul>
</div>
```

### Quiet day

```html
<div class="briefing">
  <p class="briefing-lede">Quiet day across your watchlist — no filings, 8 news articles (none material).</p>
  <ul class="briefing-list">
    <li class="briefing-item">No 13F filings. No earnings.</li>
  </ul>
</div>
```

---

Now generate the briefing.

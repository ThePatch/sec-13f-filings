# Prompt: Compact an atom to a smaller profile

You will be given a single atom (a memory unit) and a target profile. Rewrite the atom's `content` so it fits the target's token budget while preserving:
- All numbers and dates
- The subject and the main claim
- The source quote (do not touch `source_quote`)

## Profile budgets

- `lightweight` — ≤50 tokens (one sentence, no commentary)
- `standard` — ~150 tokens (one paragraph)
- `full` — ~300 tokens (multiple paragraphs)

## Rules

1. **Never change `source_quote`.** That field is immutable evidence.
2. **Numbers and dates must survive verbatim.**
3. **Negations must survive verbatim.** "Did not" must remain "did not".
4. **No new claims.** Compacting must lose information, not add it.
5. **No introducer phrases.** Drop "The atom states that..." or "According to the document..."

## Output

Return ONLY JSON:

```json
{
  "content": "<rewritten content>",
  "profile": "<target profile>",
  "token_count": <integer>
}
```

---

INPUT ATOM:
{{ATOM_JSON}}

TARGET PROFILE: {{TARGET_PROFILE}}

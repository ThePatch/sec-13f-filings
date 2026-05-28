# Prompt: Extract knowledge graph triples from a chunk

You will be given a chunk of financial text and the atoms already extracted from it. Extract 2-5 **subject-predicate-object triples** that capture the structured facts.

## Rules

1. **Subjects are entities.** Company names, executives, products, fiscal periods. Use canonical names (Apple Inc., not Apple).
2. **Predicates are short, snake_case verbs.** `acquired`, `guided_eps`, `appointed_ceo`, `disclosed_material_weakness`.
3. **Objects can be entities, dates, numbers, or short phrases.** Keep them ≤ 80 chars.
4. **Confidence is 0.0-1.0.** Direct factual statements: 0.9+. Inferred from context: 0.6-0.8. Speculative: skip.
5. **Avoid duplicates.** If two atoms support the same triple, emit it once.
6. **Use ISO dates** where possible (`2025-Q3`, `2025-09-30`).
7. **Never invent.** Every triple must be supported by the chunk text.

## Output format

```json
{
  "triples": [
    {"subject": "Apple Inc.", "predicate": "set_iphone_revenue_record", "object": "2025-Q4", "confidence": 0.95},
    {"subject": "Apple Inc.", "predicate": "normalized_inventory", "object": "Vision Pro 2025-Q4", "confidence": 0.9},
    {"subject": "Tim Cook", "predicate": "role_at", "object": "Apple Inc. CEO", "confidence": 0.99}
  ]
}
```

## Predicate vocabulary (use these when applicable)

Financial events:
- `beat_eps`, `missed_eps`, `met_eps`
- `guided_eps`, `guided_revenue`, `withdrew_guidance`
- `announced_buyback`, `announced_dividend`, `cut_dividend`
- `acquired`, `divested`, `spun_off`, `merged_with`

Personnel:
- `appointed_ceo`, `appointed_cfo`, `departed`, `joined`
- `role_at` (object: "Company X CEO")

Disclosure:
- `disclosed_material_weakness`, `disclosed_investigation`, `disclosed_lawsuit`
- `received_subpoena`, `settled_lawsuit`

Strategy:
- `entered_market`, `exited_market`, `discontinued_product`, `launched_product`

Positioning (for 13F integration):
- `holds`, `added_position_in`, `reduced_position_in`, `exited_position_in`

If no predicate in this list fits, coin a new one in snake_case. Stay consistent across triples extracted from related chunks.

## Examples

### Example 1

Chunk:
> Bill Ackman of Pershing Square Capital Management announced a new $1.4 billion position in Brookfield Asset Management, marking the firm's first major initiation since Q1 2025. Ackman said the investment reflects "long-term confidence in alternative asset managers."

Output:
```json
{
  "triples": [
    {"subject": "Pershing Square Capital Management", "predicate": "initiated_position_in", "object": "Brookfield Asset Management (BAM) ~$1.4B", "confidence": 0.95},
    {"subject": "Pershing Square Capital Management", "predicate": "first_initiation_since", "object": "2025-Q1", "confidence": 0.85},
    {"subject": "Bill Ackman", "predicate": "role_at", "object": "Pershing Square Capital Management", "confidence": 0.99},
    {"subject": "Bill Ackman", "predicate": "stated_thesis_for", "object": "alternative asset managers — long-term confidence", "confidence": 0.8}
  ]
}
```

### Example 2

Chunk (boilerplate):
> This call may contain forward-looking statements. Actual results may differ materially.

Output:
```json
{ "triples": [] }
```

---

Now extract triples from the following chunk + atoms.

CHUNK:
{{CHUNK_TEXT}}

ATOMS EXTRACTED (for context):
{{ATOMS_JSON}}

CONTEXT:
- Document type: {{DOC_TYPE}}
- Company: {{COMPANY_NAME}} ({{COMPANY_TICKER}})
- Published: {{PUBLISHED_AT}}

Return ONLY the JSON object.

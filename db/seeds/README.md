# db/seeds — one-off seed tasks

Each rake task here is **idempotent** and safe to re-run. They populate
tables that v1/v2 features depend on.

## `db:seed_companies_from_mappings`

Populates the v2 `companies` table from existing rows in
`cusip_symbol_mappings`. Upserts on `cusip`. Skips mappings without a
`symbol`.

```bash
bundle exec rake db:seed_companies_from_mappings
```

Output reports inserted / updated / skipped counts and the final row total.

Run this:
- After `db:migrate` lands the v2 `companies` table on a fresh DB.
- After a fresh `mappings:sync` (`SecTickerSync` or OpenFIGI backfill)
  brings in new CUSIP↔ticker mappings.
- Before any v2 ingestion task that creates `documents` for a CUSIP —
  the FK requires a matching `companies` row.

The task is read-only against `cusip_symbol_mappings`. If you need to
*rebuild* `companies` from scratch:

```sql
TRUNCATE companies CASCADE;  -- careful: cascades to documents
```

then re-run the seed task.

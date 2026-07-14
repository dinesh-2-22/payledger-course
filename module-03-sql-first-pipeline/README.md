# Module 3 — SQL-first pipeline

> **Goal:** Hand-build the pipeline in `docs/lineage.md` with nothing but SQL and
> Snowflake Tasks: raw → staging (watermark/Δ-load) → intermediate → `fact_payment_ledger`
> + conformed dimensions. This is the pipeline you'll migrate to dbt in Modules 5–6 —
> living it once by hand is what makes that migration click.

---

## What you'll produce

| Layer | Schema.Table | Built by |
|---|---|---|
| L1 staging | `PAYLEDGER_DW.stg_transactions`, `stg_gateway_log` | `etl/stg_transactions`, `etl/stg_gateway_log` (incremental, watermark) |
| L2 intermediate | `PAYLEDGER_DW.int_transactions_enriched`, `int_settlements`, `int_fees` | `etl/int_*` (full MERGE) |
| L3 dimensions | `PAYLEDGER_DW.dim_merchant`, `dim_card`, `dim_mcc`, `dim_currency` | `ddl/04_dimension_tables.sql` (full refresh, no ETL needed) |
| L3 fact | `PAYLEDGER_DW.fact_payment_ledger` | `etl/fact_payment_ledger` (full MERGE) |
| Orchestration | 6 Snowflake Tasks | `orchestration/run_pipeline.sql` |

See `docs/lineage.md` for the full diagram and the column-level lineage of
`fact_payment_ledger` — this module's DDL matches it exactly.

---

## Prerequisites

- **Module 1 & 2 complete**: `PAYLEDGER_DW` schema exists, and the 5 raw tables in
  `PAYLEDGER_RAW` are populated (`SELECT COUNT(*) FROM PAYLEDGER_RAW.raw_transactions`
  returns ~10,000).

> **Optional — tired of copy-pasting each file into a Snowsight worksheet?**
> `optional_snowflake_git_integration.sql` sets up a native Snowflake Git
> Repository object against this GitHub repo. Once it's set up, `git push` +
> `ALTER GIT REPOSITORY ... FETCH` + `EXECUTE IMMEDIATE FROM @repo/.../file.sql`
> (or just opening the repo as a Snowsight Workspace) replaces copy-paste for
> every script in this module — and every module after it.

---

## Steps

### 1. Create the tables

Run in order (each is idempotent — `IF NOT EXISTS` / `CREATE OR REPLACE`):

```
ddl/01_watermark_control.sql
ddl/02_staging_tables.sql
ddl/03_intermediate_tables.sql
ddl/04_dimension_tables.sql   -- also loads the dims (CTAS, full refresh)
ddl/05_fact_table.sql
```

### 2. Load staging (the watermark/Δ-load pattern)

Run `etl/stg_transactions/load_stg_transactions.sql` and
`etl/stg_gateway_log/load_stg_gateway_log.sql`. Each defines a stored procedure that:

1. Reads the last watermark from `etl_watermark`
2. `MERGE`s only rows with `_loaded_at` past that watermark into staging
3. Advances the watermark to `MAX(_loaded_at)` on the raw table

Run either script a **second time** with no new raw data — it should report
`merged 0 row(s)`. That's the point: a correct Δ-load is idempotent and cheap to
re-run, unlike a full-table reload.

### 3. Load intermediate + fact

Run in order:

```
etl/int_transactions_enriched/load_int_transactions_enriched.sql
etl/int_settlements/load_int_settlements.sql
etl/int_fees/load_int_fees.sql
etl/fact_payment_ledger/load_fact_payment_ledger.sql
```

These are full `MERGE`s over all of staging each run — at this data volume (10K
transactions) that's cheap, and it keeps the SQL simple. (dbt's `is_incremental()`
in Module 6 is where you'd revisit that trade-off at scale.)

### 4. Orchestrate it

Run `orchestration/run_pipeline.sql` to wire all six procedures into a Snowflake Task
DAG (two roots on a nightly `CRON`, fanning out to intermediate, fanning back in to the
fact table). It includes commented-out `EXECUTE TASK` calls to test the DAG on demand
instead of waiting for the schedule, plus a `TASK_HISTORY()` query to watch runs.

> **Cost note:** these tasks fire nightly whether or not `generate_data.py` produced new
> data. Suspend the tree (commands at the bottom of the script) once you're done
> exploring this module, so a trial account doesn't spend credits on empty runs.

---

## ✅ Checkpoint

- [ ] `stg_transactions` / `stg_gateway_log` row counts match the raw tables.
- [ ] Re-running a staging load script reports `merged 0 row(s)`.
- [ ] `dim_merchant` (~60), `dim_card` (~800), `dim_mcc`, `dim_currency` are populated.
- [ ] `SELECT COUNT(*) FROM fact_payment_ledger;` returns a row count ≤ 10,000 (only
      settled transactions have a fact row).
- [ ] The validation query at the bottom of `load_fact_payment_ledger.sql` shows a
      non-null `total_net_amount` and `disputed_rows` > 0.
- [ ] `orchestration/run_pipeline.sql` ran without error and `TASK_HISTORY()` shows
      `SUCCEEDED` for a manual `EXECUTE TASK` test.

---

## Where this goes next

**Module 4** wraps this hand-rolled DDL in CI/CD (`schemachange` + GitHub Actions) so
schema changes are versioned and deployed automatically instead of run by hand.
**Module 5–6** rebuild this exact pipeline in dbt and assert it produces identical rows.

See **`claude-code.md`** for two ways Claude Code accelerates this module.

# Module 2 — Mock data generation, raw landing & the dispute corpus

> **Goal:** Generate a small, realistic, *reproducible* set of payment files and land
> them in Snowflake's `PAYLEDGER_RAW` schema. Everything you build in Modules 3–10
> reads from these tables, so this module is the foundation.

---

## What you'll produce

| File | Rows (default) | Becomes table | Used by |
|---|---|---|---|
| `raw_merchant_master.csv` | ~60 | `raw_merchant_master` | dim_merchant |
| `raw_card_master.csv` | ~800 | `raw_card_master` | dim_card |
| `raw_transactions.csv` | **10,000** | `raw_transactions` | the whole pipeline |
| `raw_gateway_log.csv` | ~10,000 | `raw_gateway_log` | settlements & fees |
| `dispute_memos.csv` | ~200 | `dispute_memos` | **Cortex Search (Module 10)** |

The dispute memos are free text on purpose. We generate them *now*, alongside the
structured data, so that when Cortex Search shows up in Module 10 it has a real,
internally-consistent corpus to index — not a contrived afterthought.

### How the data hangs together

```
raw_card_master ─┐
                 ├─< raw_transactions >─┬─< raw_gateway_log
raw_merchant_master ┘                   └─< dispute_memos
```

Every transaction points at a real card + merchant. Every gateway event and
dispute points at a real transaction. This referential integrity is what makes
the joins in Module 3 (and the dbt tests in Module 5) meaningful.

---

## Prerequisites

- **Module 1 complete**: you have `PAYLEDGER` database, `PAYLEDGER_RAW` schema,
  `PAYLEDGER_WH` warehouse, and the `PAYLEDGER_DEV` role.
- Python 3.9+ locally.
- One of: **SnowSQL**, the **VS Code Snowflake extension**, or **Snowsight** (for the upload step).

---

## Steps

### 1. Install dependencies & generate data

```bash
cd module-02-mock-data-and-corpus
python -m venv .venv && source .venv/bin/activate   # optional but recommended
pip install -r requirements.txt
python generate_data.py
```

You should see output ending with a `MAX(_loaded_at)` line — **note that timestamp**,
it's the watermark you'll anchor the delta-load on in Module 3.

Useful flags:
```bash
python generate_data.py --rows 50000   # scale up the transaction count
python generate_data.py --seed 7       # different (but still reproducible) data
```

> **Why deterministic?** A fixed seed means your data matches everyone else's. In
> Module 6 we assert the dbt-built fact table matches the SQL-built one *row for row* —
> that only works if the inputs are identical.

### 2. Inspect what you generated

Open `data/raw_transactions.csv` and skim it. Sanity questions to ask yourself
(and good prompts for Claude Code — see `claude-code.md`):
- Do `currency_code` values look consistent with the merchant's country?
- Are `_loaded_at` values batched (clustered around 02:00–03:00)? Why does that matter?

### 3. Land the data in Snowflake

Open `stage_and_copy.sql` and run it top to bottom.

- **SnowSQL / VS Code:** uncomment the `PUT` statements (step 2 of the script) to
  upload your local CSVs to the internal stage, then run the `COPY INTO`s.
- **Snowsight:** the `PUT` commands won't run in a worksheet, and the stage's own object
  page doesn't expose an upload button in every Snowsight version. The reliable path:
  left nav → **Ingestion → Add Data** → **Load files into a Stage** → **Snowflake Stage**,
  pick `PAYLEDGER.PAYLEDGER_RAW.PAYLEDGER_RAW_STAGE` as the destination, and upload each of
  the 5 CSVs. Confirm with `LIST @PAYLEDGER_RAW_STAGE;` (should return 5 rows), then run the
  `COPY INTO` statements (drop the `.gz` suffix — files uploaded this way aren't compressed).

---

## ✅ Checkpoint

You're ready for Module 3 when:

- [ ] `SELECT COUNT(*) FROM raw_transactions;` returns ~10,000.
- [ ] All five raw tables are populated (run the validation query at the bottom of `stage_and_copy.sql`).
- [ ] `SELECT MAX(_loaded_at) FROM raw_transactions;` returns a timestamp — you know what the watermark is.
- [ ] `SELECT memo_text FROM dispute_memos LIMIT 5;` shows varied, readable dispute narratives.

---

## Where this goes next

**Module 3** reads `raw_transactions` + `raw_gateway_log` incrementally using the
`MAX(_loaded_at)` watermark, builds staging → intermediate → `fact_payment_ledger`.

See **`claude-code.md`** for two ways Claude Code accelerates this module.

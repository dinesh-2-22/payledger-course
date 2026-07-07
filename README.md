# PayLedger: From Raw SQL to AI-Native Analytics

> Build, modernize, and AI-augment a payments data pipeline — one repo, eleven modules.

This is a hands-on data engineering course. You'll build a payments-ledger data
pipeline three times — and that's the point. First the **SQL-first** way (hand-rolled
Snowflake ETL), then migrate it to **dbt**, then put an **AI layer** (Snowflake Cortex)
on top. Walking the same pipeline through all three eras is what makes you *feel* why
dbt exists and why AI-native analytics is interesting on a clean lakehouse.

**Claude Code is threaded throughout** — every module has a `claude-code.md` showing
how to use it as a draft-and-critique partner for that specific task.

---

## Who this is for

Engineers and analysts with **intermediate SQL** who want to learn the modern data
stack end-to-end. No prior Snowflake or dbt experience required. You'll need a free
**Snowflake trial account** and Python 3.9+.

## The running example: PayLedger

A fictional card-issuing fintech. The pipeline turns raw card transactions into a
clean `fact_payment_ledger` plus conformed dimensions, then exposes it to natural-language
analytics.

```
RAW (PAYLEDGER_RAW)            STAGING            INTERMEDIATE              FACT
raw_transactions    ─┐                                                ┌─ fact_payment_ledger
raw_gateway_log     ─┤─► stg_transactions ─► int_transactions_enriched┤
raw_merchant_master ─┤   stg_gateway_log      int_settlements         │   DIMS
raw_card_master     ─┘                        int_fees                └─ dim_merchant
dispute_memos ········(free text)······························► Cortex Search   dim_card
                                                                            dim_mcc
                                                                            dim_currency
```

---

## Module index

| # | Module | You'll learn | Status |
|---|--------|--------------|--------|
| 0 | [Orientation & Snowflake setup](module-00-setup/) | Trial account, roles/warehouses/db bootstrap | ⬜ planned |
| 1 | [Snowflake foundations](module-01-snowflake-foundations/) | Warehouses, schemas, stages, time travel, cost | ⬜ planned |
| 2 | [**Mock data, raw landing & dispute corpus**](module-02-mock-data-and-corpus/) | Faker generator, stages, `COPY INTO` | ✅ **built** |
| 3 | [SQL-first pipeline](module-03-sql-first-pipeline/) | Watermark/delta-load, MERGE, staging→fact | ⬜ planned |
| 4 | [CI/CD for SQL pipelines](module-04-sql-cicd/) | GitHub Actions + schemachange, environments | ⬜ planned |
| 5 | [dbt migration — day 1](module-05-dbt-day1/) | sources, staging models, tests, data quality | ⬜ planned |
| 6 | [dbt migration — day 2](module-06-dbt-day2/) | intermediate, marts, `ref()`, docs/lineage | ⬜ planned |
| 7 | [dbt slim CI](module-07-dbt-slim-ci/) | `state:modified+`, deferred refs, PR builds | ⬜ planned |
| 8 | [Cortex Analyst](module-08-cortex-analyst/) | semantic YAML, natural-language → SQL | ⬜ planned |
| 9 | [Snowflake Intelligence agent](module-09-intelligence-agent/) | Cortex Search + agent over Analyst + Search | ⬜ planned |
| 10 | [Capstone: ship `fact_chargebacks`](module-10-capstone/) | integrate every skill end-to-end | ⬜ planned |

> `solutions/` (a branch, eventually) holds reference implementations you can diff against.

---

## How to use this repo

Work the modules **in order** — each builds on the tables/artifacts from the previous one.
Every module folder contains:

- **`README.md`** — the lesson narrative and step-by-step instructions
- **runnable artifacts** — `.sql`, `.py`, `.yaml`, or workflow files you execute
- **`claude-code.md`** — two concrete ways Claude Code accelerates that module
- a **checkpoint** — what must be working before you move on

## Quickstart (Module 2 is ready now)

```bash
# 1. Set up Snowflake objects (Module 1 — coming soon)
# 2. Generate and inspect the mock data:
cd module-02-mock-data-and-corpus
pip install -r requirements.txt
python generate_data.py
# 3. Load it: run stage_and_copy.sql in SnowSQL / Snowsight
```

---

## Conventions

- **Database:** `PAYLEDGER` · **Schemas:** `PAYLEDGER_RAW` (landing), `PAYLEDGER_DW` (modeled)
- **Warehouse:** `PAYLEDGER_WH` (XS) · **Role:** `PAYLEDGER_DEV`
- Reproducible by design: the data generator is seeded, so everyone's pipeline produces
  identical results — which is what lets Module 6 assert dbt output matches the SQL build
  row-for-row.

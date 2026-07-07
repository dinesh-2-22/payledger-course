# Module 8 — Cortex AISQL: native AI functions in plain SQL

> **Goal:** Run large-language-model operations — sentiment, classification, filtering,
> generation, summarization, embeddings — **directly in a SQL statement**, with no Python,
> no external API, and no data leaving Snowflake. Then do the thing most tutorials skip:
> **measure** how good the AI actually is, because our data has ground-truth labels.

This is the "row-level AI" layer. It comes *before* Cortex Analyst (M9) and the
Intelligence agent (M10) because those higher-level services are built on exactly these
primitives — once you've called `AI_COMPLETE` and `AI_EMBED` yourself, Analyst and Search
stop feeling like magic.

---

## Why this matters

The `dispute_memos` table you generated in Module 2 is **free text** with a **known
category label** (`dispute_category`). That combination is gold for learning AISQL:

- The free text is realistic input for every AI function.
- The label lets you **score** `AI_CLASSIFY` — you'll compute an accuracy %, inspect a
  confusion matrix, and see *why* the model's "mistakes" are often defensible.

You'll finish this module able to answer: *when should I reach for a native AI function
instead of writing rules or moving data to a Python service?*

---

## Prerequisites

- **Module 2 loaded** — the `dispute_memos` and `raw_merchant_master` tables exist.
  (This module only needs Module-2 data, so you can run it any time after Module 2.)
- **Cortex access granted** to your role:
  ```sql
  USE ROLE ACCOUNTADMIN;
  GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PAYLEDGER_DEV;
  ```
- A running warehouse (`PAYLEDGER_WH`). Cortex functions run on your warehouse compute
  plus per-token AI credits — see the cost note below.

---

## The AISQL function families

| Family | Functions you'll use | Lab |
|---|---|---|
| **Enrich** (row-level) | `AI_SENTIMENT`, `SNOWFLAKE.CORTEX.SUMMARIZE`, `AI_TRANSLATE`, `EXTRACT_ANSWER`, `AI_COUNT_TOKENS` | `01_text_enrichment.sql` |
| **Classify & filter** | `AI_CLASSIFY`, `AI_FILTER` (+ `PROMPT()`) | `02_classify_and_filter.sql` |
| **Generate** | `AI_COMPLETE` (+ `model_parameters`, structured `response_format`) | `03_generate_responses.sql` |
| **Aggregate** (across rows) | `AI_AGG`, `AI_SUMMARIZE_AGG` | `04_aggregate_insights.sql` |
| **Embed & compare** | `AI_SIMILARITY`, `AI_EMBED`, `VECTOR_COSINE_SIMILARITY` | `05_embeddings_similarity.sql` |

> **Modern vs classic naming.** Snowflake's newer **AISQL** functions use the `AI_` prefix
> (`AI_COMPLETE`, `AI_CLASSIFY`, `AI_SENTIMENT`, `AI_TRANSLATE`, …). The older
> `SNOWFLAKE.CORTEX.*` functions (`COMPLETE`, `SENTIMENT`, `SUMMARIZE`, `CLASSIFY_TEXT`,
> `EMBED_TEXT_1024`, …) still work and are handy where a newer alias doesn't exist yet
> (e.g. `SUMMARIZE`, `EXTRACT_ANSWER`). The labs lead with `AI_` functions and use the
> classic namespace only where it's the documented path.

---

## The labs (run in order)

1. **`01_text_enrichment.sql`** — score sentiment, summarize, translate, and extract a
   specific fact ("what is the disputed amount?") from each memo.
2. **`02_classify_and_filter.sql`** ⭐ — classify memos into our dispute taxonomy, then
   **score it against `dispute_category`**: accuracy %, confusion matrix, and an
   `AI_FILTER` natural-language WHERE clause.
3. **`03_generate_responses.sql`** — draft customer replies with `AI_COMPLETE`, control
   output with `model_parameters`, and turn free text into **typed columns** using a
   structured `response_format`.
4. **`04_aggregate_insights.sql`** — `AI_AGG` / `AI_SUMMARIZE_AGG` collapse *many* memos
   into one insight per merchant/category — one model call per group, not per row.
5. **`05_embeddings_similarity.sql`** — semantic search with `AI_SIMILARITY`, then the
   `AI_EMBED` + `VECTOR_COSINE_SIMILARITY` mechanics underneath. This is the bridge to
   Cortex Search (M10).

---

## ⚠️ Cost & safety

- **Every row is a model call.** `SELECT AI_COMPLETE(...) FROM dispute_memos` with no
  `LIMIT` calls the LLM 200 times. While iterating, always gate with `LIMIT` or
  `TABLESAMPLE`.
- **Pick the right model.** Smaller/faster models (e.g. `llama3.3-70b`) are cheaper than
  large frontier models; match the model to task difficulty. Model availability varies by
  region — see the docs for your region's list.
- **Estimate first.** `AI_COUNT_TOKENS` tells you the token volume before you commit.
- **Use `TRY_` variants and `temperature => 0`** for production determinism and graceful
  failure at scale.

---

## ✅ Checkpoint

You're done when you can:

- [ ] Return an `overall_sentiment` for every dispute memo (Lab 1).
- [ ] Produce an **accuracy %** and a **confusion matrix** for `AI_CLASSIFY` vs
      `dispute_category`, and explain one class of errors (Lab 2).
- [ ] Emit a structured triage object (`severity`, `refund_recommended`,
      `recommended_action`) as typed columns (Lab 3).
- [ ] Generate one `AI_AGG` insight per merchant (Lab 4).
- [ ] Rank memos by semantic similarity to a free-text query (Lab 5).

## Where this goes next

- **Module 9 — Cortex Analyst:** instead of you writing SQL, an LLM writes it against a
  semantic model over `fact_payment_ledger` + dims.
- **Module 10 — Cortex Search + Intelligence agent:** the managed, indexed version of the
  hand-rolled semantic search you built in Lab 5, wired into an agent alongside Analyst.

See **`claude-code.md`** for two ways Claude Code helps you write and *evaluate* AISQL.

/* ============================================================================
   Module 8 · Lab 5 — Semantic similarity & embeddings (bridge to Cortex Search)
   ----------------------------------------------------------------------------
   Search by MEANING, not keywords. First the easy way (AI_SIMILARITY), then
   the mechanics underneath (AI_EMBED + VECTOR_COSINE_SIMILARITY).
   ========================================================================== */
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_RAW;

-- ---------------------------------------------------------------------------
-- 5a. Semantic search without keywords.
--     AI_SIMILARITY(a, b) -> float in [-1, 1]; higher = closer in meaning.
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    dispute_category,
    ROUND(AI_SIMILARITY(memo_text,
          'the customer never received the item they ordered'), 3) AS sim,
    memo_text
FROM dispute_memos
ORDER BY sim DESC
LIMIT 10;
-- Notice the top hits are GOODS_NOT_RECEIVED even when they never use those exact words.

-- ---------------------------------------------------------------------------
-- 5b. What AI_SIMILARITY does under the hood: embed each text, then cosine.
--     AI_EMBED(model, text) -> a VECTOR.
-- ---------------------------------------------------------------------------
WITH q AS (
    SELECT AI_EMBED('snowflake-arctic-embed-l-v2.0',
                    'refund was promised but never arrived') AS qvec
)
SELECT
    d.dispute_id,
    d.dispute_category,
    ROUND(VECTOR_COSINE_SIMILARITY(
        AI_EMBED('snowflake-arctic-embed-l-v2.0', d.memo_text),
        q.qvec), 3) AS cosine_sim,
    d.memo_text
FROM dispute_memos d, q
ORDER BY cosine_sim DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- 5c. Materialize embeddings once, then reuse (don't re-embed every query).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE dispute_memo_vectors AS
SELECT
    dispute_id,
    dispute_category,
    memo_text,
    AI_EMBED('snowflake-arctic-embed-l-v2.0', memo_text) AS memo_vec
FROM dispute_memos;

-- Find near-duplicate disputes (same complaint, different wording).
SELECT
    a.dispute_id AS dispute_a,
    b.dispute_id AS dispute_b,
    ROUND(VECTOR_COSINE_SIMILARITY(a.memo_vec, b.memo_vec), 3) AS sim
FROM dispute_memo_vectors a
JOIN dispute_memo_vectors b
  ON a.dispute_id < b.dispute_id                 -- each pair once, no self-match
WHERE VECTOR_COSINE_SIMILARITY(a.memo_vec, b.memo_vec) > 0.9
ORDER BY sim DESC
LIMIT 20;

-- ---------------------------------------------------------------------------
-- BRIDGE → Module 10: you just hand-built semantic search. Cortex Search
-- automates all of it -- managed embeddings, a maintained index, incremental
-- refresh, and hybrid keyword+vector retrieval -- so you never babysit a
-- vector table. Same idea, production-grade.
-- ---------------------------------------------------------------------------

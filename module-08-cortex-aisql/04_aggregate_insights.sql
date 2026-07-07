/* ============================================================================
   Module 8 · Lab 4 — Aggregate insights across rows (AI_AGG / AI_SUMMARIZE_AGG)
   ----------------------------------------------------------------------------
   AI_AGG collapses MANY rows into ONE answer per group -- one model call per
   group, not per row. Perfect for "summarize all disputes for each merchant".
   ========================================================================== */
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_RAW;

-- ---------------------------------------------------------------------------
-- 4a. One insight per merchant. AI_AGG(expr, instruction) -> STRING.
--     Use a declarative instruction (not a question) and name the use case.
-- ---------------------------------------------------------------------------
SELECT
    m.merchant_name,
    COUNT(*) AS dispute_count,
    AI_AGG(
        d.memo_text,
        'Summarize the recurring dispute themes for this merchant in two sentences '
        || 'and name the single most common problem.'
    ) AS merchant_dispute_insight
FROM dispute_memos d
JOIN raw_merchant_master m USING (merchant_id)
GROUP BY m.merchant_name
HAVING COUNT(*) >= 3                 -- only merchants with enough memos to summarize
ORDER BY dispute_count DESC
LIMIT 10;

-- ---------------------------------------------------------------------------
-- 4b. AI_SUMMARIZE_AGG -- same reduce-across-rows idea, no instruction needed.
--     One summary per dispute category.
-- ---------------------------------------------------------------------------
SELECT
    dispute_category,
    COUNT(*)                    AS n,
    AI_SUMMARIZE_AGG(memo_text) AS category_summary
FROM dispute_memos
GROUP BY dispute_category
ORDER BY n DESC;

-- ---------------------------------------------------------------------------
-- Why this matters: compare the cost of 4a (one call per merchant, ~dozens)
-- against calling AI_COMPLETE once per memo (200 calls). Aggregating at the
-- group grain is both cheaper and produces a more coherent summary.
-- ---------------------------------------------------------------------------

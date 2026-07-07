/* ============================================================================
   Module 8 · Lab 2 — Classify & filter, then MEASURE against ground truth  ⭐
   ----------------------------------------------------------------------------
   dispute_memos.dispute_category is a real label (from Module 2's generator),
   so we can score how well AI_CLASSIFY reads free text. The lesson isn't
   "AI is smart" -- it's "here's how you evaluate it and make it better."
   ========================================================================== */
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_RAW;

-- ---------------------------------------------------------------------------
-- 2a. Classify each memo into our 8-way dispute taxonomy.
--     AI_CLASSIFY(input, categories[, config]) -> {"labels":[...]}.
--     Categories can be plain strings OR {label, description} objects (better).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TEMP TABLE dispute_predictions AS
SELECT
    dispute_id,
    dispute_category AS actual_category,          -- ground truth
    AI_CLASSIFY(
        memo_text,
        ['FRAUD','GOODS_NOT_RECEIVED','DUPLICATE','SUBSCRIPTION',
         'DEFECTIVE','REFUND_NOT_PROCESSED','AMOUNT_MISMATCH','UNRECOGNIZED'],
        {'task_description':
            'Classify the card-payment dispute memo into the single best reason category.'}
    ):labels[0]::string AS predicted_category,
    memo_text
FROM dispute_memos;

SELECT * FROM dispute_predictions LIMIT 10;

-- ---------------------------------------------------------------------------
-- 2b. Overall accuracy vs the ground-truth label.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                                                                   AS n,
    COUNT_IF(predicted_category = actual_category)                             AS correct,
    ROUND(100.0 * COUNT_IF(predicted_category = actual_category) / COUNT(*), 1) AS accuracy_pct
FROM dispute_predictions;

-- ---------------------------------------------------------------------------
-- 2c. Where does it get confused? A mini confusion matrix of the misses.
-- ---------------------------------------------------------------------------
SELECT actual_category, predicted_category, COUNT(*) AS misses
FROM dispute_predictions
WHERE predicted_category <> actual_category
GROUP BY 1, 2
ORDER BY misses DESC;
-- Discussion: FRAUD vs UNRECOGNIZED overlap heavily (both map to reason code 10.4),
-- so many "errors" are defensible. Two levers usually lift accuracy:
--   (1) give each category a `description` instead of a bare label, and
--   (2) pass few-shot `examples` in the config object.
-- Try re-running 2a with richer categories and compare the accuracy_pct.

-- ---------------------------------------------------------------------------
-- 2d. AI_FILTER: a natural-language predicate, usable right in the WHERE clause.
--     Returns BOOLEAN. Use PROMPT('template {0}', col) to inject column values.
-- ---------------------------------------------------------------------------
SELECT dispute_id, dispute_category, memo_text
FROM dispute_memos
WHERE AI_FILTER(
    PROMPT('This card dispute describes fraud or a charge the cardholder does not recognize: {0}',
           memo_text)
)
LIMIT 20;

-- How well does the free-text filter line up with the labeled fraud-like memos?
SELECT
    COUNT(*)                                              AS flagged_by_ai_filter,
    COUNT_IF(dispute_category IN ('FRAUD','UNRECOGNIZED')) AS of_those_labeled_fraud_like
FROM dispute_memos
WHERE AI_FILTER(
    PROMPT('This card dispute describes fraud or a charge the cardholder does not recognize: {0}',
           memo_text)
);

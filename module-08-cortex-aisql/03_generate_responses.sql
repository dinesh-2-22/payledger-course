/* ============================================================================
   Module 8 · Lab 3 — Generation with AI_COMPLETE
   ----------------------------------------------------------------------------
   Draft customer replies, control the model, and -- most useful for a data
   pipeline -- turn free text into TYPED COLUMNS via structured output.

   ⚠️ Every row is a model call. Keep the LIMITs while you iterate.
   ========================================================================== */
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_RAW;

-- ---------------------------------------------------------------------------
-- 3a. Draft a short, empathetic reply per dispute (merchant name for context).
-- ---------------------------------------------------------------------------
SELECT
    d.dispute_id,
    m.merchant_name,
    AI_COMPLETE(
        'llama3.3-70b',
        'You are a card-issuer support agent. In three sentences, write a polite reply '
        || 'to the cardholder acknowledging this dispute and outlining next steps. '
        || 'Do not admit fault or promise a refund. Dispute memo: ' || d.memo_text
    ) AS draft_reply
FROM dispute_memos d
JOIN raw_merchant_master m USING (merchant_id)
LIMIT 5;

-- ---------------------------------------------------------------------------
-- 3b. Control generation with model_parameters (deterministic + capped length).
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    AI_COMPLETE(
        model  => 'llama3.3-70b',
        prompt => 'Summarize this card dispute in one neutral sentence: ' || memo_text,
        model_parameters => {'temperature': 0, 'max_tokens': 60}
    ) AS tight_summary
FROM dispute_memos
LIMIT 5;

-- ---------------------------------------------------------------------------
-- 3c. STRUCTURED OUTPUT -- the pipeline-friendly pattern.
--     response_format pins the shape, so free text becomes queryable columns.
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    triage:severity::string            AS severity,
    triage:refund_recommended::boolean AS refund_recommended,
    triage:recommended_action::string  AS recommended_action
FROM (
    SELECT
        dispute_id,
        AI_COMPLETE(
            model  => 'llama3.3-70b',
            prompt => 'Triage this card dispute for an operations queue. Memo: ' || memo_text,
            response_format => TYPE OBJECT(
                severity            STRING,   -- e.g. LOW / MEDIUM / HIGH
                refund_recommended  BOOLEAN,
                recommended_action  STRING
            )
        ) AS triage
    FROM dispute_memos
    LIMIT 10
);

-- ---------------------------------------------------------------------------
-- Production notes:
--   * Prefer SNOWFLAKE.CORTEX.TRY_COMPLETE (or show_details => TRUE) so a single
--     bad row doesn't abort a large batch.
--   * temperature => 0 makes summaries/triage repeatable run-to-run.
--   * Gate big generations behind LIMIT / TABLESAMPLE until the prompt is dialed in.
-- ---------------------------------------------------------------------------

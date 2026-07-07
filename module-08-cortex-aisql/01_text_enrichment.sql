/* ============================================================================
   Module 8 · Lab 1 — Row-level text enrichment with Cortex AISQL
   ----------------------------------------------------------------------------
   Enrich each dispute memo with sentiment, a summary, a translation, and an
   extracted fact -- all in plain SQL. No data leaves Snowflake.

   Prereqs:
     - Module 2 loaded (dispute_memos table)
     - GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE PAYLEDGER_DEV;
   ========================================================================== */
USE ROLE PAYLEDGER_DEV;
USE WAREHOUSE PAYLEDGER_WH;
USE SCHEMA PAYLEDGER.PAYLEDGER_RAW;

-- ---------------------------------------------------------------------------
-- 1a. Sentiment. AI_SENTIMENT returns an OBJECT:
--     {"categories":[{"name":"overall","sentiment":"negative"}, ...]}
--     Dispute memos should skew negative -- a quick sanity check on the function.
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    AI_SENTIMENT(memo_text):categories[0]:sentiment::string AS overall_sentiment,
    memo_text
FROM dispute_memos
LIMIT 10;

-- Distribution across the whole corpus
SELECT
    AI_SENTIMENT(memo_text):categories[0]:sentiment::string AS sentiment,
    COUNT(*) AS memos
FROM dispute_memos
GROUP BY 1
ORDER BY memos DESC;

-- ---------------------------------------------------------------------------
-- 1b. One-line summary per memo (row-level summarizer).
--     SUMMARIZE lives in the classic SNOWFLAKE.CORTEX namespace.
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    SNOWFLAKE.CORTEX.SUMMARIZE(memo_text) AS summary
FROM dispute_memos
LIMIT 5;

-- ---------------------------------------------------------------------------
-- 1c. Translate a memo to Spanish -- multilingual, still fully in-SQL.
--     AI_TRANSLATE(text, from_lang, to_lang);  '' as from_lang = auto-detect.
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    memo_text                            AS original_en,
    AI_TRANSLATE(memo_text, 'en', 'es')  AS translated_es
FROM dispute_memos
LIMIT 5;

-- ---------------------------------------------------------------------------
-- 1d. Extract a specific fact from free text.
--     EXTRACT_ANSWER returns an ARRAY of {answer, score}; take the top answer.
-- ---------------------------------------------------------------------------
SELECT
    dispute_id,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(memo_text, 'What is the disputed amount?')[0]:answer::string  AS disputed_amount,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(memo_text, 'Why is the cardholder disputing?')[0]:answer::string AS extracted_reason
FROM dispute_memos
LIMIT 10;

-- ---------------------------------------------------------------------------
-- 1e. Cost awareness: estimate token volume BEFORE running a big job.
--     AI_COUNT_TOKENS(model_or_function, text).
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                                        AS memos,
    SUM(AI_COUNT_TOKENS('llama3.3-70b', memo_text)) AS total_prompt_tokens,
    AVG(AI_COUNT_TOKENS('llama3.3-70b', memo_text)) AS avg_tokens_per_memo
FROM dispute_memos;

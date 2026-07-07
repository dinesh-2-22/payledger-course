# Claude Code in Module 2 — "draft & critique"

The theme across this whole course: use Claude Code as a **draft-and-critique partner**,
never as blind autocomplete. Below are two techniques tuned to *this* module
(generating data + landing DDL). Try them, then read what came back critically.

---

## Technique 1 — Generate a realistic generator from a DDL

You have a `CREATE TABLE` and want plausible synthetic rows. Hand the DDL to
Claude Code and let it draft the Faker logic — then **critique it for skew**.

**Prompt:**
> Here's my `raw_transactions` CREATE TABLE (paste from `stage_and_copy.sql`).
> Write a Python Faker function that produces realistic rows. Transactions should
> reference existing `card_id`s and `merchant_id`s I pass in. Weight `transaction_type`
> ~80% PURCHASE. Spread `transaction_timestamp` across the last 90 days.

**Then critique what it gives you — this is the actual learning:**
- Are amounts uniformly random (unrealistic) or is there a long tail of large txns?
- Does every merchant get roughly equal traffic, or is there realistic concentration?
- Are declines correlated with anything, or purely random?

> Follow-up: "Real payment data is skewed — a few merchants do most volume, and
> most amounts are small with a long tail. Rework the amount and merchant-selection
> logic to reflect that." Compare before/after distributions.

---

## Technique 2 — Diff a CREATE TABLE against the staged CSV header

The #1 cause of a failed `COPY INTO` is a column mismatch between the table and the
file. Let Claude Code catch it before Snowflake does.

**Prompt:**
> Here's the header row of `data/raw_gateway_log.csv`:
> `gateway_log_id,transaction_id,gateway_name,...`
> And here's my `CREATE TABLE raw_gateway_log (...)`.
> Diff them: list any columns that are missing, extra, out of order, or whose name
> doesn't match. Flag any type that looks wrong for the sample values I'll paste.

**Why this matters:** `COPY INTO` matches by *position*, not name. A reordered or
missing column loads silently-wrong data into the wrong field. Catching this at the
header level saves a confusing debugging session later.

> Bonus: paste a `COPY INTO ... VALIDATION_MODE = RETURN_ERRORS` result and ask
> Claude Code to explain the first failure in plain English and suggest the file-format
> fix (usually `FIELD_OPTIONALLY_ENCLOSED_BY` for the free-text `memo_text` column).

---

## Anti-pattern to avoid

Don't ask Claude Code to "just generate 10k rows of fake payment data" and paste
the result. You lose reproducibility (no seed), referential integrity (orphan FKs),
and the learning. Generate *code* you can re-run and reason about — not data.

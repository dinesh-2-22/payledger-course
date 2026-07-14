# Using Claude Code in Module 3

**Technique 1 — Trace a MERGE's grain before you run it.** Paste one of the `etl/*/load_*.sql`
procedures to Claude Code and ask it to state the output grain (one row per what?) and
whether the `USING (...)` subquery could ever produce duplicate keys for that grain — e.g.
for `int_settlements`, ask it to verify the `ROW_NUMBER() OVER (PARTITION BY transaction_id
ORDER BY gateway_timestamp DESC)` really guarantees one row per `transaction_id` even if two
gateway events share the same timestamp. This catches a `MERGE` "matched more than once"
error before you hit it live.

**Technique 2 — Diff the Task DAG against the lineage doc.** Paste `orchestration/run_pipeline.sql`
alongside the Mermaid diagram in `docs/lineage.md` and ask Claude Code to confirm every
`AFTER` dependency in the Tasks matches an edge in the diagram, and flag anything that's
in one but not the other. This is the same kind of cross-file consistency check you'll want
before every module's checkpoint, but it's especially valuable here since a wrong `AFTER`
means a task fires before its input is actually ready.

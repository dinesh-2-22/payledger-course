# Using Claude Code in Module 1

**Technique 1 — Interrogate the grants.** Paste the `GRANT` statements from `setup.sql` into
Claude Code and ask it to explain the least-privilege implications of each one, and what
would break downstream if you skipped the `FUTURE TABLES`/`FUTURE STAGES` grants. (Answer:
Module 2's `COPY INTO` would fail with an authorization error even though `PAYLEDGER_RAW`
itself exists — the schema-level grant doesn't retroactively cover objects created after it.)

**Technique 2 — Draft a teardown script.** Ask Claude Code to write a `teardown.sql` that
mirrors `setup.sql` in reverse (`DROP WAREHOUSE`, `DROP DATABASE`, `DROP ROLE`, in that
order). Useful for resetting your trial account to a clean slate if you want to re-run
Module 1 from scratch, or for an instructor resetting between cohorts. Ask it to explain
why the drop order matters (e.g. why the role should go last, after nothing depends on it).

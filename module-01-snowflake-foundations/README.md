# Module 1 — Snowflake foundations

> **Goal:** Bootstrap the warehouse, database, schemas, and role that every later module
> depends on. This is the step Module 2 (and everything after it) assumes is already done.

---

## Prerequisites

- A Snowflake **trial account** (Module 0). You're logged in as your default user, which
  is granted the `ACCOUNTADMIN` role automatically on a trial — `setup.sql` needs that role
  to create warehouses and roles.

---

## Steps

### 1. Run the bootstrap script

Open a Snowsight worksheet (or connect via SnowSQL) and run `setup.sql` top to bottom.
It's idempotent, so re-running it after a partial failure is safe.

It creates:

| Object | Name | Notes |
|---|---|---|
| Warehouse | `PAYLEDGER_WH` | `XSMALL`, auto-suspend after 60s, starts suspended — won't burn trial credits sitting idle |
| Database | `PAYLEDGER` | |
| Schema | `PAYLEDGER.PAYLEDGER_RAW` | landing zone — Module 2 lands raw CSVs here |
| Schema | `PAYLEDGER.PAYLEDGER_DW` | modeled schema — staging/intermediate/marts, Module 3+ |
| Role | `PAYLEDGER_DEV` | granted to whoever runs the script (`CURRENT_USER()`); owns everything above |

### 2. Verify

The last statement in `setup.sql` switches into `PAYLEDGER_DEV` / `PAYLEDGER_WH` /
`PAYLEDGER` / `PAYLEDGER_RAW` and selects the current context. Confirm it returns:

```
PAYLEDGER_DEV | PAYLEDGER_WH | PAYLEDGER | PAYLEDGER_RAW
```

---

## Concepts

- **Why a dedicated XS warehouse with auto-suspend?** Compute is what costs credits on a
  trial account, not storage. `AUTO_SUSPEND = 60` means the warehouse suspends a minute
  after the last query finishes, and `AUTO_RESUME` brings it back instantly on the next
  query — you never pay for idle compute between study sessions.
- **Why `PAYLEDGER_RAW` vs `PAYLEDGER_DW`?** Landing data and modeled data live in separate
  schemas so raw loads (Module 2) never collide with the staging → intermediate → mart
  layers built on top of them (Module 3+). See `docs/lineage.md` for the full layer map.
- **Time Travel.** Snowflake keeps recent versions of table data automatically, so you can
  query `AT`/`BEFORE` a point in time, or `UNDROP` a table you dropped by mistake. There's
  nothing to demonstrate yet since no tables exist — you'll use this for real once Module 2
  lands data and Module 3 starts mutating it.

---

## ✅ Checkpoint

You're ready for Module 2 when:

- [ ] `setup.sql` ran without errors.
- [ ] The final verification query returns `PAYLEDGER_DEV | PAYLEDGER_WH | PAYLEDGER | PAYLEDGER_RAW`.

---

## Where this goes next

**Module 2**'s prerequisites section assumes exactly these objects exist — `PAYLEDGER`
database, `PAYLEDGER_RAW` schema, `PAYLEDGER_WH` warehouse, `PAYLEDGER_DEV` role — before you
generate and land the mock data.

See **`claude-code.md`** for two ways Claude Code accelerates this module.

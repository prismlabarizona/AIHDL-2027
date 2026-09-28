# Rank 1 — AI Chat Logs

This folder contains the AI-assisted design session that implemented the fix for
**Rank 1 (CRITICAL) — Key Registers Readable via Bus** from the DP3 security
evaluation report (`DP3_submission/security_report.pdf`).

## Contents

- **`chatlog.md`** — Markdown transcript of the session. Organized chronologically
  by phase: context gathering, attack analysis, scope selection, option
  comparison, implementation, testbench updates, race-condition debugging,
  verification, and commits.
- **`chatlog.pdf`** — Typeset PDF rendering of `chatlog.md` (generated with
  pandoc + xelatex).

## What was fixed

- `AES128/AES_memory.v` — reads of key register addresses `0x02-0x05` now return
  `32'b0` instead of the live key bytes. Writes are unchanged.
- `AES128/testbenches/AES_memory_tb.v` — bus-readback assertions updated; new
  `check_key` helper preserves coverage of `key_lock` and key-persistence
  properties via the internal `original_key` wire.
- `AES128/testbenches/AES_peripheral_tb.v` — TEST 7 (soft-reset-clears-state)
  switched to peeking `original_key` directly; one-cycle settling delay added
  after `load_key` to avoid sampling before the final NBA commits.

Side fix (prerequisite for running the top-level TB on Icarus Verilog):

- `AES128/AES_encryption_engine.v` — moved `reg` declarations above
  `assign cipher = state_reg;`. No logic change; resolves Icarus's
  declaration-before-use error.

## Commits

| Commit  | Subject                                                                  |
|---------|--------------------------------------------------------------------------|
| c2c553f | Fix Rank 1 vulnerability: make AES key registers write-only              |
| dde25ef | Fix declaration order in AES_encryption_engine so Icarus can elaborate   |

Branch: `DP3` (pushed to `origin`).

## Verification

Both affected Icarus testbenches (`[1] Top Level Integration` and
`[5] Memory Interface`) report all assertions passing after the change. Key
security properties (`key_lock` prevents overwrite; key persists across
encryptions; soft reset zeroizes the key) are still verified — just via the
internal `original_key` wire rather than bus readback, because bus reads of the
key addresses now return `0` by design.

## Out of scope

Ranks 2, 3, 4, 5, 6, 7, 8 from the security report remain unaddressed in this
session. See the report for details.

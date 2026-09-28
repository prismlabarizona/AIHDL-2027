# Rank 2 — AI Chat Logs

This folder contains the AI-assisted design session that implemented the fix for
**Rank 2 (CRITICAL) — FSM and Round Counter Have No Integrity Protection** from
the DP3 security evaluation report (`DP3_submission/security_report.pdf`).

## Contents

- **`chatlog.md`** — Markdown transcript of the session. Organized chronologically
  by turn: reading the report, designing the fix, justifying each protection,
  scoping from the `Updated_*` files back onto the live files, implementation,
  debugging the sim-only reset race, verification, and commit.
- **`chatlog.pdf`** — Typeset PDF rendering of `chatlog.md` (generated with
  pandoc + xelatex).

## What was fixed

- `AES128/AES_control_unit.v` — rewritten with a one-hot 4-bit FSM
  `{IDLE, RUN, DONE, FAULT}`, a shadow counter enforcing
  `count + count_shadow == 22`, continuous integrity checks, FAULT that is
  sticky across soft reset (only the hard reset pin `reset_n` clears it), a
  terminal-transition guard that blocks early DONE, and a new `fault` output.
- `peripheral.v` — new `fault` wire; `engine_reset = core_reset | fault`
  routed into both engines so `state_reg`, `sub_out_hi`, and `round_key` are
  wiped via their existing async-reset paths whenever a fault is detected.
- `AES128/testbenches/AES_control_unit_tb.v` — `fault` port added; 11
  fault-injection assertions appended (count glitch, shadow-counter glitch,
  illegal one-hot state, sticky FAULT across soft reset, hard reset clears
  FAULT, datapath zeroed in FAULT, start ignored in FAULT).

Dead code removed:

- `AES128/Updated_Control_Unit.v`, `AES128/Updated_Encyption_Engine_4_S-boexs.v`,
  `AES128/Updated_Peripheral.v` — superseded by the non-`Updated_` versions
  that are the authoritative files for this design.

## Commits

| Commit  | Subject                                                                  |
|---------|--------------------------------------------------------------------------|
| 491d2dc | Fix Rank 2 vulnerability: FSM and round-counter integrity protection     |

Branch: `DP3`.

## Verification

- Control-unit testbench (`run_tb.py` option 2): 27/27 asserts pass — 16
  existing plus 11 new Rank 2 fault-injection cases using Verilog
  `force`/`release` to glitch `count`, `count_shadow`, and `state`.
- Peripheral integration testbench (`run_tb.py` option 1): 9/9 tests pass,
  including FIPS-197 AES-128 test vectors and the soft-reset-clears-state
  case.

## Security properties verified

After this change, an attacker attempting a Differential Fault Analysis (DFA)
campaign against the AES core faces:

- Any single-bit glitch on `count`, `count_shadow`, or `state` is caught in
  the same cycle and latches FAULT.
- FAULT forces `done=0`, zeroes the exposed counter, drops
  `key_engine_start`, and (via `engine_reset`) wipes the cipher output,
  SubBytes intermediate, and round-key registers.
- Software cannot clear FAULT — the memory-mapped soft reset (`reset_s`) is
  gated to preserve FAULT. Only the physical hard reset pin (`reset_n`) can
  recover a faulted core.

## Out of scope

Ranks 3, 4, 5, 6, 7, 8 from the security report remain unaddressed in this
session. See the report for details.

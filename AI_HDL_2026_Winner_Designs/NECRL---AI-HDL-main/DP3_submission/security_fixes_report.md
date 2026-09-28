# AES-128 Peripheral Security Hardening Report

## DP3 — Security Vulnerability Fixes

**Project:** NECRL AI-HDL AES-128 Peripheral (TinyQV Platform)  
**Target:** Skywater sky130 PDK, OpenLane flow  
**Date:** April 2026  
**Branch:** `DP3`

---

## Table of Contents

1. [How We Found the Vulnerabilities: Multi-Agent Security Evaluation](#1-how-we-found-the-vulnerabilities-multi-agent-security-evaluation)
2. [Executive Summary](#2-executive-summary)
3. [Background & Terminology](#3-background--terminology)
4. [Architecture Overview](#4-architecture-overview)
5. [Rank 1 — Key Register Read-Back Exposure](#5-rank-1--key-register-read-back-exposure)
6. [Rank 2 — FSM and Round-Counter Integrity](#6-rank-2--fsm-and-round-counter-integrity)
7. [Rank 5 — Soft-Reset Race Condition](#7-rank-5--soft-reset-race-condition)
8. [Rank 6 — LFSR Random Stall (DPA Countermeasure)](#8-rank-6--lfsr-random-stall-dpa-countermeasure)
9. [Rank 7 — Fault Signal Visibility in Status Register](#9-rank-7--fault-signal-visibility-in-status-register)
10. [Rank 8 — FIPS 197 Power-On Self-Test](#10-rank-8--fips-197-power-on-self-test)
11. [Vulnerabilities Not Addressed](#11-vulnerabilities-not-addressed)
12. [Test Summary](#12-test-summary)
13. [PPA Impact](#13-ppa-impact)

---

## 1. How We Found the Vulnerabilities: Multi-Agent Security Evaluation

### Why Not Just Review It Ourselves?

When you design something, you know what it's *supposed* to do. That makes you the worst person to find the security holes — your mental model fills in gaps that an attacker would exploit. Security review is fundamentally adversarial: the reviewer needs to think like a cryptographer, a hardware engineer, and someone trying to break into the system, all at the same time. No single reviewer naturally covers all of that.

We needed a way to get genuinely different perspectives arguing with each other about our design — not just a checklist, but a real debate about what's actually exploitable and how bad it would be.

### What We Did

We used Claude Code to set up a structured debate between multiple AI agents, each given a different role and the full RTL source. Think of it like a security review meeting, but the participants are specialists who don't share each other's blind spots:

```
  ┌─────────────────────────────────────────────────────────┐
  │                   Agent Chatroom                        │
  │                                                         │
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
  │  │ Cryptography │  │  Hardware   │  │  Adversarial │    │
  │  │   Reviewer   │  │  Security   │  │   Red Team   │    │
  │  │              │  │  Reviewer   │  │              │    │
  │  │ Focuses on   │  │ Focuses on  │  │ Focuses on   │    │
  │  │ algorithmic  │  │ physical    │  │ "what would  │    │
  │  │ correctness  │  │ attack      │  │ I actually   │    │
  │  │ and math     │  │ surfaces    │  │ do to break  │    │
  │  │              │  │             │  │ this?"       │    │
  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘    │
  │         │                │                │            │
  │         └────────────────┼────────────────┘            │
  │                          │                              │
  │                          ▼                              │
  │                Debate & Challenge                       │
  │                          │                              │
  │                          ▼                              │
  │               Ranked Vulnerability List                 │
  │                          │                              │
  │                          ▼                              │
  │               security_report.pdf                       │
  └─────────────────────────────────────────────────────────┘
```

Each agent independently analyzed the RTL, then they debated each other's findings — pushing back on severity, questioning whether attacks were realistic, and catching things the others missed.

### How the Debate Worked

1. **Independent analysis:** Each agent read the RTL and proposed vulnerabilities with severity ratings.
2. **Cross-examination:** They challenged each other. "Is Rank 3 really HIGH if it needs 800 power traces?" "Yes — 800 traces takes under an hour with off-the-shelf equipment."
3. **Severity ranking:** Through back-and-forth, they calibrated a consistent severity scale that weighed theoretical feasibility against practical cost and required equipment.
4. **Final report:** The agreed-upon ranked list became `security_report.pdf`, which was our work order for the fixes in this document.

### The Result

The evaluation produced 8 ranked vulnerabilities. We fixed 6 of them (Ranks 1, 2, 5, 6, 7, 8) and made a deliberate decision to defer the remaining 2 (Ranks 3, 4) due to area constraints (see [Section 11](#11-vulnerabilities-not-addressed)).

The full security evaluation is available in `DP3_submission/security_report.pdf`.

---

## 2. Executive Summary

Six security vulnerabilities (Ranks 1, 2, 5, 6, 7, 8) were identified in the AES-128 peripheral's security report and have been fixed on the `DP3` branch. The fixes span four RTL source files and five testbench files. All five testbench suites pass after the changes.

| Rank | Severity | Vulnerability | Status |
|------|----------|--------------|--------|
| 1 | CRITICAL | Secret key readable via bus | **Fixed** |
| 2 | CRITICAL | No FSM/counter integrity checks | **Fixed** |
| 3 | HIGH | Unmasked S-boxes (DPA) | Not addressed |
| 4 | HIGH | Two-phase SubBytes fault window | Not addressed |
| 5 | HIGH | Soft-reset race condition | **Fixed** |
| 6 | MEDIUM | No timing randomization (DPA) | **Fixed** |
| 7 | MEDIUM | Fault signal not software-visible | **Fixed** |
| 8 | LOW | No power-on self-test | **Fixed** |

---

## 3. Background & Terminology

This section defines the technical terms used throughout the report.

### Cryptographic Terms

| Term | Definition |
|------|-----------|
| **AES-128** | Advanced Encryption Standard with a 128-bit key. Encrypts 128-bit blocks of data through 10 rounds of substitution, permutation, and key mixing. Standardized by NIST as FIPS 197. |
| **Round Key** | A 128-bit key derived from the original key for each of the 10 encryption rounds. Generated by the Key Expansion (key schedule) algorithm. |
| **S-box** | Substitution box — a fixed nonlinear lookup table that maps each input byte to a different output byte. Provides the "confusion" property of AES. |
| **SubBytes** | The AES round step that passes each of the 16 bytes in the state through the S-box. |
| **MixColumns** | The AES round step that multiplies each 4-byte column by a fixed polynomial in GF(2^8). Provides the "diffusion" property. |
| **AddRoundKey** | XOR of the current state with the current round key. |
| **FIPS 197** | The NIST standard that defines AES. Includes known-answer test vectors in its appendices. |

### Attack Terminology

| Term | Definition |
|------|-----------|
| **DPA** | Differential Power Analysis — a side-channel attack that statistically correlates power consumption traces with intermediate encryption values to recover the secret key. Requires physical access to measure current draw during encryption. |
| **DFA** | Differential Fault Analysis — an active attack that injects faults (e.g., voltage glitch, laser pulse) during encryption to cause incorrect output. Comparing correct and faulted ciphertexts allows mathematical key recovery. Typically requires 2-4 faults. |
| **Fault Injection** | Deliberately disrupting a chip's operation (via voltage glitch, clock glitch, electromagnetic pulse, or laser) to alter register values or skip instructions. |
| **Side-Channel Attack** | Extracting secret data by observing physical characteristics (power, timing, electromagnetic emissions) rather than exploiting algorithmic weaknesses. |

### Hardware Design Terms

| Term | Definition |
|------|-----------|
| **FSM** | Finite State Machine — a sequential circuit whose next state depends on the current state and inputs. Used here to control the AES encryption flow (IDLE -> RUN -> DONE). |
| **One-Hot Encoding** | An FSM encoding where exactly one bit is high in each valid state (e.g., `0001`, `0010`, `0100`, `1000`). Any single bit-flip produces an invalid code, enabling fault detection. |
| **LFSR** | Linear Feedback Shift Register — a shift register whose input bit is a function (XOR) of selected output bits. Produces a pseudo-random sequence. Used here to generate random stall timing. |
| **NBA** | Non-Blocking Assignment (`<=` in Verilog). Register updates are scheduled and take effect at the end of the simulation time step, not immediately. |
| **RTL** | Register-Transfer Level — the abstraction level at which digital circuits are described using registers and combinational logic between them. |
| **Sticky** | A register value that, once set, cannot be cleared except by a specific condition (e.g., only a hard reset can clear a sticky fault latch). |

---

## 4. Architecture Overview

The AES-128 peripheral consists of four main modules connected through a top-level peripheral wrapper:

```
                         peripheral.v (tqvp_necrl_spi)
  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  ┌──────────────┐    ┌───────────────────┐                  │
  │  │  AES_memory   │    │ AES_control_unit  │                  │
  │  │              │    │                   │                  │
  │  │ - key_mem    │    │ - One-hot FSM     │                  │
  │  │ - plaintext  │    │ - Shadow counter  │                  │
  │  │ - ciphertext │    │ - LFSR stall      │                  │
  │  │ - control_reg│    │ - Fault detection  │                  │
  │  │ - status_reg │    │                   │                  │
  │  └──────┬───────┘    └────────┬──────────┘                  │
  │         │                     │                              │
  │         │    selected_data    │   encryption_engine_count    │
  │         │    selected_key     │   key_engine_start           │
  │         │         │           │   stall                      │
  │         │         ▼           ▼                              │
  │  ┌──────┴─────────────┐  ┌──────────────────┐              │
  │  │ AES_encryption     │  │ AES_key_engine   │              │
  │  │ _engine            │  │                  │              │
  │  │                    │  │ - Key expansion  │              │
  │  │ - 10-round AES     │◄─┤ - 2 S-boxes     │              │
  │  │ - 8 S-boxes        │  │ - Round keys     │              │
  │  │ - 2-phase SubBytes │  │                  │              │
  │  └────────────────────┘  └──────────────────┘              │
  │                                                              │
  │  ┌──────────────────────────────────────────┐               │
  │  │ Rank 8: Self-Test Controller             │               │
  │  │ - FIPS test vectors (hardcoded)          │               │
  │  │ - Muxes key/data into engines at boot    │               │
  │  │ - Gates effective_start on pass/fail     │               │
  │  └──────────────────────────────────────────┘               │
  └──────────────────────────────────────────────────────────────┘
```

### Bus Address Map

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| `0x00` | Control | R/W | bit 0: start, bit 1: soft reset, bit 2: key_lock, bit 3: auto_start |
| `0x01` | Status | R | bit 0: done, bit 1: fault, bit 2: selftest_done, bit 3: selftest_fail |
| `0x02-0x05` | Key | W-only | 128-bit AES key (4 x 32-bit words). Reads return 0. |
| `0x06-0x09` | Plaintext | R/W | 128-bit plaintext input (double-buffered) |
| `0x0A-0x0D` | Ciphertext | R | 128-bit encryption result |

---

## 5. Rank 1 — Key Register Read-Back Exposure

### The Vulnerability

The AES peripheral exposed the 128-bit secret key at bus addresses `0x02`-`0x05`. Any bus master could extract the entire key with four 32-bit reads — no cryptographic knowledge, special equipment, or physical access required. The existing `key_lock` mechanism (control_reg bit 2) only blocked *writes* to the key registers; it did nothing to block *reads*.

**Severity:** CRITICAL — complete key recovery with zero effort.

### The Fix

**File:** `AES128/AES_memory.v`

The read path for key addresses now returns `32'b0` unconditionally:

```verilog
// Key registers are write-only. Reads return zero so that a
// compromised or buggy bus master cannot exfiltrate the secret key.
6'h02: data_out = 32'b0;
6'h03: data_out = 32'b0;
6'h04: data_out = 32'b0;
6'h05: data_out = 32'b0;
```

The write path is unchanged — software can still load keys. Internally, the key propagates to the encryption engine via the `original_key` wire (a concatenation of `key_mem[3:0]`), which is never exposed on the bus.

### How It Was Tested

Since bus reads of key addresses now always return zero, testbench assertions must verify key integrity through internal wire probing instead of bus reads.

**AES_memory_tb.v** — Added a `check_key` helper task that directly samples the internal `original_key` wire and compares it against an expected 128-bit value. Used at four critical points:

| Check Point | What It Verifies |
|-------------|-----------------|
| After key load | Key actually landed in registers (bus reads are 0, so we probe internally) |
| After locked overwrite attempt | `key_lock` prevents mutation (can't verify via bus since bus always returns 0) |
| After encryption A completes | Key persists across encryptions |
| After encryption B completes | Key still intact after key-reuse scenario |

**AES_peripheral_tb.v** — TEST 7 ("Soft Reset clears state") was updated to probe `dut.aes_memory_inst.original_key` directly instead of using bus reads, with a 1-cycle settling delay to ensure the NBA from the final key write commits before sampling.

---

## 6. Rank 2 — FSM and Round-Counter Integrity

### The Vulnerability

The control unit's FSM used a simple 2-bit binary encoding with no integrity checks. The 5-bit round counter had no redundancy. A single voltage glitch could:

1. Skip the FSM directly to the DONE state, truncating encryption
2. Corrupt the round counter, producing fewer rounds
3. Trigger a silent "out-of-range count" fallback that completed encryption early

Any of these produces a weakened ciphertext. Comparing a correct and a faulted ciphertext through **Differential Fault Analysis (DFA)** allows full 128-bit key recovery with as few as 2-4 faults.

**Severity:** CRITICAL — full key recovery with physical access and fault injection equipment.

### The Fix

**File:** `AES128/AES_control_unit.v`

#### One-Hot FSM Encoding

The FSM was changed from 2-bit binary to 4-bit one-hot encoding:

```verilog
localparam [3:0]
    IDLE  = 4'b0001,
    RUN   = 4'b0010,
    DONE  = 4'b0100,
    FAULT = 4'b1000;   // new terminal state
```

In one-hot encoding, exactly one bit is set in each valid state. Any single bit-flip (the most common glitch effect) produces either a 0-hot or 2-hot code, which is always illegal. This provides inherent fault detection:

```
Valid states:    0001  0010  0100  1000
Single flip of 0001 → 0000, 0011, 0101, 1001  (all illegal)
```

#### Shadow Counter

A redundant 5-bit `count_shadow` register maintains the invariant `count + count_shadow == 22` at all times:

```verilog
reg [4:0] count;
reg [4:0] count_shadow;   // invariant: count + count_shadow == 22
```

When count increments, count_shadow decrements by the same amount. A glitch that corrupts either register breaks the invariant.

#### Integrity Detectors

Two combinational detectors run continuously:

```verilog
wire state_ok       = (state == IDLE) || (state == RUN)
                   || (state == DONE) || (state == FAULT);
wire count_ok       = (count + count_shadow == 6'd22);
wire integrity_fail = !state_ok || !count_ok;
```

If either check fails, the FSM immediately transitions to FAULT.

#### FAULT State Behavior

- **Terminal:** FAULT state loops to itself. No start pulse can exit it.
- **Engine wipe:** `fault` output is ORed into `engine_reset`, which triggers the async reset paths of both the encryption engine (zeroes `state_reg`) and the key engine (zeroes `round_key`). This ensures no partial-encryption data remains.
- **Sticky:** A `fault_latch` register latches on any integrity failure. It survives soft reset and can only be cleared by a full hard reset (`reset_n`). This prevents an attacker from using soft reset to clear a detected fault.

```verilog
always @(posedge clk or posedge reset_n) begin
    if (reset_n)
        fault_latch <= 1'b0;        // only hard reset clears
    else if (integrity_fail || state == FAULT)
        fault_latch <= 1'b1;        // once set, stays set
end
```

### How It Was Tested

The control unit testbench includes 11 fault-injection assertions using Verilog `force`/`release`:

| Test | Injection | Expected Result |
|------|-----------|----------------|
| Happy path baseline | None | `fault == 0` throughout |
| Count glitch | Flip bit 2 of `count` mid-run | `fault == 1`, `done == 0`, outputs zeroed |
| FAULT survives soft reset | `reset_s` pulse after fault | `fault` remains 1 |
| Hard reset clears FAULT | `reset_n` pulse | `fault` clears to 0 |
| Illegal one-hot state | Force `state = 4'b0011` (2-hot) | `fault == 1` |
| Start ignored in FAULT | Pulse `start` while faulted | `fault` remains 1, `done` stays 0 |
| Shadow counter glitch | Flip bit 3 of `count_shadow` | `fault == 1` |

---

## 7. Rank 5 — Soft-Reset Race Condition

### The Vulnerability

A bus master could write the soft-reset bit (control_reg bit 1) while the AES engine was actively encrypting. This caused two problems:

1. **DoS key wipe:** The soft reset cleared `key_mem` while the key engine was mid-expansion, destroying the key without completing the encryption.
2. **Key leakage:** If the key was wiped mid-expansion, the key engine would produce round keys derived from a mix of the original key (early rounds) and zeroes (later rounds). The resulting malformed ciphertext mathematically exposes the original key.

**Severity:** HIGH — denial of service and potential key recovery.

### The Fix

**File:** `AES128/AES_memory.v`

An interlock gates soft-reset on engine-idle:

```verilog
6'h00: begin
    if (control_reg[0]) begin
        // Engine busy: mask out bit 1 (reset), preserve bit 0 (start)
        control_reg <= {data_in[31:2], 1'b0, control_reg[0]};
    end else begin
        // Engine idle: accept full write
        control_reg <= data_in;
    end
    // Soft reset only honored when idle
    if (data_in[1] && !control_reg[0]) begin
        reset_s <= 1'b1;
        control_reg <= 32'b0;
        key_mem[0] <= 32'b0;  // ... clears all state
    end
end
```

**Key behaviors:**
- While busy (`control_reg[0] == 1`): bit 1 (soft reset) is forced to 0 in any write. Bit 0 (start) is preserved from the current register, preventing accidental de-assertion mid-run.
- While idle (`control_reg[0] == 0`): the full write goes through and soft reset is honored.

### How It Was Tested

**AES_memory_tb.v** — TEST 5 verifies 7 assertions:

| Assertion | What It Checks |
|-----------|---------------|
| `t5_start_asserted` | Encryption actually started |
| `t5_reset_suppressed_while_busy` | `reset_s` stays 0 when reset bit written during encryption |
| `t5_start_still_asserted` | Start bit not de-asserted by the rejected write |
| Key intact after reset attempt | Internal key unchanged during busy-time reset |
| `t5_reset_bit_masked_in_combined_write` | Combined writes (bits [1:3] together) are masked correctly |
| `t5_reset_honored_when_idle` | `reset_s` asserts when written after engine finishes |
| Key cleared after idle reset | Soft reset succeeds when engine is idle |

---

## 8. Rank 6 — LFSR Random Stall (DPA Countermeasure)

### The Vulnerability

Without timing randomization, every encryption takes the same number of clock cycles. An attacker performing **Differential Power Analysis (DPA)** can average power traces across many encryptions, aligning them perfectly by cycle count. This alignment amplifies the signal-to-noise ratio, enabling key recovery in as few as 500-800 traces.

**Severity:** MEDIUM — requires physical access and power measurement equipment.

### The Fix

**File:** `AES128/AES_control_unit.v`

An 8-bit LFSR introduces random stall cycles during encryption, desynchronizing the power trace alignment that DPA relies on.

#### LFSR Design

```verilog
reg [7:0] lfsr;   // 8-bit LFSR (x^8 + x^6 + x^5 + x^4 + 1)

always @(posedge clk or posedge reset_n) begin
    if (reset_n)
        lfsr <= 8'hAC;   // seed
    else
        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
end
```

The LFSR is free-running (advances every clock) and only resets on hard reset. Soft resets do not affect it, so the random phase is preserved across encryption runs — an attacker cannot predict the stall pattern by triggering soft resets.

#### Stall Condition

```verilog
assign stall = (state == RUN)
            && (count >= 5'd2) && (count <= 5'd21)   // mid-round only
            && (stall_count < 4'd8)                    // max 8 stalls per run
            && !integrity_fail
            && (lfsr[1:0] == 2'b00);                   // ~25% probability
```

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Probability per eligible cycle | ~25% (`lfsr[1:0] == 2'b00`) | High enough to meaningfully disrupt DPA alignment |
| Max stalls per encryption | 8 | Bounds worst-case latency increase |
| Eligible count range | 2-21 | Excludes initial AddRoundKey (count 1) and terminal transition (count 22) to avoid complicating the FSM |

#### How Stall Gates the Engines

When `stall == 1`:

- **Control unit:** Round counter freezes. `stall_count` increments.
- **Encryption engine:** `if (!stall)` gate prevents `state_reg` and `sub_out_hi` from updating.
- **Key engine:** `if (!stall)` gate prevents `temp_key`, `key_phase`, and `current_state` from advancing.
- **Encryption engine count output:** Driven to `5'd0` during stalls, so the encryption engine sees "idle" and holds its state.

All three modules stall in lockstep — the stall signal is a single wire from the control unit to both engines. This maintains synchronization between the round counter, key schedule, and encryption state.

### How It Was Tested

The stall mechanism is verified indirectly through the full integration testbench — all encryption results remain correct despite the random stalls. The PPA (Power, Performance, Area) was measured via OpenLane synthesis to confirm the area overhead is within budget (+2.4% vs DP2).

---

## 9. Rank 7 — Fault Signal Visibility in Status Register

### The Vulnerability

Rank 2 added fault detection with a FAULT state, but the `fault` signal was not software-visible. Software polling the status register (`0x01`) could only see `done` (bit 0). Both "still running" and "halted by integrity failure" showed `done == 0` — software could not distinguish them and would wait forever for an encryption that would never complete.

**Severity:** MEDIUM — software cannot detect or recover from fault events.

### The Fix

**Files:** `peripheral.v`, `AES128/AES_memory.v`

The existing `fault` output from the control unit is wired through the peripheral into AES_memory and exposed as bit 1 of the status register:

```verilog
// AES_memory.v — status register read (address 0x01)
6'h01: data_out = {28'b0, selftest_fail, selftest_done, fault, status_done};
```

**Status register bit layout:**

```
  Bit 3       Bit 2          Bit 1      Bit 0
┌──────────┬──────────────┬──────────┬──────────┐
│selftest  │ selftest     │  fault   │   done   │
│  _fail   │   _done      │          │          │
└──────────┴──────────────┴──────────┴──────────┘
```

Software can now poll `status & 0x2` to detect a fault condition and take appropriate action (e.g., log the event, trigger a hard reset, refuse to use the peripheral).

### How It Was Tested

**AES_memory_tb.v** — TEST 6 verifies three assertions:

| Condition | Expected Status | Pass? |
|-----------|----------------|-------|
| `fault=0, done=0` | `0x00000000` | Yes |
| `fault=1, done=0` | `0x00000002` (bit 1 set) | Yes |
| `fault=0, done=0` (fault de-asserted) | `0x00000000` | Yes |

---

## 10. Rank 8 — FIPS 197 Power-On Self-Test

### The Vulnerability

The chip had no way to verify that its AES implementation was correct. If a manufacturing defect subtly altered the S-box logic, or if a wire was misconnected during fabrication, the chip would silently encrypt data using a broken algorithm. The FIPS 197 specification includes known-answer test vectors for exactly this purpose.

**Severity:** LOW — risk is manufacturing defects producing weak ciphertext, not active attacks.

### The Fix

**Files:** `peripheral.v`, `AES128/AES_memory.v`, `AES128/AES_control_unit.v`

#### Self-Test Controller (peripheral.v)

A state machine runs automatically on power-up:

```
  Hard Reset (rst_n)
        │
        ▼
  selftest_active = 1
  selftest_started = 0
        │
        ▼
  Pulse selftest_start ──► effective_start ──► Control Unit
  Mux FIPS vectors into engines:
    selected_key  = SELFTEST_KEY
    selected_data = SELFTEST_PLAINTEXT
        │
        ▼
  Wait for done == 1
        │
        ▼
  Compare ciphertext vs SELFTEST_CIPHERTEXT
        │
    ┌───┴───┐
    │       │
  Match   Mismatch
    │       │
    ▼       ▼
  selftest_done=1    selftest_done=1
  selftest_fail=0    selftest_fail=1
  Pulse selftest_clear   Engine BLOCKED
  (resets FSM to IDLE)   (effective_start
                          permanently gated)
```

#### Hardcoded Test Vectors (FIPS 197, Appendix C.1)

```verilog
localparam [127:0] SELFTEST_KEY        = 128'h00010203_04050607_08090A0B_0C0D0E0F;
localparam [127:0] SELFTEST_PLAINTEXT  = 128'h00112233_44556677_8899AABB_CCDDEEFF;
localparam [127:0] SELFTEST_CIPHERTEXT = 128'h69C4E0D8_6A7B0430_D8CDB780_70B4C55A;
```

#### Input Muxing

During self-test, the engines receive test vectors instead of memory data:

```verilog
wire [127:0] selected_key  = selftest_active ? SELFTEST_KEY       : original_key;
wire [127:0] selected_data = selftest_active ? SELFTEST_PLAINTEXT : encryption_engine_data;
```

#### Start Gating (effective_start)

Normal software starts are blocked until the self-test passes:

```verilog
wire effective_start;
assign effective_start = selftest_active ? selftest_start
                                         : (selftest_done && !selftest_fail && start);
```

If `selftest_fail == 1`, `effective_start` is permanently 0 — the engine cannot be used until a hard reset.

#### Post-Self-Test FSM Cleanup

After the self-test encryption completes, the FSM is in the sticky DONE state. A one-cycle `selftest_clear` pulse resets the control unit to IDLE so it is ready for normal software-initiated encryptions:

```verilog
.reset_s(reset_s | selftest_clear),   // control unit's soft-reset input
```

#### Control Unit Changes for Consecutive Encryptions

The DONE state was modified to support re-starting without a soft reset, which is needed for both the self-test flow and normal consecutive encryption (e.g., key-reuse, double-buffering):

**Rising-edge detection on start:** A `start_d` register tracks the previous value of `start`. The DONE-to-RUN transition only fires on a *rising edge* (`start && !start_d`), preventing a feedback loop where a level-high `start` from auto-start would cause infinite re-encryption.

**Pulse-mode key_engine_start:** Changed from level (high during all of RUN) to a one-clock pulse (high only on the IDLE-to-RUN or DONE-to-RUN transition). This prevents the key engine from spuriously restarting its key schedule when the FSM transitions to DONE.

### How It Was Tested

**AES_peripheral_tb.v** includes:

| Test | What It Verifies |
|------|-----------------|
| Boot self-test pass | `wait_for_selftest_pass` polls status register bit [2] until `selftest_done==1, selftest_fail==0` |
| Self-test status sticky | After soft reset, status bits [3:2] remain `2'b01` (done=1, fail=0) |
| TEST 1: Manual start after self-test | First user encryption produces correct FIPS-197 ciphertext |
| TEST 2: Auto-start | Auto-start via address 0x09 write works correctly |
| TEST 3: Key reuse | Two consecutive encryptions (no reset between) produce correct results |
| TEST 4: Double-buffering | Overlapped writes during encryption produce correct results |
| TEST 7: Soft reset | Key cleared, control reg cleared, self-test status persists |

The `wait_for_done` task was updated to handle sticky done — it first waits for `done` to go low (confirming a new encryption started), then waits for it to go high (confirming completion). This correctly handles the DONE-to-RUN-to-DONE sequence in consecutive encryption scenarios.

---

## 11. Vulnerabilities Not Addressed

### Rank 3 — Unmasked S-Boxes (DPA in 500-800 Traces)

**What it is:** Every S-box computation directly processes key-dependent data without masking. This makes the design vulnerable to Differential Power Analysis.

**Why not fixed:** The fix requires first-order Boolean masking — XORing a random mask into S-box inputs and correcting outputs. This roughly doubles S-box area and requires a random number generator. The resulting area increase would exceed our constrained die budget.

### Rank 4 — Two-Phase SubBytes Creates Asymmetric Fault Window

**What it is:** The design processes 16-byte SubBytes in two phases (upper 8 bytes, then lower 8 bytes). A precisely-timed single-cycle fault between phases can corrupt exactly 8 bytes while leaving the other 8 untouched — mathematically ideal for DFA key recovery.

**Why not fixed:** Exploiting this requires intimate knowledge of the hardware design's internal timing, plus precision fault injection equipment. The fix (16 parallel S-boxes or inter-phase integrity checks) would significantly increase area. The risk-to-cost ratio does not justify the change.

---

## 12. Test Summary

All five testbench suites pass after the security fixes:

| Testbench | Module | Assertions | Result |
|-----------|--------|-----------|--------|
| TB 1: AES_peripheral_tb | Top-level integration | 11 | **ALL PASS** |
| TB 2: AES_control_unit_tb | Control unit (FSM, fault, stall) | 23 | **ALL PASS** |
| TB 3: AES_encryption_engine_tb | Encryption engine | 1 (FIPS vector) | **PASS** |
| TB 4: AES_key_engine_tb | Key engine | 10 test cases | **ALL PASS** |
| TB 5: AES_memory_tb | Memory interface | 63 | **ALL PASS** |

---

## 13. PPA Impact

Measured via OpenLane synthesis targeting Skywater sky130:

| Metric | DP2 Final | DP3 (with all fixes) | Delta |
|--------|-----------|---------------------|-------|
| Cell Area | ~82k um^2 | ~84k um^2 | +2.4% |
| Utilization | 56% | 56.46% | +0.46% |
| WNS/TNS | 0 | 0 | No change |
| Setup Slack | — | 4.55 ns | — |
| DRC Violations | 0 | 1 | +1 |

The security hardening adds approximately 2.4% cell area, primarily from the shadow counter, one-hot FSM encoding, LFSR, fault detection logic, and self-test controller.

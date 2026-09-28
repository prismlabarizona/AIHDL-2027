# AES-128 Hardware Encryption Peripheral for TinyQV RISC-V

Team NeCRL (SFSU) -- AI-HDL 2026

An AES-128 hardware encryption engine integrated as a memory-mapped peripheral onto the [TinyQV](https://github.com/MichaelBell/tinyQV) RISC-V processor, targeting the Tiny Tapeout shuttle on the SkyWater SKY130 130nm CMOS process.

## Overview

- **Technology:** SkyWater SKY130 (`sky130_fd_sc_hd` standard cell library)
- **Die Size:** 682.64 x 225.76 um (4x2 Tiny Tapeout tile)
- **Clock:** 57.1 MHz (17.5 ns signoff period)
- **Encryption Latency:** 31 clock cycles per 128-bit block
- **Standard Cells:** 11,725
- **Core Utilization:** 66.3%
- **Total Power:** 5.68 mW
- **Signoff:** DRC clean, LVS clean, STA clean across all 9 PVT corners

## Architecture

```
  ┌──────────────────────────────────────────────────────────┐
  │                 AES-128 Peripheral                       │
  │                                                          │
  │  ┌──────────┐  plaintext [128]  ┌────────────────────┐  │
  │  │          │──────────────────>│                    │  │
  │  │          │  original_key[128]│  Encryption Engine │  │
  │  │  Memory  │──────────────────>│                    │  │
  │  │          │                   │  SubBytes          │  │
  │  │  (Key +  │  ciphertext [128] │  ShiftRows         │  │
  │  │   Data   │<──────────────────│  MixColumns        │  │
  │  │  Banks)  │                   │  AddRoundKey       │  │
  │  └────┬─────┘                   └──────┬─────────────┘  │
  │       │ start/done                     │ round_key[128] │
  │  ┌────v─────┐  core_reset       ┌─────v──────────┐     │
  │  │ Control  │──────────────────>│   Key Engine   │     │
  │  │   Unit   │                   │  (10-round     │     │
  │  │  (FSM)   │<──────────────────│   expansion)   │     │
  │  └──────────┘                   └────────────────┘     │
  └──────────────────────────────────────────────────────────┘
```

The peripheral is memory-mapped onto TinyQV's bus. Software writes the 128-bit plaintext and key via 32-bit store instructions, triggers encryption, and reads back the ciphertext. The design uses an iterative architecture with 10 S-box instances (8 encryption + 2 key engine) processing in two phases per round.

## Key Design Decisions

- **Galois Field S-box:** Composite field arithmetic instead of lookup tables, reducing die area by ~47%
- **Operand isolation:** AND-gate masking at S-box inputs to suppress spurious switching power
- **2-phase SubBytes:** Halved S-box count by processing 128-bit state in two phases per round
- **Pipelined round:** Register stage between ShiftRows and MixColumns to close timing at the slow corner
- **Aggressive synthesis constraint:** 9 ns PnR clock with 17.5 ns signoff to force large drive cells
- **`keep_hierarchy` on MixColumns:** Prevents cross-module gate sharing that caused slew/cap violations

## Security Features

- Write-only key registers (bus reads return zero)
- One-hot FSM with shadow counter and terminal FAULT state
- LFSR-driven random stall cycles (DPA countermeasure)
- Soft-reset interlock (gated on engine-idle)
- Fault visibility in status register
- FIPS-197 power-on self-test

## Register Map

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| `0x00` | Control | R/W | bit 0: start, bit 1: soft reset, bit 2: key_lock, bit 3: auto_start |
| `0x01` | Status | R | bit 0: done, bit 1: fault, bit 2: selftest_done, bit 3: selftest_fail |
| `0x02-0x05` | Key | W-only | 128-bit AES key (4 x 32-bit words) |
| `0x06-0x09` | Plaintext | R/W | 128-bit plaintext input (double-buffered) |
| `0x0A-0x0D` | Ciphertext | R | 128-bit encryption result |

## Project Structure

```
AES128/                    RTL source files
  AES_encryption_engine.v  Encryption datapath (SubBytes/ShiftRows/MixColumns/AddRoundKey)
  AES_control_unit.v       FSM, shadow counter, LFSR stall, fault detection
  AES_key_engine.v         On-the-fly key expansion
  AES_memory.v             Memory-mapped register interface
  mix_columns.v            MixColumns module (keep_hierarchy)
  sbox_lookup.v            Galois Field S-box
peripheral.v               Top-level peripheral wrapper + self-test controller
config.json                OpenLane configuration
base.sdc                   Synthesis/PnR SDC (reads CLOCK_PERIOD env)
pnr_signoff.sdc            Signoff SDC (hardcoded 17.5 ns)
run_tb.py                  Testbench runner (5 suites, FIPS-197 vectors)
DP4_submission/            Final submission deliverables
  gds/                     GDSII (Magic + KLayout)
  netlist/                 Gate-level netlists
  constraints/             SDC files
  signoff/                 DRC, LVS, 9-corner STA reports
  metrics/                 Area, power, timing metrics
  final_report.md          Design Phase 4 report
```

## Tools

- **OpenLane 2.3.10** (RTL-to-GDSII)
- **Yosys** (synthesis)
- **OpenROAD** (floorplanning, placement, CTS, routing, STA)
- **Magic** (DRC, SPICE extraction)
- **KLayout** (secondary DRC)
- **Netgen** (LVS)

## Running Testbenches

```bash
python3 run_tb.py
```

Requires Icarus Verilog (`iverilog`).

## Team

Parsa Mirfasihi, Waylon Woo, Ethan Weldon

San Francisco State University

### Design Comparison: Phase 1 vs. Phase 2

| Metric | Phase 1 (Baseline) | Phase 2 (Optimized) | Diff (%) | Optimization Method | Trade-off |
|:---|:---:|:---:|:---:|:---|:---|
| **Clock Period** | 20.0 ns | 14.0 ns | -30.0% | Tightening timing constraints | Increased design pressure |
| **Frequency** | 50.0 MHz | 71.4 MHz | +42.8% | Frequency scaling | More sensitive to PVT variations |
| **Core Area** | 37,488.45 um^2 | 33,344.48 um^2 | -11.0% | Logic synthesis optimization | Potential routing density increase |
| **Cell Count** | 4,013 Cells | 3,650 Cells | -9.0% | Gate-level restructuring | Reduced logic redundancy |
| **Utilization** | 11.72% | 12.22% | +4.3% | Floorplan area reduction | Reduced whitespace for ECO |
| **Worst Neg Slack**| 0.000 ns | 0.000 ns | 0% | Timing met (Sign-off) | N/A |

Key Architectural Changes for PPA Replaced Variable Comparators with Zero-Checks:

The Issue: The original code compared div_cnt against clk_div using a < operator. It also compared bit_cnt == 4'h1 at the end of the shift. Evaluating variables against other variables or non-zero constants costs more logic gates.

The Fix: div_cnt now pre-loads clk_div and counts down to zero. Checking if a 6-bit register is non-zero (div_cnt != 0) synthesizes to a single 6-input NOR gate. We applied the exact same strategy to bit_cnt.

Eliminated an Adder in the Datapath:

The Issue: Loading the bit counter originally required a 4-bit addition: bit_cnt <= {1'b0, cfg_wlen} + 4'h1;.

The Fix: By switching to a down-counter that stops at 0, we can load cfg_wlen directly into a 3-bit register without any arithmetic overhead.

Register Disentanglement:

The Issue: busy was a combinatorial wire evaluated as (bit_cnt != 4'h0). While this saves one Flip-Flop, it puts a 4-input OR gate in the critical path for cs_n and several state transitions.

The Fix: Replaced it with an explicit busy Flip-Flop. Because bit_cnt was reduced from 4 bits to 3 bits, the overall register count remains perfectly neutral, but the maximum operating frequency (Fmax) improves by flattening the logic cone.

Config Register Protection:

Conditioned the config register writes on !busy (e.g., 4'h2: if (!busy) clk_div <= data_in[5:0];). This ensures the CPU cannot accidentally corrupt a transaction mid-flight by changing the clock divider or CPOL/CPHA settings while the FSM is active.

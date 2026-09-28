# Design Methodology

## 1. Architectural Strategy
Our team adopted a highly optimized, modular design strategy for the **tqvp_spi_master** peripheral (Index 16). We decomposed the architecture into distinct functional blocks to ensure scalability, Full-Duplex capability, and minimal area:
- **CPU Interface**: Register-mapped (DATA, STATUS, DIVIDER, CONFIG) to provide seamless TinyQV bus compatibility.
- **FSM & Control Logic**: Manages SPI Modes 0-3 (CPOL/CPHA), automated `CS_n` timing, and configurable word lengths (4 to 8 bits).
- **Clock Generation**: Utilizes a highly optimized 6-bit down-counter for programmable SPI clock scaling, reducing flip-flop utilization compared to standard 8-bit counters.
- **Datapath**: Features independent TX and RX shift registers to support concurrent Full-Duplex data transmission, with hardware-level LSB/MSB-first reversal.

## 2. Implementation Flow & Physical Metrics
The design was synthesized, placed, and routed using the **OpenLane ASIC automated flow** targeting the **SkyWater 130nm** (sky130_fd_sc_hd) process node. The final physical implementation achieved the following results:

| Metric | Value | Source |
|:---|:---|:---|
| **Total Cell Count** | **3650 Cells** | OpenLane Synthesis Summary |
| **Core Area** | **33,344.48 µm²** | Final Floorplan Report |
| **Core Utilization** | **12.2251%** | Placement Summary |
| **Clock Period** | **14.0 ns (~71.4 MHz)** | SDC Timing Constraints |
| **Worst Negative Slack** | **0.000 ns** | STA Sign-off Report |

## 3. Key Design Decisions
- **Routability over Density**: We deliberately maintained a strategic core utilization of **12.2251%** to prevent routing congestion and DRC violations within the 3650-cell system wrapper.
- **PPA Optimization**: Replaced standard variable comparators with zero-check down-counters, and flattened the combinatorial logic cone for the `BUSY` flag to maximize the maximum frequency ($F_{max}$).
- **Timing Closure Verification**: We performed rigorous post-layout timing verification using the **Standard Delay Format (.sdf)** in `cocotb`. This back-annotation ensured the 50MHz target was met under realistic physical delays with a perfectly optimized **WNS of 0.000 ns**.

## 4. Physical Sign-off
Final verification confirmed 100% manufacturing readiness for the Tiny Tapeout submission:
- **DRC (Magic)**: 0 violations.
- **LVS (Netgen)**: 0 mismatches.
- **Antenna Checks**: 0 violations.
# Design Methodology: Secure & Autonomous System Architecture

## 1. Initial Approach & Threat Mitigation Strategy
Our philosophy centered on a **Zero-Trust Hardware Model**. Initially, we recognized that standard SPI peripherals are passive slaves to the CPU. For Phase 3, we evolved this into a **Security-First Autonomous Hub**. By separating the address space into a Standard Operational Zone and a Gated Secure Zone, we established a physical root of trust. This architectural decision was driven by the STRIDE threat model to specifically neutralize "Tampering" and "Privilege Escalation" risks identified in Phase 1.

## 2. AI Integration & Prompt Engineering
We utilized a **"Context-Aware Prompting"** strategy:
- **Architecture Drafting (Gemini)**: We provided the AI with our specific memory map and register definitions before requesting RTL modules, ensuring seamless integration.
- **Physical Optimization (Claude 3.5 Sonnet)**: We fed raw OpenLane `.log` files back into the AI to identify critical logic cones. This allowed us to refactor high-fanout nets in the CRC engine that were originally causing setup-time violations.
- **Methodology**: We utilized **Few-Shot Prompting**, providing the AI with examples of Sky130 standard cell limitations to ensure the generated RTL was synthesis-ready.

## 3. Physical Implementation Results (PPA Analysis)
To guarantee silicon-proven performance, we locked in strict physical constraints. Below is the sign-off data compared against our baseline:

| Metric | Phase 2 Baseline (image_1.png) | Phase 3 Secured Design | Source |
| :--- | :---: | :---: | :--- |
| **Total Cell Count** | 4,013 Cells | **9,435 Cells (+135%)** | OpenLane Summary |
| **Sequential Elements**| 112 DFFs | **312 DFFs** | OpenLane Synthesis |
| **Core Area** | 37,488.45 µm² | **80,146.97 µm² (+140%)**| Floorplan Report |
| **Core Utilization** | 11.72% | **29.9254%** | Placement Summary |
| **Clock Period** | 20.0 ns (50 MHz) | **14.0 ns (71.4 MHz)** | Timing Constraints |
| **Worst Negative Slack**| 0.000 ns | **0.000 ns** | Post-Routing STA |

## 4. Design Evolution & Critical Refactoring
- **Serial LFSR vs. Parallel XOR**: Initial AI-generated CRC logic used a parallel XOR tree, which resulted in a combinational path depth of 16 gates, failing timing. We refactored this into an **On-the-fly Serial LFSR**. This distributed the calculation over the 8-bit/32-bit shift cycle, achieving a pristine 0.000 ns WNS at 71.4 MHz.
- **Mutex-like Priority Gating**: Integrating the autonomous "Sleep-Walker" timer created potential race conditions for the system bus. We evolved the internal FSM to prioritize CPU writes while "pausing" the autonomous polling, ensuring bus stability without software overhead.

## 5. Key Decisions & System-Level Trade-offs
- **The "Security Area Tax"**: We accepted a 140% area increase to house 32-bit comparators and security registers. This was a calculated decision: the hardware-level protection neutralizes threats that software-based solutions cannot catch, and the "Sleep-Walker" mode results in a net SoC energy gain by allowing the CPU to enter power-saving states.

## 6. Verification Strategy (Stress & Hardening)
- **Attacker Simulation**: Using **cocotb**, we deployed asynchronous coroutines to simulate a "Brute-force Key Injection" attack during active SPI transactions. This proved that the hardware lockout was deterministic and non-disruptive.
- **SDF Back-Annotation**: We performed Post-Layout simulations using **Standard Delay Format (.sdf)** files to verify that physical wire delays did not create timing glitches in our security gating.
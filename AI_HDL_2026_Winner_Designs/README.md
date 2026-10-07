# 🏆 AI-HDL 2026 Winning Designs & Silicon Validation

Welcome to the AI-HDL 2026 Hall of Fame! This page highlights the final physical implementation results of the top winning designs from our previous competition. 

These projects prove that an AI-prompted design flow can successfully bridge the gap between abstract concepts and physical silicon, yielding functionally distinct blocks that survive rigorous physical verification.

---

## 🔬 The Fabricated Designs

For the 2026 tapeout, two distinct functional blocks were fabricated using the **SKY130 process at a 1.8 V supply**. These designs reflect different competition divisions and opposing optimization goals, demonstrating the versatility of AI-assisted hardware design:

*   **SPI Controller with CRC-16** *(Undergraduate Division)*: An intermittently active sensing peripheral aggressively optimized for energy efficiency.
*   **AES-128 Accelerator** *(Graduate Division)*: A continuously active cryptographic datapath heavily optimized for security, utilizing balancing countermeasures for a flatter leakage profile.

---
<div align="center">

## 📊 Post-Layout Implementation Results


| ***Metric*** | SPI Controller with CRC-16 <br> *(Lower Division)* <br> ITIMS Boys <br> *Hanoi University of Science and Technology, Vietnam* | AES-128 Accelerator <br> *(Upper Division)* <br> SFSU-NeCRL <br> *San Fransico State University, USA*|
| :--- | :---: | :---: |
| Die footprint | 0.040 mm² | 0.154 mm² |
| Core area | 37,488 µm² | 149,082 µm² |
| Standard cell count | 2,392 | 6,492 |
| Core utilization | 57.23% | 66.30% |
| Maximum clock frequency | 71.43 MHz | 57.10 MHz |
| Worst negative slack | 0.000 ns | +0.2974 ns |
| DRC/LVS violations | 0 | 0 |
| ***Post-layout power estimation at 1.8 V*** | | |
| Internal power | 1.57 µW | 3.79 mW |
| Switching power | 0.72 µW | 1.89 mW |
| Leakage power | 12 nW | 0.10 µW |
| Total active power | **2.29 µW** | **5.68 mW** |

</div>

---

## 💡 Reading the Results: Key Insights


1. **Precision Timing Closure:** The SPI block closed timing at 71.43 MHz with a worst negative slack of exactly 0.000 ns. This means the EDA flow successfully converged on the design constraints with zero margin left—an ideal optimization state. The AES block comfortably closed at 57.10 MHz with a healthy positive slack of 0.2974 ns.
2. **Workload Dictates Power:** You'll notice a massive, three-order-of-magnitude power gap between the two designs (2.29 µW vs 5.68 mW). This is a direct consequence of the workload, not the design quality! The SPI controller idles between sensor polls, whereas the AES block drives a continuous, full-round-based datapath.
3. **Security Trade-offs:** The AES accelerator incorporates deliberate balancing countermeasures added during the Design Phase 3 (Security Evaluation). These countermeasures intentionally trade away power efficiency in exchange for a flatter leakage profile, protecting the chip against side-channel attacks. 
4. **The Power of Prompts:** Read together, these two results support a critical claim: **an RTL-to-GDSII flow driven by AI prompting works.** It successfully produced two functionally distinct blocks that survived physical verification, one optimized for *energy* and one for *security*. This indicates that AI assistance transfers beautifully across completely different design objectives.

---

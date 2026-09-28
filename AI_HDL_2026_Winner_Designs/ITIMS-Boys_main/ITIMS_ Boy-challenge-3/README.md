# 🛡️ ITIMS-Boys: Secure & Autonomous SPI Master for IoT Edge
## AI-HDL Challenge 2026 [Phase 3 Submission]

## Team Information
- **Team Name**: ITIMS-Boys
- **Institution**: Hanoi University of Science and Technology (HUST) - ITIMS
- **Division**: Lower division
- **Team Members**: 
  - **Do Tien Dung** - Verification Engineer - Dung.DT2419499@sis.hust.edu.vn
  - **Nguyen Ngoc Hai** - Documentation Lead - hai.nn2419514@sis.hust.edu.vn
  - **Pham Viet Trung Kien** - Results Lead - kien.pvt2419567@sis.hust.edu.vn
  - **Cao Hoang Long** - RTL Designer - long.ch2419579@sis.hust.edu.vn
  - **Ta Ngoc Minh Quang** - AI & Media Specialist - quang.tnm2419611@sis.hust.edu.vn
- **Mentor**: Nguyen Tri Dung & Sudipta Paria

## Challenge Summary
For Phase 3 (Security Evaluation), we transitioned our high-performance SPI Master (Index: 16) into a **Hardened Autonomous Peripheral**. Designed for secure Edge Computing, this IP offloads continuous sensor polling from the TinyQV CPU while mathematically guaranteeing data integrity via hardware-level CRC and neutralizing privilege escalation threats through a 32-bit Tamper-Evident Lockout mechanism.

## Key Features
- **🛡️ Hardware Tamper-Evident Lock**: A gated 32-bit lock (`32'hCAFEBABE`) isolates the Secure Configuration Zone. Unauthorized access instantly triggers a permanent hardware trap, preventing malicious firmware from altering threshold parameters.
- **🤖 Autonomous Sleep-Walker FSM**: Implements an independent hardware-polling loop with 16-bit interval timers. This allows the main CPU to remain in a deep sleep state (saving SoC power) until the peripheral detects a data anomaly via threshold comparison.
- **⚡ Serial LFSR CRC-16-CCITT**: Integrated data integrity verification (Polynomial: $x^{16} + x^{12} + x^5 + 1$) executed on-the-fly. By avoiding deep combinational XOR trees, we achieved high-frequency timing closure at 71.4 MHz.
- **📡 Unified 32-bit Secure Datapath**: Supports multi-byte burst transfers with deterministic LSB/MSB-first bit reversal, optimized for modern high-resolution sensor interfaces.

## AI Tools Used
- **Primary LLM**: Gemini 1.5 Pro (Architecture blueprinting, FSM state mapping, and cocotb coroutine generation).
- **Additional tools**: Claude 3.5 Sonnet (Gate-level optimization & PPA analysis), ChatGPT-4o (STRIDE/DREAD threat modeling).
- **Total AI interactions**: ~150 recorded sessions across all design phases.

## Results Summary
- **Functionality**: **PASS**. 100% success rate in legacy SPI regressions and DP3 Security Attacker simulation (brute-force key injection).
- **ASIC Implementation**: **SUCCESS**. Clean GDSII generated via OpenLane (Sky130 PDK).
- **Resource Usage**: 9,435 Cells, 80,146.97 µm² Core Area, 29.92% Utilization.
- **Timing**: **71.4 MHz Achieved** (14.0 ns period) with a pristine **0.000 ns WNS**.

## Innovation Highlights
Our **"Security-as-a-Service"** hardware layer uniquely addresses the latency-security trade-off. By embedding a Serial LFSR instead of a parallel XOR tree, we removed the timing bottlenecks that usually plague security logic. This ensures that every bit sampled from the MISO line is verified before it even touches the internal system bus.

## Team Reflection
This project reshaped our understanding of the "Area-Security-Tax." We learned that robust hardware security requires a calculated investment in silicon real estate. While our area increased by ~140% compared to the baseline (image_1.png), the resulting mitigation of Critical DREAD risks (9.2/10) provides a significantly more resilient SoC architecture for real-world deployments.
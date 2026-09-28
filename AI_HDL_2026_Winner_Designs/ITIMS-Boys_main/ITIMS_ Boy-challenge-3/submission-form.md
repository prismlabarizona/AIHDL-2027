# AI-HDL Challenge [3] Submission Form

## Basic Information
- **Submission Date**: 2026-03-25
- **Challenge Number**: 3
- **Team Name**: ITIMS-Boys
- **Team ID**: 

## Team Members
| Name | Role | Email | Contribution % |
|------|------|-------|----------------|
| Do Tien Dung | Verification | Dung.DT2419499@sis.hust.edu.vn | 20% |
| Nguyen Ngoc Hai | Documentation | hai.nn2419514@sis.hust.edu.vn | 20% |
| Pham Viet Trung Kien | Results Lead | kien.pvt2419567@sis.hust.edu.vn | 20% |
| Cao Hoang Long | RTL Designer | long.ch2419579@sis.hust.edu.vn | 20% |
| Ta Ngoc Minh Quang | AI Specialist | quang.tnm2419611@sis.hust.edu.vn | 20% |

## Design Specifications Met
- [x] All required functionality implemented (SPI Modes 0-3, CRC-16, Sleep-Walker)
- [x] ASIC/OpenLane implementation successful (Sky130 PDK Sign-off)
- [x] Timing requirements met (WNS 0.000 ns at 71.4 MHz)
- [x] Resource constraints satisfied (Clean DRC/LVS/Antenna)
- [x] All test cases pass (Functional + Security Stress Tests)

## AI Tool Usage Declaration
- **Primary AI Tool**: Gemini 1.5 Pro
- **Total Conversation Sessions**: ~45 formal sessions.
- **Estimated AI-Generated Code %**: 30% - 35%
- **Manual Modifications Made**: Yes. We completely re-architected the AI's initial parallel CRC tree into a Serial LFSR engine to resolve timing violations and hand-coded all FSM priority gating to prevent bus deadlocks.

## Special Considerations
- **Bonus Features Implemented**: Autonomous Sleep-Walker FSM for intelligent sensor polling and significant power reduction at the SoC level.
- **Known Issues**: None. The 140% area increase was a strategic trade-off for silicon-level security hardening.
- **Future Improvements**: Integration of a hardware-level AES-128 cryptographic challenge-response for the configuration lockout.

## Verification Checklist
- [x] All source files compile without errors
- [x] Testbenches run successfully (cocotb environment)
- [x] ASIC/OpenLane implementation verified (GDSII generated)
- [x] AI interaction logs are complete (stored in `ai_logs/`)
- [x] Documentation is thorough and clear

## Team Statement
We certify that this submission represents our original work, completed according to AI-HDL rules and academic integrity guidelines. All AI interactions have been logged and submitted.

**Team Representative**: Nguyen Ngoc Hai
**Date**: 2026-03-25
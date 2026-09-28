# AI Strategy and Usage

## Tool Selection & Ecosystem
We utilized a multi-model ecosystem to leverage specific strengths:
- **Gemini 1.5 Pro**: Primary architect for Verilog skeletons and complex Python `cocotb` testbenches. Its 1M+ context window allowed it to "remember" our entire 32-bit datapath across multiple files.
- **Claude 3.5 Sonnet**: Our **Physical Design Consultant**. Its superior logic reasoning helped us refactor the CRC engine from a parallel to a serial architecture to close timing.
- **ChatGPT-4o**: Specialized in structuring threat models (STRIDE/DREAD) and academic-grade documentation.

## Prompting Techniques
- **Persona-Driven Constraints**: *"Act as a Senior ASIC Architect specializing in Sky130 PDK. Analyze this critical timing path and refactor to eliminate combinational depth."*
- **Iterative Debugging**: When OpenLane reported TritonRoute congestion, we injected the routing density maps into the AI to brainstorm floorplan adjustments, settling on a 29.92% target utilization.

## Iteration Process
Human-Driven, AI-Accelerated cycle:
1. AI drafts structural boilerplate based on our constraints.
2. Immediate physical check via OpenLane flows.
3. Timing/Congestion logs fed back to AI for refactoring.
4. Human designer hand-codes all critical security gating and non-blocking assignments (`<=`).

## AI Limitations Encountered
- **Sequential Bias**: AI models frequently attempted to use software-like blocking assignments (`=`) in clocked blocks. Our human designers had to manually refactor these to ensure correct flip-flop inference.
- **Routing Blindness**: AI cannot "see" density. It suggested area-heavy 32-bit parallel comparators that caused routing failure, forcing us to pivot to a more serial architecture.

## Learning from AI
AI accelerated của mastery of **Asynchronous Verification**. However, the project reinforced that **PPA Optimization** remains a human architectural discipline. AI showed us the syntax, but ITIMS-Boys designed the silicon.
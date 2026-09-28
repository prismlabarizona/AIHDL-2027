# AI Strategy and Usage

## Tool Selection
We employed a multi-model approach to leverage the unique strengths of various LLMs for our Transmit-Only SPI Master design:
* **ChatGPT-4o (Primary)**: Utilized for generating initial RTL skeletons, FSM logic, and comprehensive cocotb testbench templates.
* **Claude 3.5 Sonnet (Secondary)**: Acted as our "Lead Code Reviewer" for debugging Verilog logic and optimizing synthesis-friendly constructs due to its strong logical consistency.
* **Gemini 1.5 Pro (Research & Documentation)**: Leveraged for technical research, analyzing OpenLane synthesis logs, and structuring our project documentation.

## Prompting Techniques
To maximize the quality of the AI output, we utilized several specific prompting strategies:
* **Role-Based Prompting**: Assigned specific personas, such as "Acting as a hardware verification expert," to ensure high-quality, edge-case-focused testbench generation.
* **Contextual Grounding (Chain-of-Thought)**: Before requesting code, we provided the AI with the `tt_wrapper.v` environment and internal SPI implementation guidelines, instructing it to "read and study the contents" to establish a solid baseline.
* **Modular Prompting**: Instead of requesting a monolithic design, we broke requests into sequential steps:
    1. Generating the initial Transmit-Only SPI Master FSM skeleton.
    2. Adding the 7-bit clock divider logic.
    3. Generating integration mapping for the Tiny Tapeout slot 16.

## Iteration Process
Our transition from high-level specifications to a verified peripheral relied heavily on a structured iteration loop:
* **Initial Generation**: AI generated approximately 75% of the raw Verilog and Python (cocotb) code.
* **The "Human Loop"**: 100% of the AI-generated code was manually reviewed and iteratively refined. We systematically tested the AI's output against our simulation environment.
* **Targeted Refinement**: When the AI produced inefficient logic (e.g., in FSM state transitions or register mapping for DATA, STATUS, and DIVIDER), we provided the error logs or simulation waveforms back to the AI with specific constraints to force corrections.

## AI Limitations Encountered
During the development process, we encountered and overcame several AI limitations:
* **Toolchain Hallucinations**: AI frequently suggested using SystemVerilog constructs (like `always_comb` or `interfaces`) which are not fully supported by the OpenLane/Yosys synthesis flow we utilized. We had to strictly prompt the AI to output "Verilog-2001 compatible code."
* **ASIC vs. FPGA Constraints**: The AI struggled to understand the specific I/O constraints of the Tiny Tapeout ASIC flow. It attempted to generate standard FPGA `.xdc` files. We overcame this by manually configuring the `info.yaml` and directly mapping ports in the `tt_wrapper.v` module.
* **Clock Domain Crossing (CDC)**: The AI was unreliable when handling CDC logic. It often failed to explicitly synchronize external asynchronous input signals (like user buttons) to the system clock domain, requiring manual intervention to implement proper 2-stage flip-flop synchronizers to prevent metastability.

## Learning from AI
Working alongside AI tools provided several key insights into hardware design:
* **Importance of Explicit Specifications**: AI excels at boilerplate generation but requires incredibly precise constraints. Vague prompts lead to generic designs that fail synthesis.
* **Toolchain Nuances**: Debugging AI hallucinations reinforced our understanding of the strict differences between HDL standards (Verilog vs. SystemVerilog) and what specific synthesis tools (like Yosys) can actually compile.
* **Verification over Generation**: We learned that generating code is the easy part; the real challenge is architecting a robust verification environment. AI is highly effective at writing test vectors if the human engineer properly defines the edge cases and timing requirements first.
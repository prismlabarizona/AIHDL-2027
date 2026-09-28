# AI Integration Strategy

## 1. Tool Selection
We employed a multi-model approach to leverage the unique strengths of various LLMs:
- **Gemini Pro (Primary)**: Utilized for generating initial RTL skeletons, FSM logic, and resolving testbench API compatibility.
- **Claude 3.5 Sonnet (Secondary)**: Acted as our "Lead Code Reviewer" for debugging Verilog logic, expanding to Full-Duplex, and optimizing synthesis-friendly constructs (PPA).
- **Gemini 1.5 Pro (Research & Documentation)**: Leveraged for technical research, analyzing OpenLane logs, and summarizing hardware specifications.

## 2. Implementation Workflow
Our team adopted a structured AI-driven workflow to transition from high-level specifications to a fully verified hardware peripheral:
- **RTL Generation**: Transformed the SPI Master specification into synthesizable Verilog, specifically focusing on the FSM, Full-Duplex logic, and register mapping (DATA, STATUS, DIVIDER, CONFIG).
- **Verification Architecture**: Architected a robust cocotb testbench. We explicitly requested multiple test cases to cover clock divider scaling, protocol timing, and back-to-back transmissions.
- **Integration Support**: Generated the necessary modifications for `Makefile` and `tt_wrapper.v` to ensure the peripheral was correctly indexed at slot 16.

## 3. Prompt Engineering Techniques
- **Role-Based Prompting**: Assigned specific personas such as "Acting as a verification expert" to ensure high-quality testbench generation.
- **Chain-of-Thought Integration**: Provided the AI with the Verilog wrapper and internal SPI implementation files first, asking it to "read and study the contents" before coding.
- **Iterative Refinement**: Instead of asking for the full code at once, we broke requests down into modular prompts:
    1. Initial SPI Master skeleton.
    2. Expanding to Full-Duplex and adding a 7-bit clock divider.
    3. Optimizing logic for Area and generating integration steps for the Tiny Tapeout harness.

## 4. Integration & Validation
- **Code Generation**: AI generated approximately **75%** of the raw code.
- **Human Loop**: 100% of the AI code was manually reviewed. We specifically had to intervene in testbench API compatibility and timing precision where AI tended to be less reliable.
- **Log Management**: All interactions were exported and stored in the `ai_logs/` directory to ensure transparency.

## 5. AI Limitations Encountered
- **Hallucination**: AI occasionally suggested using SystemVerilog features that are not supported by the specific OpenLane/Yosys synthesis tool version.
- **Physical Constraints**: AI struggled to map physical constraints accurately for the specific ASIC board, attempting to use FPGA constraints (XDC). This required manual configuration of the `info.yaml` and direct port mapping.
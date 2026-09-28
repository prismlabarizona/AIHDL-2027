# Lessons Learned

## 1. Technical Insights: Physical Design & Timing
- **Utilization vs. Routability**: We learned that a lower utilization (**11.7249%**) is not wasteful but essential for complex systems like ours (4,013 cells). "Packing" logic too tightly often leads to unresolvable routing congestion and timing violations.
- **Post-Layout Reality Check**: Functional verification (RTL simulation) is not enough. Our experience with the **Standard Delay Format (.sdf)** proved that physical wire delays can significantly impact high-speed protocols. Validating with `.sdf` ensures the design works on actual silicon, not just in theory.

## 2. AI Collaboration Strategy
- **Prompt Engineering**: The quality of AI output is directly proportional to the specificity of the input. We treated AI as a "junior engineer"—great for boilerplate Verilog (like the initial FSM) but requiring strict supervision for critical timing paths.
- **Verification Assistant**: AI proved invaluable in analyzing verbose logs (OpenLane reports) and generating complex `cocotb` testbench assertions that would have taken hours to write manually.

## 3. Team & Workflow Management
- **Git Discipline is Crucial**: We learned the hard way that "force pushing" or ignoring conflicts leads to chaos. Adopting a strict `git pull --rebase` workflow saved the team from "detached head" states and lost work.
- **Role Specialization**: Assigning dedicated roles (Documentation, Physical Design, Verification) allowed us to parallelize work. While Kien focused on closing timing (WNS 0ns), Hai could simultaneously document the architectural decisions, significantly speeding up the submission process.

## 4. Future Improvements
- **Automated CI/CD**: For the next challenge, we plan to implement GitHub Actions to automatically run the `cocotb` testbench and OpenLane flow on every push, ensuring immediate feedback on integration errors.
- **Hardware-Software Co-Design**: We realized that defining the Register Map (0x00, 0x01, 0x02) early is critical. Future projects will start with a frozen address specification to avoid integration headaches later.
# Challenges Faced and Solutions

## 1. FSM Timing and CS_n De-assertion
- **Challenge**: Initial simulations showed the `BUSY` flag clearing too early, causing the `CS_n` signal to return High before the 8th bit was fully sampled.
- **Solution**: We refined the FSM by adding a dedicated wait state, ensuring `BUSY` remains active until the final falling edge of SCK.

## 2. Clock Divider Stability
- **Challenge**: Potential glitches in `SCLK` generation if the `DIVIDER` register (Address 2) was updated mid-transmission.
- **Solution**: We implemented a logic gate to prevent register updates while the `BUSY` flag is High, ensuring frequency stability.

## 3. Scaling to Full System Integration (3650 Cells)
- **Challenge**: Integrating the module into a full system of **3650 cells** while maintaining a compact physical footprint.
- **Solution**: We optimized the placement to achieve a core area of **33,344.48 µm²** with **12.2251% utilization**, providing a clean routing environment.

## 4. Verification of 50MHz Timing (WNS = 0)
- **Challenge**: Functional simulations did not account for physical delays in the 130nm process.
- **Solution**: We utilized the **Standard Delay Format (.sdf)** for back-annotation in cocotb, confirming a **Worst Negative Slack (WNS) of 0.000 ns**.

## 5. Version Control Conflicts
- **Challenge**: Team faced `non-fast-forward` errors during collaborative documentation updates.
- **Solution**: Adopted a strict Git workflow, using `git pull --rebase` to integrate remote changes smoothly.
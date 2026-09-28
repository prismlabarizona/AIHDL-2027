# Challenges Faced and Solutions

## 1. FSM Timing and CS_n De-assertion
- **Challenge**: Initial Verilator simulations showed the internal `BUSY` flag clearing too early, causing the `CS_n` (Chip Select) signal to return High before the 8th bit was fully sampled by the peripheral.
- **Solution**: We refined the AI-generated FSM by manually adding a dedicated `WAIT` state. This ensured the `BUSY` signal remains active until the final falling edge of `SCK` is completely registered, maintaining strict adherence to the SPI protocol.

## 2. Clock Divider Stability
- **Challenge**: We identified potential metastability and glitches in `SCLK` generation if the CPU updated the `DIVIDER` register (Address 2) mid-transmission.
- **Solution**: We implemented a hardware lockout mechanism (logic gate wrapper) to prevent memory-mapped register updates while the `BUSY` flag is High, ensuring frequency stability during active transactions.

## 3. Scaling to Full System Integration (4,013 Cells)
- **Challenge**: Integrating the `tqvp_spi_master` into the full `tt_um_tqv_peripheral_harness` system of **4,013 cells** while maintaining a compact physical footprint without causing routing congestion in OpenLane.
- **Solution**: We strategically optimized the floorplan placement and limited the synthesis strategy to achieve a core area of **37,488.45 µm²** with a strict **11.7249% core utilization**. This sparse density provided the global router enough tracks to achieve zero violations.

## 4. Verification of 50MHz Timing (WNS = 0)
- **Challenge**: Functional RTL simulations did not account for the real-world physical delays inherent in the SkyWater 130nm process, leaving uncertainty about the 50MHz target.
- **Solution**: We utilized the **Standard Delay Format (.sdf)** extracted from the OpenLane flow for back-annotated gate-level simulations, successfully confirming a perfectly optimized **Worst Negative Slack (WNS) of 0.000 ns**.

## 5. Version Control Conflicts
- **Challenge**: During collaborative documentation and constraint updates, the team frequently faced `non-fast-forward` errors and merge conflicts.
- **Solution**: We adopted a strict Git workflow, mandating the use of `git pull --rebase` to integrate remote changes smoothly and maintain a linear, clean commit history.

## 6. Circuit Validity Check (CVC) Resolution
- **Challenge**: The final OpenLane physical sign-off reported a single `cvc_total_errors = 1`, despite passing all Magic DRC and Netgen LVS checks.
- **Solution**: We are currently isolating this specific CVC flag. Because it does not directly impede the fundamental DRC/LVS tape-out requirements, we documented it as a known minor issue for future iterations rather than aggressively modifying the stable routed layout.
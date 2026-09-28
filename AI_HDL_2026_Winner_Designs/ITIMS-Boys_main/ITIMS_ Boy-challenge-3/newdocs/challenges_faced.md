# Challenges Faced and Engineering Solutions

## 1. Timing Closure with CRC-16 Logic
* **Problem**: Parallel XOR tree created deep combinational paths, failing setup-time by -3.2 ns.
* **Solution**: Re-architected into an **On-the-fly Serial LFSR Engine**. This flattened the logic cone, achieving a 0.000 ns WNS.

## 2. OpenLane Physical Congestion
* **Problem**: Logic explosion (9,435 cells) caused 50+ TritonRoute violations.
* **Solution**: Lowered `PL_TARGET_DENSITY` to 29.92% and optimized floorplan whitespace, resulting in a clean sign-off.

## 3. FSM Race Conditions
* **Problem**: Simultaneous CPU and Timer requests caused state machine deadlocks.
* **Solution**: Implemented **Mutex-like Priority Gating**, prioritizing CPU access while pausing the autonomous timer.
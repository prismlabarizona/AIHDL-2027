# 🔧 OpenLane Synthesis & Tapeout Guide
## ITIMS-Boys — TinyQV Peripheral Integration (DP2 → DP4)

This guide walks through integrating your custom `itims_spi` peripheral into the TinyQV core and running the full OpenLane physical design flow.

---

## Prerequisites

- OpenLane installed and Docker running
- TinyQV DP2 design folder at `~/AI-HDL/OpenLane/designs/DP2`
- Your peripheral source files: `itims_spi.v`, `tt_wrapper.v`

---

## Step 1: Copy Peripheral Files into the DP2 Design Folder

Copy your custom peripheral RTL into the TinyQV design directory alongside the existing core files.

```bash
# Navigate to your project root
cd ~/AI-HDL/OpenLane/designs/DP2

# Copy your peripheral source files
cp /path/to/your/itims_spi.v .
cp /path/to/your/tt_wrapper.v .

# Verify the files are present
ls itims_spi.v tt_wrapper.v
```

After this step your design folder should contain all required RTL:

```
DP2/
├── itims_spi.v              ← your peripheral (copied in)
├── tt_wrapper.v             ← your harness wrapper (copied in)
├── tinyqv.v                 ← TinyQV top
├── cpu.v
├── core.v
├── alu.v
├── decode.v
├── register.v
├── latch_reg.v
├── mem_ctrl.v
├── qspi_ctrl.v
├── counter.v                ← your interval timer
├── reclocking.sv
├── rising_edge_detector.sv
├── falling_edge_detector.sv
├── spi_reg.sv
├── synchronizer.sv
├── synth.ys                 ← Yosys synthesis script (Step 2)
└── config.json              ← OpenLane config (Step 3)
```

---

## Step 2: Create the Yosys Synthesis Script (`synth.ys`)

Create `synth.ys` in the DP2 folder. This script is used to verify the design synthesizes cleanly with Yosys **before** running the full OpenLane flow — it catches RTL errors early.

```bash
cat > synth.ys << 'EOF'
read_verilog -sv reclocking.sv
read_verilog -sv rising_edge_detector.sv
read_verilog -sv falling_edge_detector.sv
read_verilog -sv spi_reg.sv
read_verilog -sv synchronizer.sv

read_verilog alu.v
read_verilog core.v
read_verilog counter.v
read_verilog cpu.v
read_verilog decode.v
read_verilog latch_reg.v
read_verilog mem_ctrl.v
read_verilog itims_spi.v
read_verilog qspi_ctrl.v
read_verilog register.v
read_verilog tinyqv.v
read_verilog tt_wrapper.v

synth -top tt_um_tqv_peripheral_harness

stat
clean
EOF
```

### Run the Yosys Pre-check

```bash
# From inside the DP2 folder
yosys synth.ys
```

**Expected output:** `stat` will print cell counts and the hierarchy. Check that:
- No `ERROR` lines appear
- `tt_um_tqv_peripheral_harness` is listed as the top module
- All your submodules (`i_spi_reg`, `i_counter`, etc.) appear in the hierarchy

> ⚠️ Fix any Yosys errors before proceeding to OpenLane. Common issues: undefined macros, missing module ports, or implicit wire width mismatches.

---

## Step 3: Configure `config.json`

Edit `config.json` in the DP2 folder with the following settings. Key changes from the default TinyTapeout template are explained inline.

```json
{
  "DESIGN_NAME": "tt_um_tqv_peripheral_harness",
  "TOP_MODULE":  "tt_um_tqv_peripheral_harness",

  "VERILOG_FILES": [
    "dir::tinyqv.v",
    "dir::tt_wrapper.v",
    "dir::cpu.v",
    "dir::core.v",
    "dir::decode.v",
    "dir::alu.v",
    "dir::register.v",
    "dir::latch_reg.v",
    "dir::mem_ctrl.v",
    "dir::qspi_ctrl.v",
    "dir::itims_spi.v",
    "dir::counter.v",
    "dir::reclocking.sv",
    "dir::rising_edge_detector.sv",
    "dir::falling_edge_detector.sv",
    "dir::spi_reg.sv",
    "dir::synchronizer.sv"
  ],

  "CLOCK_PERIOD": 14.0,
  "CLOCK_PORT":   "clk",
  "CLOCK_NET":    "clk",

  "FP_SIZING":        "absolute",
  "DIE_AREA":         "0 0 200 200",
  "PL_TARGET_DENSITY": 0.72,
  "PL_TARGET_DENSITY_PCT": 70,

  "SYNTH_STRATEGY": "AREA 3",
  "SYNTH_SIZING":   1,

  "MAX_FANOUT_CONSTRAINT":          20,
  "CTS_SINK_CLUSTERING_SIZE":       15,
  "CTS_SINK_CLUSTERING_MAX_DIAMETER": 50,

  "PL_RESIZER_MAX_WIRE_LENGTH":   500,
  "GRT_RESIZER_MAX_WIRE_LENGTH":  500,
  "PL_RESIZER_HOLD_SLACK_MARGIN": 0.1,
  "GRT_RESIZER_HOLD_SLACK_MARGIN": 0.05,

  "RUN_LINTER":             1,
  "LINTER_INCLUDE_PDK_MODELS": 1,

  "RUN_KLAYOUT_XOR":  0,
  "RUN_KLAYOUT_DRC":  0,

  "DESIGN_REPAIR_BUFFER_OUTPUT_PORTS": 0,

  "TOP_MARGIN_MULT":    1,
  "BOTTOM_MARGIN_MULT": 1,
  "LEFT_MARGIN_MULT":   6,
  "RIGHT_MARGIN_MULT":  6,

  "GRT_ALLOW_CONGESTION": 1,
  "GRT_OVERFLOW_ITERS":   50,

  "FP_IO_HLENGTH": 2,
  "FP_IO_VLENGTH": 2,
  "FP_PDN_VPITCH": 38.87,

  "RUN_CTS": 1,

  "FP_PDN_MULTILAYER": 0,
  "RT_MAX_LAYER":      "met4",

  "MAGIC_DEF_LABELS":      0,
  "MAGIC_WRITE_LEF_PINONLY": 1
}
```

### Key Parameters Explained

| Parameter | Value | Why |
|---|---|---|
| `CLOCK_PERIOD` | `14.0` | 14 ns = 71.4 MHz, matches TinyQV requirement |
| `DIE_AREA` | `0 0 200 200` | 200×200 µm — required for power grid stability |
| `PL_TARGET_DENSITY` | `0.72` | Calibrated to avoid GPL-0302 placement failure |
| `SYNTH_STRATEGY` | `AREA 3` | Aggressive area minimization via Yosys |
| `MAX_FANOUT_CONSTRAINT` | `20` | Accommodates CTS leaf buffers (fanout 11–17) |
| `RT_MAX_LAYER` | `met4` | TinyTapeout tiles must not use met5 |
| `FP_PDN_MULTILAYER` | `0` | No power rings — power comes from top-level harness |

---

## Step 4: Run the OpenLane Flow

### Option A: Using the OpenLane Docker wrapper (recommended)

```bash
# From the OpenLane root directory
cd ~/AI-HDL/OpenLane

# Run the full flow on the DP2 design
./flow.tcl -design designs/DP2 -tag RUN_$(date +%Y.%m.%d_%H.%M.%S)
```

### Option B: Using `make`

```bash
cd ~/AI-HDL/OpenLane
make mount

# Inside the Docker container:
./flow.tcl -design designs/DP2
```

### Monitor Progress

The flow runs 41 steps. Key milestones to watch:

```
[STEP 1]  Synthesis        ← Yosys + abc
[STEP 3]  Floorplanning    ← Die area, power grid
[STEP 7]  Global Placement ← GPL; fails here if density too low
[STEP 12] CTS              ← Clock tree insertion
[STEP 19] Global Routing   ← FastRoute
[STEP 23] Detailed Routing ← TritonRoute; DRC check here
[STEP 31] Final STA        ← Timing signoff
[STEP 38] LVS              ← Netlist vs. layout check
[STEP 39] DRC              ← Magic design rule check
```

---

## Step 5: Check the Results

### Quick pass/fail check

```bash
# Check flow status
grep -E "SUCCESS|ERROR|Flow" designs/DP2/runs/*/openlane.log | tail -5

# Check for DRC violations
grep "violations" designs/DP2/runs/*/reports/manufacturability.rpt
```

### Check timing signoff

```bash
# View final STA report
cat designs/DP2/runs/*/reports/signoff/31-rcx_sta.checks.rpt
```

Look for:
- `WNS: 0.000` — no setup violations ✅
- `TNS: 0.000` — no total negative slack ✅
- `max fanout violation count 0` — all fanout constraints met ✅

### Check DRC and LVS

```bash
# DRC
cat designs/DP2/runs/*/reports/signoff/39-drc.rpt | grep "violations"

# LVS
grep "Total errors" designs/DP2/runs/*/logs/signoff/38-lvs.lef.log
```

Both should show `0`.

---

## Step 6: Locate Final Outputs

```bash
# Your deliverables are in:
ls designs/DP2/runs/*/results/final/

# Key files:
#   *.gds      → Final GDSII (submit this)
#   *.lef      → Abstract layout
#   *.v        → Powered Verilog netlist
#   *.spef.gz  → Parasitics (nom corner)
```

---

## Troubleshooting Common Errors

| Error | Cause | Fix |
|---|---|---|
| `GPL-0302 Use a higher -density` | Core area too small for cell count | Raise `PL_TARGET_DENSITY` to `0.75`–`0.77` or increase `DIE_AREA` |
| `SYNTH_MAX_FANOUT is deprecated` | Old key name | Use `MAX_FANOUT_CONSTRAINT` instead |
| `FP_SIZING absolute but no DIE_AREA` | Missing die area spec | Add `"DIE_AREA": "0 0 200 200"` |
| Power grid scaled down warning | Die too small for PDN pitch | Increase `DIE_AREA` or reduce `FP_PDN_VPITCH` |
| Max fanout violations after flow | CTS leaf buffers over limit | Raise `MAX_FANOUT_CONSTRAINT` to `20` |
| LVS mismatch on fill/tap cells | `MAGIC_DEF_LABELS 1` | Ensure `"MAGIC_DEF_LABELS": 0` |

---

## Expected Final Metrics (Reference)

| Metric | Value |
|---|---|
| Flow Status | ✅ Completed |
| Clock Frequency | 71.43 MHz |
| WNS | 0.000 ns |
| DRC Violations | 0 |
| LVS Errors | 0 |
| Logic Cells | ~2,392 |
| Core Area | ~37,488 µm² |
| Placement Utilization | ~57% |

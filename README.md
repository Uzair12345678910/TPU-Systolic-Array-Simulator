# TPU Systolic Array Simulator (Verilog-2005)

A laptop-only, TPU-style **4×4 systolic array** for matrix multiply using signed 8-bit operands and 20-bit accumulators.  
The core exposes a simple streaming interface: `start / in_valid / in_ready / done`.  
Includes a performance testbench and VCD waveforms; runs with **Icarus Verilog**.

---

## Why this is interesting
- **Systolic dataflow:** weight-stationary / edge-skewed streaming of operands.
- **Hardware–software bridge:** exposes timing/throughput metrics you can compare to CPU baselines.
- **No FPGA needed:** everything runs from a laptop (Icarus + GTKWave).

---

## Quick start

### Requirements
- Icarus Verilog (`iverilog`, `vvp`)
- (Optional) GTKWave for viewing `.vcd` waveforms

### Build & run
```bash
# from repo root
iverilog -g2005-sv -s tb_perf_only -o tpu4 tb_perf_only.v tpu_core.v systolic_array.v mac_cell.v
vvp tpu4

## Expected Output
Feed cycles   = 4
Total cycles  = 13–14
Peak MACs/cyc = 16 | Effective MACs/cyc ~ 4.6–4.9

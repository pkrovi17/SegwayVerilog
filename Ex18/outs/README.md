# Exercise 18: Gated clocks

## Summary

The supplied multiply-accumulate circuit captures a 16-by-16-bit unsigned
product when `en` is high and adds that product into a 64-bit accumulator
one clock later. When disabled, its enabled registers hold their state using
recirculating feedback muxes, while the register clocks keep toggling.

`mult_accum_gated.sv` replaces those feedback enables with two gated clocks.
The product clock runs when `en` is active. The accumulator clock runs when
`en_stg2 | clr` is active, so synchronous clear works even without a product
to accumulate. The one-bit enable pipeline remains on the original clock.

Each gate uses a low-level latch to hold its enable stable while the source
clock is high, followed by an AND gate. A plain `clk & en` would permit short
or extra pulses if `en` changed during the high phase. Latch-based gates
prevent that. Like the supplied design, there is no reset; `clr` initializes
the accumulator and has priority over accumulation.

The PDF calls the product register 16 bits in one hint, but the supplied RTL
declares it as 32 bits. A 16-by-16 multiplication requires the full 32-bit
result, so that width is preserved.

Key terms:

- **Clock gating:** suppress clock activity in inactive register banks.
- **Recirculating mux:** feeds a register's previous output back to its input
  when its enable is low.
- **Low-level latch:** follows the enable while the clock is low, then holds
  it during the high phase to keep clock pulses intact.
- **Pipeline enable:** delays validity alongside the product so the next
  stage accumulates the correct previous-cycle result.
- **Dynamic power:** switching-related power, including cell-internal and
  net-switching power. Clock gating can reduce it when stages are inactive.
- **Timing constraints and activity assumptions:** both designs must use
  the same clock, library corner, loads, and input activity for comparison.

## Local verification and current status

`mult_accum_tb.sv` compares both implementations with an arithmetic reference.
All 56 clock-cycle checks passed. Tests cover the full-width product,
pipeline draining, hold, clear while disabled, and enable/clear changes
during the high phase that must neither create nor truncate clock pulses.
`simulation_output.txt` records the actual Icarus Verilog run.

Design Compiler and SAED32 are not installed in this workspace. Synthesis,
the measured area/power table, and timing conclusions remain pending the
CAE runs below. `comparison.md` explicitly marks those values as pending.

## ModelSim

From Ex18:

```tcl
vlog -sv mult_accum.sv mult_accum_gated.sv mult_accum_tb.sv
vsim work.mult_accum_tb
run -all
```

## CAE synthesis

The supplied RTL `mult_accum.sv` is unchanged. The original synthesis script
is saved as `mult_accum_provided.dc` in this directory for reference. The
updated `../mult_accum.dc` runs either implementation with the supplied
constraints: 5 ns clock period, 2.3 ns high phase, 0.75 ns I/O delay,
0.05 pF output load, 0.10 ns maximum transition, NAND2X1_RVT drivers,
and wire-load model 16000. Input activity assumptions are also preserved:
probability 0.5/toggle rate 0.25 generally, overridden to 0.1/0.1 for `en`.

The script uses the tutorial's `.synopsys_dc.setup` for `target_library`,
`link_library`, and library search paths. It derives the library name from
the first target .db filename, so input drivers and the wire-load model
match that configured corner. Keep the same setup/corner for both runs.
The tutorial's RVT / TT / medium-voltage / room-temperature settings match
its `saed32rvt_tt0p85v25c` examples. No `saed_db` override or path search is needed.

In a CAE Linux terminal:

```sh
cd /path/to/Ex18
module load synopsys/suite
module load saed32_edk
synopsys-run
dc_shell
```

For the original design:

```tcl
set gated 0
source mult_accum.dc
quit
```

Start a fresh `dc_shell` in the same container for the gated design:

```tcl
set gated 1
source mult_accum.dc
quit
```

Each run maps, flattens, performs hold fixing, and compiles again. The final
reports and netlist go into separate folders:

```text
reports/original/{area,power,timing_max,timing_min,constraints,check_design}.rpt
reports/gated/{area,power,timing_max,timing_min,constraints,check_design}.rpt
```

The tutorial's `.synopsys_dc.setup` must already be installed in your home
or project directory before starting DC. To inspect the active target, use
`printvar target_library`. The script uses `compile -map_effort medium`,
retains the exercise's `set_fix_hold`, and collects final reports after the
second compile. It does not add the tutorial example's clock uncertainty
or unrelated tri-state load changes.

The uncommented "All measurements..." sentence was fixed to be a comment;
it would otherwise be interpreted as an invalid Tcl command before reporting.

## Complete the comparison and submit

After retrieving both report folders, run from Ex18:

```sh
python outs/summarize_results.py
```

This reads actual final area, total dynamic power, and worst reported setup
and hold slack and writes `outs/comparison.md`. Positive/zero slack passes
the corresponding path check; also inspect `constraints.rpt` for design-rule
and other violations. Power here is a vectorless estimate under the scripted
activity, rather than measured hardware power. Gating adds latch/gate area
while removing feedback muxes; the reports determine the net change in area,
dynamic power, and timing. Do not assume improvement without those results.

Submit `../mult_accum_gated.sv` and the completed comparison table. The README
and simulation testbench are supporting files, not extra required submissions.

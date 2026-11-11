# Exercise 14: fast simulation and balance control

## Summary

This exercise adds a `fast_sim` parameter to PID and combines PID with
SegwayMath in `balance_cntrl`. Both parameters default to `1` for simulation.
Set `balance_cntrl.fast_sim` to `0` for the original hardware math; the wrapper
passes the setting down to its PID instance.

| Operation | `fast_sim = 1` | `fast_sim = 0` |
| --- | --- | --- |
| Integral term | Saturated `integrator[15:1]` | Sign-extended `integrator[17:6]` |
| Timer increment | 256 each clock | 1 each clock |
| Register sizes | 18-bit integrator, 27-bit timer | Same |

The fast integral term divides by 2 instead of 64, increasing its effective
gain by 32. Bits [17:15] are checked before truncating: values outside the
representable range clamp the signed 15-bit I term to -16384 or 16383.
The soft-start ramp runs 256 times faster, reaching its terminal upper byte
after 522,240 clocks instead of 133,693,440 clocks. Overflow holding, valid
gating, rider-off clearing, and the P and D terms retain their behavior.

`balance_cntrl` connects PID's signed 12-bit correction and 8-bit soft-start
timer to SegwayMath. SegwayMath adds steering, shapes torque, saturates the
left/right speed commands, and generates the overspeed warning.

Key concepts:

- **Parameter:** an elaboration-time setting that selects how a module is built.
- **Conditional generate:** selects either fast or normal arithmetic; it is
  not a runtime switch and does not build a selector controlled by an input.
- **Saturation:** clamps a result to its signed range to prevent wraparound
  when upper bits are discarded.
- **Hierarchy and parameter propagation:** a wrapper connects modules and
  passes its parameter to a child instance using `#(.fast_sim(fast_sim))`.
- **Simulation acceleration:** shorten long time constants while preserving
  the main datapath and register structure.

`PID.sv` was copied from HW3 and `SegwayMath.sv` from HW2. All edits are in
Ex14. The supplied testbench retains its checks; its module name was changed
from `PID_dbg_tb` to `PID_fastsim_tb` to match its filename, a timescale was
added, and the success message includes Pranav Krovi (pkrovi).

## ModelSim

Run from Ex14, or add these four files to the project:

```tcl
vlog -sv PID.sv SegwayMath.sv balance_cntrl.sv PID_fastsim_tb.sv
vsim work.PID_fastsim_tb
run -all
```

Expect GOOD1 through GOOD13 and the final success message. The provided
bench ends with `$stop`, so ModelSim pauses after success. It uses a 100 MHz
simulation clock (`#5` half-period), retained from the supplied file.

To load the wrapper in each mode and check its hierarchy:

```tcl
vsim work.balance_cntrl
quit -sim
vsim -gfast_sim=0 work.balance_cntrl
```

The wrapper has no stimulus by itself. Ex14 only requests a compilation
check; functional integration testing is deferred to Ex16.

## Submission and verification

Submit `../balance_cntrl.sv` as requested by Ex14. Its dependencies are
`../PID.sv` and `../SegwayMath.sv`; keep all three in your project.

`simulation_output.txt` records the actual Icarus Verilog test results.
`PID_fastsim_pass.png` shows the supplied fast-simulation test's output.
The wrapper was compiled in both parameter modes. Normal PID behavior was
also checked against the earlier provided PID debug bench with `fast_sim=0`.

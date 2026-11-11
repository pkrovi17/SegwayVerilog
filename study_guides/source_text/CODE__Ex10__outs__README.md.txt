# Exercise 10: PID controller

## Summary

This exercise extends the combinational PID math from Ex06 with stored state.
`PID.sv` was copied from `Ex06/PID_Math.sv` and updated inside Ex10; files in
earlier exercises are unchanged.

The proportional (P) term responds to the current pitch error. The integral
(I) term now comes from an internal 18-bit accumulator, which adds the
saturated pitch error whenever `vld` is high. It holds when an addition would
overflow and can resume updating when the error changes direction. When
`rider_off` is asserted, it clears on the next rising clock edge, even if
`vld` is low. The derivative (D) term still comes from negated pitch rate
divided by 64. The three terms are added and saturated to a signed 12-bit output.

A 27-bit soft-start timer counts while `pwr_up` is high. Its upper eight bits
form `ss_tmr`, which gradually increases motor drive through SegwayMath.
The timer freezes when that byte reaches 0xFF: after 133,693,440 clocks,
about 2.674 seconds at 50 MHz. Power off clears the timer on the next clock.
Active-low asynchronous reset immediately clears both registers.

Key concepts:

- **Sequential RTL:** registers preserve state between clock edges;
  `always_ff` and nonblocking assignments describe their updates.
- **Valid gating:** `vld` enables accumulation only for a valid sensor sample.
- **Signed overflow:** adding operands with matching signs overflows if the
  result has the opposite sign. Holding the old value prevents wraparound.
- **Integral windup:** accumulated error can remain large after conditions
  change; rider-off clearing removes that stored error.
- **Soft start and one-shot timer:** a gradual ramp that stops at its limit
  instead of rolling back to zero.
- **Self-checking simulation:** ModelSim or Icarus Verilog runs stimulus and
  compares results with expected values, including reset and boundary cases.

## Run in ModelSim

From the Ex10 directory (or add these files to a project):

```tcl
vlog -sv PID.sv PID_dbg_tb.sv PID_extra_tb.sv
vsim work.PID_dbg_tb
run -all
```

The supplied bench should print GOOD1 through GOOD13 followed by:

```text
YAHOO!! all tests passed...my name is Pranav Krovi
```

It intentionally ends with `$stop`, so ModelSim pauses on success. Its only
edits are the requested name and an explicit `1ns/1ps` timescale. The original
`#5` half-period is preserved, so its simulation clock is 100 MHz; the DUT
still uses the specified counter widths for a 50 MHz system clock.

For the additional checks:

```tcl
vsim work.PID_extra_tb
run -all
```

The extra bench checks 543 cycles, covering exact arithmetic, both overflow
directions, recovery, valid gating, rider-off priority, timer rollover
boundaries, terminal hold, power cycling, and asynchronous reset. It seeds
the internal timer near two boundaries to avoid waiting 134 million clocks;
it does not change the DUT. The supplied bench's permissive GOOD2 condition
is left unchanged; the extra bench checks the P term against an exact result.

## Submission proof

- `PID_debug_pass.png`: image of the actual supplied-testbench transcript.
- `simulation_output.txt`: results from both simulation runs.

Submit `../PID.sv` and the passing-testbench proof as requested by Ex10.

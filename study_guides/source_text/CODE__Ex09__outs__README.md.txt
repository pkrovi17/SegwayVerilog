# Exercise 09 simulation

Implemented `PWM11.sv`, `rst_synch.sv`, `PB_release.sv`, and
`up_dwn_cnt4.sv`. The supplied `PWM11_test.sv` wrapper is unchanged;
it already contains the direction flip-flop that reverses the counter.
FPGA mapping and programming are omitted as requested.

## Summary

This exercise builds a pulse-width modulation (PWM) circuit to control average
motor drive or LED brightness by changing how long an output stays high.
An 11-bit counter repeatedly counts from 0 to 2047. With a 50 MHz clock,
each period lasts 40.96 us, giving a PWM frequency of about 24.4 kHz.
The `duty` input sets the switching point within that period.

`PWM11` produces two opposing outputs with gaps where both are low. These
gaps prevent the two power switches in a motor-driver stack from conducting
at the same time. It also generates a period-start signal (`PWM_synch`) and
an overcurrent-blanking signal (`ovr_I_blank`) for use by other control logic.

The supporting modules safely bring reset and push-button signals into the
clocked design. Each detected button release enables one step of a 4-bit
counter. The supplied wrapper reverses its direction at 0 and 15 and uses
the count to set PWM duty. Simulation checks the timing, pulse widths,
reset behavior, and button-driven counting before any FPGA programming.

Key terms and technologies learned:

- **Duty cycle:** the fraction of a PWM period spent high. Non-overlap
  shortens the actual high pulses compared with the nominal duty setting.
- **Non-overlap (dead time):** a both-low interval between opposing outputs.
  This avoids **shoot-through**, a direct current path through both switches.
- **Overcurrent blanking:** temporarily ignoring current detection near
  switching events to avoid false trips from transients.
- **Synchronization and metastability:** an asynchronous input can arrive
  near a clock edge and leave a flip-flop temporarily unsettled. Two
  synchronization stages reduce the chance of that uncertainty propagating.
- **Asynchronous reset assertion, synchronous release:** reset takes effect
  immediately, but this design releases it after two falling clock edges,
  away from the rising edges used by the other logic.
- **Edge detection:** comparing a synchronized button value with its previous
  value to produce one clock-long pulse on release. This is not debouncing.
- **Counters and SR flip-flops:** counters track PWM position and duty;
  reset-dominant set/reset flip-flops produce registered PWM outputs.
- **SystemVerilog RTL:** `always_ff`, nonblocking assignments (`<=`),
  continuous assignments, and explicit bit widths describe the hardware.
  Extra bits preserve carries in timing calculations and prevent overflow.
- **ModelSim and self-checking simulation:** testbenches drive inputs and
  compare outputs with expected behavior. Waveforms and VCD (Value Change
  Dump) files show how signals change over time.

## ModelSim

Run these commands from the Ex09 directory:

```tcl
vlog -sv PWM11.sv rst_synch.sv PB_release.sv up_dwn_cnt4.sv PWM11_test.sv PWM11_tb.sv PWM11_test_tb.sv
vsim work.PWM11_tb
add wave -radix unsigned sim:/PWM11_tb/duty
add wave -radix unsigned sim:/PWM11_tb/iDUT/cnt
add wave sim:/PWM11_tb/PWM1
add wave sim:/PWM11_tb/PWM2
add wave sim:/PWM11_tb/PWM_synch
add wave sim:/PWM11_tb/ovr_I_blank
run -all
```

Keep the four one-bit outputs digital. The counter can be displayed as
Analog (automatic). Choose No if prompted to close the simulation at `$finish`.
Each duty value is held for two PWM periods (81.92 us). In order, the values
are 0x000, 0x001, 0x03F, 0x040, 0x041, 0x200, 0x400, 0x600, 0x7BF,
0x7C0, and 0x7FF. The nominal 25%, 50%, and 75% settings start near
409.62 us, 491.54 us, and 573.46 us. Non-overlap shortens the high pulses.

Then test the supplied wrapper and supporting modules:

```tcl
vsim work.PWM11_test_tb
add wave -r sim:/PWM11_test_tb/iDUT/*
run -all
```

This checks asynchronous reset assertion, two falling edges for reset release,
button synchronization, one-clock release pulses, disabled count retention,
and counting 0 -> 15 -> 0 -> 2.

## Timing details

- PWM outputs follow the reset-dominant SR flip-flops in the PDF. They
  change after the rising clock edge using the previous counter value.
- `duty` changes in the PWM testbench only while `PWM_synch` is high.
- The PWM2 start and blanking thresholds use 12-bit sums to prevent overflow
  at large duty values.
- Blanking follows the diagram's strict `lower < cnt < upper` comparisons.
  These select 127 counter values per full window, despite the prose saying
  128 clocks. A window near the end of the period is truncated, not wrapped.
- `PB_release` synchronizes and detects a release; it does not debounce.

`PWM11_waveforms.png` shows actual simulated signals at five duty settings.
`simulation_output.txt` records the simulation results. Running `PWM11_tb`
also produces `PWM11.vcd` in the simulator's working directory.

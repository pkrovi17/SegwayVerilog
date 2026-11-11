# Exercise 19: Piezo warning driver

## Summary

`piezo_drv.sv` generates differential square waves for the piezo bender.
The driver selects between a normal "Charge!" fanfare, a reversed low-battery
fanfare, and a continuously repeated three-note overspeed warning.

Priority is **too_fast > batt_low > en_steer**. Overspeed immediately restarts
the sound at G6, including when a lower-priority tune is already playing.
Battery changes do not interrupt an existing full fanfare; direction is
captured when the next tune starts. If all inputs go low, both outputs
immediately become low. During a note they are complementary.

The first tune starts immediately when a request arrives. Normal/battery
tunes repeat every three seconds measured from one tune start to the next,
with silence after the notes finish. Overspeed repeats G6, C7, E7 without
a silent gap. When overspeed clears, its current three-note pattern finishes
and the driver selects the remaining request. If none remains, it stops
immediately instead.

The three-state FSM (`IDLE`, `PLAY`, `WAIT_REPEAT`) controls three timers:
note duration, tone half-period, and tune-repeat interval. A note index
selects the pitch and length. Reverse mode reads the same six-entry table
backward, reversing both the note order and the associated durations.

| Forward index | Note | Frequency (Hz) | Hardware duration (50 MHz clocks) |
| --- | --- | ---: | ---: |
| 0 | G6 | 1568 | 2^23 = 8388608 |
| 1 | C7 | 2093 | 2^23 = 8388608 |
| 2 | E7 | 2637 | 2^23 = 8388608 |
| 3 | G7 | 3136 | 2^23 + 2^22 = 12582912 |
| 4 | E7 | 2637 | 2^22 = 4194304 |
| 5 | G7 | 3136 | 2^24 = 16777216 |

The PDF's superscripts are powers of two, not decimal values such as 223.
A complete fanfare lasts about 1.1744 seconds in hardware. The repeat timer
counts to 150,000,000 for a three-second start-to-start interval.

`fast_sim` defaults to 1. A conditional generate selects timer increments of
64 for simulation or 1 for hardware. Note lengths and repeat time become
1/64 as long, and tones become 64 times faster. The accelerated fanfare
lasts 18.35008 ms and its repeat interval is 46.875 ms. The frequency timer
preserves any remainder after a half-period expires, avoiding accumulated
rounding error; accelerated half-periods can vary by one system clock.

Key concepts:

- **Piezoelectric effect:** applied voltage deforms the bender to produce sound.
- **Differential drive:** opposite output levels increase voltage swing.
- **Frequency divider:** counter/toggle logic converts 50 MHz into audio tones.
- **FSM priority and captured mode:** choose a warning and remember its
  direction while its tune finishes.
- **Parameter / conditional generate:** select fast simulation or real-time
  hardware timing at elaboration.
- **Residual counter:** carry fractional-period remainder into later cycles
  to preserve the average tone frequency under accelerated timing.

## Verification and ModelSim

The self-checking bench tests all six forward notes, all six reverse notes,
and two complete overspeed patterns. It checks note durations and output
periods, differential drive, initial/idle silence, battery-only operation,
battery priority over steering, overspeed preemption, and alarm recovery.
It measures a complete 46.875 ms accelerated repeat interval.

From Ex19:

```tcl
vlog -sv piezo_drv.sv piezo_drv_tb.sv rst_synch.sv piezoTest.sv
vsim work.piezo_drv_tb
add wave sim:/piezo_drv_tb/en_steer
add wave sim:/piezo_drv_tb/too_fast
add wave sim:/piezo_drv_tb/batt_low
add wave -radix unsigned sim:/piezo_drv_tb/iDUT/state
add wave -radix unsigned sim:/piezo_drv_tb/iDUT/tune_note
add wave sim:/piezo_drv_tb/piezo
add wave sim:/piezo_drv_tb/piezo_n
run -all
wave zoom full
```

Keep the one-bit signals digital. Use the state/note index to see the melody
sequence, and zoom into the piezo outputs to inspect their periods. The test
finishes around 80.9542 ms. Expected message:

```text
Pranav Krovi (pkrovi): all 18 piezo note checks and mode/priority checks passed!
```

`simulation_output.txt` is the actual Icarus Verilog transcript.
`piezo_pass.png` renders that transcript as an image, not a ModelSim screenshot.
Both parameter values and the supplied hardware wrapper were successfully
elaborated locally. That does not replace a Quartus device compilation.

## FPGA preparation and remaining physical work

`rst_synch.sv` is an unchanged copy from Ex09. The supplied `piezoTest.sv`,
`.qpf`, and `.qsf` are unchanged. The wrapper already instantiates
`piezo_drv #(0)`, selecting real hardware timing; the standalone module's
default remains fast simulation, as required. The QSF already lists the
three hardware source files and maps piezo to A14 and piezo_n to B16.

Quartus and a DE0-Nano are not accessible in this workspace, so the FPGA
build/programming and staff demo have not been performed. On your Quartus
machine:

1. Open `piezoTest.qpf`; confirm Cyclone IV E EP4CE22F17C6 and top `piezoTest`.
2. Compile the project and check that it completes without errors.
3. Program the DE0-Nano, reset, and test the three DIP switches.
4. Verify silence with all switches off; forward fanfare with en_steer;
   reversed fanfare with batt_low; and continuous G6/C7/E7 with too_fast.
5. Check the priority combinations and the three-second repeat interval,
   then arrange the teaching-staff demo if pursuing the bonus.

Submit `../piezo_drv.sv` and `../piezo_drv_tb.sv` as requested. Keep the
reset synchronizer and supplied project files alongside them for board testing.
Earlier exercise files were not modified.

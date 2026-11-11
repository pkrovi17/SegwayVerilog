# ECE551 Homework 3

Pranav Krovi — username shown in proof: `pkrovi`

## Summary

HW3 combines a steering-enable state machine with the PWM, PID, and UART
modules from Ex09–Ex12. All reused sources were copied into this directory;
earlier exercise files are unchanged.

The new steering FSM first waits for sufficient rider weight, then requires
1.3 seconds of continuous side-to-side balance before enabling steering.
Imbalance restarts the timer. Stepping off returns to the balance wait;
loss of rider weight returns directly to the initial state and has priority.
The load arithmetic and timer are external hardware supplied by the problem;
this module implements only their controlling state machine.

Key concepts include **finite-state machines**, **Mealy outputs** (outputs
that depend on both state and inputs), **hysteresis** (different thresholds
for entering and leaving a condition), timer clearing, and transition priority.
The reused modules cover PWM non-overlap, PID accumulation and saturation,
UART framing, asynchronous-input synchronization, and ready/clear handshakes.

The Cummings paper's coding guidance is followed: nonblocking assignments
for clocked state, blocking assignments for combinational logic, one process
per driven register, no `#0` delays, and defaults in combinational blocks.
The added steering test drives inputs away from rising clock edges and checks
after register updates settle.

## Submission checklist

| Problem | Source files | Proof |
| --- | --- | --- |
| 1: Steering FSM | `steer_en_SM.sv` | [Diagram reference](outs/steer_en_SM_diagram.png), [provided test](outs/steer_en_SM_tb_pass.png) |
| 2: PWM | `PWM11.sv`, `PWM11_tb.sv` | [Waveforms at five duty settings](outs/PWM11_waveforms.png) |
| 3: PID | `PID.sv` | [Provided PID test, with username](outs/PID_dbg_tb_pass.png) |
| 4: UART TX | `UART_tx.sv` | No image required; [test results](outs/UART_tx_tb_pass.png) also included |
| 5: UART RX | `UART_rx.sv`, `UART_tb.sv` | [Loopback proof, with username](outs/UART_tb_pass.png) |

**Manual submission step:** Problem 1 explicitly asks you to draw the bubble
diagram and take a phone picture. Use the supplied diagram as your reference,
include its defaults/legend, and photograph your drawing legibly. The generated
PNG and [printable PDF](outs/steer_en_SM_diagram.pdf) are digital diagrams,
not phone photographs.

The proof images are actual Icarus Verilog transcripts rendered as images,
and the PWM plots come from its VCD signal transitions. They are not ModelSim
screenshots. The homework names ModelSim; use the commands below to reproduce
the runs there and capture its console if required for submission.

## Fixes and validation

- The current Ex10 `PID.sv` had no assignment driving `I_term`. Restored
  `assign I_term = {{3{integrator[17]}}, integrator[17:6]};` in the HW3 copy.
- Steering state `00` is the initial state, matching the supplied bench.
  `rider_off` asserts immediately on `sum_lt_min` in the other states.
  `en_steer` deasserts immediately for either exit condition. Stepping off
  also clears the timer so old elapsed time cannot enable steering again.
- The main steering bench retains the provided checks and now also tests
  the required direct rider-off exit and its priority over stepping off.
  It finishes with one clear success message. A separate extra steering
  testbench is not required and is not part of the default run.
- Both supplied benches passed, PWM passed **11 settings / 45,056 clock
  checks**, PID passed **543 additional checks**, UART TX passed **6 frames**,
  and UART loopback passed **8 frames**. These checks passed.
- PWM follows Ex09's strict blanking inequalities. They select 127 counter
  values in a full window, despite the prose describing 128 clocks.
- PID's provided test uses a 100 MHz simulation clock; its hardware timer
  widths remain those specified for a 50 MHz clock. The extra PID bench
  seeds the timer near boundaries to test terminal hold without waiting
  through the entire hardware ramp.

## ModelSim

Run from the HW3 directory. Compile the explicit list below; do not compile
the unfinished `steer_en_SM_shell.sv` alongside the completed module because
both declare `steer_en_SM`.

```tcl
vlog -sv steer_en_SM.sv steer_en_SM_tb.sv PWM11.sv PWM11_tb.sv PID.sv PID_dbg_tb.sv PID_extra_tb.sv UART_tx.sv UART_rx.sv UART_tx_tb.sv UART_tb.sv
vsim work.steer_en_SM_tb
run -all
```

Then repeat `vsim work.<top>` and `run -all` for each desired top:

```text
PWM11_tb
PID_dbg_tb
PID_extra_tb
UART_tx_tb
UART_tb
```

The supplied PID bench stops with `$stop` even on success.
The steering bench and others use `$finish`; choose No if asked to close the simulation.
For PWM waveforms, add signals **before** running:

```tcl
vsim work.PWM11_tb
add wave -radix unsigned sim:/PWM11_tb/duty
add wave -radix unsigned sim:/PWM11_tb/iDUT/cnt
add wave sim:/PWM11_tb/PWM1
add wave sim:/PWM11_tb/PWM2
add wave sim:/PWM11_tb/PWM_synch
add wave sim:/PWM11_tb/ovr_I_blank
run -all
wave zoom full
```

Keep the four one-bit outputs digital. Each duty setting runs for 81.92 us;
the nominal 25%, 50%, and 75% settings start near 409.62, 491.54, and
573.46 us. Their actual high pulses are shorter because of non-overlap.

For reproducible Icarus checks, `python outs/run_checks.py` generates proof
images and transcripts; `python outs/plot_pwm.py` generates the PWM plot.
These scripts require Pillow, and the first requires `iverilog`/`vvp` on
PATH (or set `IVERILOG` and `VVP` to their locations). Simulation builds and
VCDs are stored under `/tmp/hw3-sim`. Graphviz can regenerate the diagram
from `outs/steer_en_SM.dot`.

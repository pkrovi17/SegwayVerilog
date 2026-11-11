# Exercise 20: A2D interface team

## Scope and status

This folder completes the **A2D interface half** of Ex20. The other half,
`inertial_integrator`, belongs to your teammates and is not implemented here.
Make one combined team submission as instructed by the exercise.

- `../A2D_intf.sv`: SPI conversion sequencing and holding registers.
- `../A2D_tb.sv`: self-checking test with the supplied ADC models.
- `../A2D_test.sv`: completed DE0-Nano test wrapper.
- `../SPI_main.sv`, `../PB_release.sv`, `../rst_synch.sv`: local copies of
  earlier modules. Earlier exercise files are unchanged.

All 13 conversion tests passed. The board wrapper also elaborated and passed
a simulation check of its request counter and four LED selections. Quartus
and the physical board are unavailable here; the Quartus build, programming,
and staff demo remain to be performed on your FPGA setup.

The module and filename use `A2D_intf`, matching the provided `A2D_test.sv`
and QSF. The slides also use `A2D_Intf` in prose; case matters in Verilog.

## Summary and operation

Each one-clock `nxt` request while idle initiates one conversion:

1. Select the next channel using a two-bit round-robin index.
2. Send `{2'b00, channel[2:0], 11'h000}` through SPI_main. This requests
   conversion; discard this transaction's incoming data.
3. Start a second SPI transfer and keep the channel index unchanged.
4. Store only the second response's low 12 bits in that channel's holding register.
5. Increment the round-robin index and return to idle.

| Round-robin index | ADC channel | Holding output |
| --- | ---: | --- |
| 0 | 0 | `lft_ld[11:0]` |
| 1 | 4 | `rght_ld[11:0]` |
| 2 | 5 | `steer_pot[11:0]` |
| 3 | 6 | `batt[11:0]` |

The slide listing battery as channel 5 is a typo: the channel list and
provided model use channel 6. The other holding registers keep their values
when one is updated. Reset clears all four and restarts at channel 0.
Requests arriving while busy are ignored; they are not queued.

The FSM states are `IDLE`, `WAIT_CONVERT`, `START_READ`, `WAIT_READ`, and
`UPDATE`. The dedicated start state also prevents the sticky SPI `done`
from being mistaken for completion of the second transaction. The second
MOSI command is ignored for the requested result; this design sends the
same channel command in both transfers.

### Timing detail with the supplied models

The handout says the two transfers have a one-clock gap. With the supplied
`SPI_main` and ADC models, an actual one-clock-high SS_n gap produces stale
channel data: the second conversion returns 0xBF0 instead of the expected
0xBF4. This was reproduced in a separate temporary timing experiment.

`ADC128S` detects completion through its SPI model, then registers the
requested channel. The next SPI response must be loaded after that update.
The implemented `START_READ` state gives one intervening idle FSM cycle,
which produces **two system-clock periods of SS_n high (40 ns at 50 MHz)**.
This passes the supplied models unchanged and adds only 20 ns compared with
the handout's literal one-clock gap. It is not claimed to be a 20 ns gap.
If exact one-clock spacing is required for grading, discuss this supplied-model
timing discrepancy with the teaching staff before changing the working sequence.

Each request completes in about 10.52 us, including the holding-register
update. The interface has no external ready output; callers must allow a
conversion to finish before requesting the next one.

## Key concepts and technologies

- **ADC / analog-to-digital conversion:** turn load-cell, steering, and battery
  voltages into 12-bit digital readings.
- **SPI and pipelined response:** one transfer selects a channel and a second
  reads its converted result; the first response is not the requested result.
- **Round-robin scheduling:** visit channels 0, 4, 5, and 6 repeatedly without
  changing the index partway through a conversion pair.
- **Holding registers:** preserve the latest value for each measurement.
- **FSM and handshake sequencing:** issue one-clock SPI requests and handle
  a completion flag that stays high until another transaction begins.
- **Reset synchronization / edge detection:** release board reset on a falling
  edge and convert an asynchronous button release into a one-clock pulse.
- **Prescaler and display mux:** a wide counter sets the request rate and a
  two-bit selection counter chooses which result appears on the LEDs.

## Testbench and expected values

The model decreases its base result by 0x010 after **each conversion pair**,
not after a full round-robin sweep. It ORs the channel number into the low bits.

| Conversion | Channel | Expected result |
| --- | ---: | --- |
| 0 | 0 | 0xC00 |
| 1 | 4 | 0xBF4 |
| 2 | 5 | 0xBE5 |
| 3 | 6 | 0xBD6 |
| 4 | 0 | 0xBC0 |

The test checks 12 consecutive conversions (three full sweeps), then asserts
reset during another transfer and verifies that the next result is channel 0,
0xC00. Every request checks exactly two 16-bit command frames, the channel
bits, inter-frame timing, retention after the first response, update of only
the selected output, rejection of a busy request, and no unsolicited SPI traffic.

`simulation_output.txt` records the actual Icarus Verilog run and
`A2D_pass.png` renders that transcript as an image. The board-wrapper check
seeded the 19-bit request counter near rollover to avoid a long wait;
`board_sim_output.txt` records its result. This test-only seeding does not
change the synthesizable counter.

## ModelSim

From Ex20, compile the explicit file list:

```tcl
vlog -sv SPI_main.sv A2D_intf.sv ADC128S.sv SPI_ADC128S.sv A2D_tb.sv
vsim work.A2D_tb
add wave sim:/A2D_tb/nxt
add wave sim:/A2D_tb/SS_n
add wave sim:/A2D_tb/SCLK
add wave sim:/A2D_tb/MOSI
add wave sim:/A2D_tb/MISO
add wave -radix hexadecimal sim:/A2D_tb/lft_ld
add wave -radix hexadecimal sim:/A2D_tb/rght_ld
add wave -radix hexadecimal sim:/A2D_tb/steer_pot
add wave -radix hexadecimal sim:/A2D_tb/batt
run -all
wave zoom full
```

Expected final message:

```text
Pranav Krovi (pkrovi): all 13 A2D conversion tests passed!
```

The test finishes near 140.081 us. Choose No if ModelSim asks to close the
simulation at `$finish`. The proof image is an Icarus transcript, not a
ModelSim screenshot; the commands above reproduce the test in ModelSim.

## DE0-Nano setup

The completed wrapper generates `nxt` when its 19-bit counter is all ones:
one request every 524288 clocks, approximately 95.37 conversions/s at 50 MHz.
Each of the four measurements is updated about 23.84 times/s.

SEL button releases cycle the LED display through left, right, steering,
and battery, showing bits [11:4] of the selected result. The button is
synchronized and edge-detected, not debounced.

The provided QSF already lists all five hardware source files and targets
Cyclone IV E EP4CE22F17C6. To finish on hardware:

1. Open `../A2D_test.qpf` and confirm top `A2D_test` and the correct device.
2. Compile the project and resolve any Quartus build errors.
3. Program the board, reset it, and check the four measurements via SEL.
4. Demonstrate the functioning interface to teaching staff if pursuing the bonus.

For the A2D portion of your combined submission, include `A2D_intf.sv`,
`A2D_tb.sv`, `A2D_test.sv`, and the required dependencies. Explain the
channel schedule and two-transfer handshake to the teammates implementing
`inertial_integrator` so the full team understands both halves.

# Exercise 15: SPI transceiver

## Summary

`SPI_main.sv` sends and receives a 16-bit packet simultaneously, most-significant
bit first. A one-clock `wrt` pulse captures `wt_data`, lowers `SS_n`, and starts
the serial clock. The clock idles high and runs at 50 MHz / 16 = 3.125 MHz.
Both devices change output data on falling SCLK edges and sample incoming
data on rising edges (SPI mode 3).

The main uses one 16-bit shift register for both directions. A separate
one-bit register samples MISO on each rising SCLK edge. That sampled bit is
shifted into the shared register at the next falling-edge time. All main
registers are clocked by `clk`; SCLK is generated data, not an internal clock.

The three-state FSM is `IDLE`, `FRONT`, and `TRANSFER`. The divider is held
at 4'b1011 when idle. After selection, five system clocks form the front
porch before the first SCLK fall, which does not shift away the loaded MSB.
After the sixteenth rise, eight system clocks form the back porch. The final
shift then captures the last received bit and deasserts selection while
preventing a seventeenth SCLK fall. The transaction takes 261 system clocks,
or 5.22 us. `rd_data` is complete when `done` asserts; it changes during shifting.

`SS_n` and `done` are registered. `done` stays high until the next accepted
request. Requests while busy are ignored. Active-low asynchronous reset
returns selection and SCLK high and clears completion.

Key terms and technologies:

- **SPI:** synchronous, full-duplex serial communication using a shared clock.
- **MOSI / MISO:** main-to-secondary and secondary-to-main serial data.
- **SS_n:** active-low secondary select, marking an active transaction.
- **CPOL / CPHA:** clock polarity and phase; here both are 1 (mode 3).
- **Front/back porch:** timing margins between selection and serial-clock activity.
- **Clock divider:** a 4-bit counter whose most-significant bit forms SCLK.
- **FSM and datapath:** control logic enables loading, sampling, shifting,
  counting, and completion using `always_comb` and `always_ff`.
- **Sensor register access:** the first byte holds read/write and register
  address; the second byte carries write data or the read response.
- **Interrupt:** the sensor's INT output reports new readings; specified
  low-byte reads acknowledge it.
- **Self-checking simulation / `$readmemh`:** compare received values with
  expected sensor readings loaded from `inert_data.hex`.

## Run in ModelSim

Run from Ex15 so both `$readmemh` calls can find `inert_data.hex`:

```tcl
vlog -sv SPI_main.sv SPI_iNEMO1.sv SPI_main_tb.sv
vsim work.SPI_main_tb
add wave sim:/SPI_main_tb/clk
add wave sim:/SPI_main_tb/SS_n
add wave sim:/SPI_main_tb/SCLK
add wave sim:/SPI_main_tb/MOSI
add wave sim:/SPI_main_tb/MISO
add wave sim:/SPI_main_tb/wrt
add wave sim:/SPI_main_tb/done
add wave -radix hexadecimal sim:/SPI_main_tb/wt_data
add wave -radix hexadecimal sim:/SPI_main_tb/rd_data
add wave sim:/SPI_main_tb/INT
run -all
wave zoom full
```

Keep the serial signals digital. Zoom into a transaction to inspect its
16 clocks and porches. Choose No if asked to close the simulation at `$finish`.
The bench also generates `SPI_main.vcd` in the simulation's working directory.

## Checks and submission

The self-checking bench completes 15 transactions:

- WHO_AM_I read: 0x8F00 returns low byte 0x6A.
- INT configuration: write 0x0D02, check `NEMO_setup`, then read back 0x02.
- Wait for INT for each of the first two data rows, then read yaw high/low,
  AX low/high, and pitch high/low against the hex-file contents.
- Check that yawL and ptchL reads clear INT, and that INT reasserts for the
  next row. The supplied model clears INT for either of those low-byte reads.
- During every transaction, check MOSI bit order, divider timing, exactly
  16 falling/rising edges, final received bits, busy-request rejection,
  and completion/data retention. Also check reset initially and mid-transaction.

The sensor model has its own power-on reset; resetting the main alone does
not reset an interrupted sensor transaction. The mid-transaction reset check
is therefore the last test and verifies the main's reset outputs.

`SPI_iNEMO1.sv` is the supplied model, with only an explicit `1ns/1ps`
timescale added so its `#40` internal half-period is 40 ns. Its functional
code and the supplied `inert_data.hex` are unchanged. Icarus emits sensitivity
notices for constant selects in the model's `always_comb`; simulation passes.

Submit `../SPI_main.sv` and `../SPI_main_tb.sv`. The model and hex file are
simulation dependencies. `SPI_pass.png` is the actual passing simulation
transcript rendered as an image; `simulation_output.txt` contains its text.

# Exercise 11: UART transmitter

## Summary

`UART_tx.sv` converts a parallel byte into a serial 8N1 frame: one low start
bit, eight data bits sent least-significant bit first, and one high stop bit.
The TX line stays high while idle. A one-clock `trmt` request captures
`tx_data` and starts transmission. Requests while busy are ignored.

A two-state FSM (`IDLE` and `TRANSMIT`) controls a 9-bit shift register,
a 13-bit baud counter, and a 4-bit frame-bit counter. Shifting in ones
provides the stop bit without storing it in a tenth register. `tx_done`
asserts after the entire stop bit and stays high until the next accepted
request. Active-low asynchronous reset aborts a frame, clears `tx_done`,
and restores TX to its idle-high state.

Key concepts and technologies:

- **UART:** asynchronous serial communication with an agreed rate and frame
  format; there is no clock wire shared between transmitter and receiver.
- **8N1:** eight data bits, no parity, one stop bit; with the start bit,
  each frame occupies ten bit periods.
- **Baud rate:** symbols per second, equal to bits per second here.
  Dividing 50 MHz by 5208 gives approximately 9600.61 baud.
- **Off-by-one timing:** count 0 through 5207 for exactly 5208 clocks,
  giving 104.16 us per bit and 1.0416 ms per frame. The PDF's wording
  "0 to 5208" would instead count 5209 clocks if both endpoints were used.
- **FSM and datapath:** separate state/control logic decides when to load,
  count, shift, and signal completion. Combinational defaults avoid latches.
- **Parallel-load shift register:** captures all data at once, then sends
  one bit at a time. Later changes to `tx_data` do not alter the frame.
- **SystemVerilog RTL:** `always_ff` describes registers and `always_comb`
  describes the FSM's next-state and control logic.
- **Self-checking simulation:** checks serial values and timing against
  an expected frame; VCD waveforms record the actual signal transitions.

## Run in ModelSim

From the Ex11 directory, or with both files added to your project:

```tcl
vlog -sv UART_tx.sv UART_tx_tb.sv
vsim work.UART_tx_tb
add wave sim:/UART_tx_tb/clk
add wave sim:/UART_tx_tb/rst_n
add wave sim:/UART_tx_tb/trmt
add wave -radix hexadecimal sim:/UART_tx_tb/tx_data
add wave sim:/UART_tx_tb/TX
add wave sim:/UART_tx_tb/tx_done
run -all
wave zoom full
```

Keep signals digital. Zoom into a frame to see start, D0 through D7, and
stop. Choose No if ModelSim asks to close the simulation at `$finish`.
`tx_data` deliberately changes after capture and `trmt` pulses again
mid-frame, to check that the active transmission is preserved.

## Verification and submission

The test sends 0x00, 0xFF, 0xA5, 0x3C, 0x81, and 0x7E. It checks every
clock of every bit (312,480 checks), exact completion timing, sticky done,
idle behavior, asynchronous reset during transmission, and restart after reset.

- `simulation_output.txt`: actual simulation results.
- `UART_tx_waveforms.png`: actual simulated frames with bit boundaries.
- `UART_tx.vcd` is generated in the simulation's working directory.

Submit `../UART_tx.sv`, as requested by the PDF. Earlier exercises are unchanged.

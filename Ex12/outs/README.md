# Exercise 12: UART receiver

## Summary

`UART_rx.sv` receives the 9600-baud, 8N1 serial frames produced by the
transmitter from Ex11. `UART_tx.sv` is an unchanged local copy; earlier
exercises are not modified. `UART_tb.sv` connects TX directly to RX and
compares the received byte with the byte sent.

The receiver uses two flip-flops to synchronize RX and another to remember
its previous value. A falling edge starts the two-state FSM (`IDLE` and
`RECEIVE`). It waits 2604 clocks to sample the start bit near its center,
then waits 5208 clocks between the remaining samples. At 50 MHz, a full
bit lasts 104.16 us. Synchronization adds a few clocks of detection delay.

A 9-bit register shifts right ten times: start, eight data bits, then stop.
The start bit falls out, the stop bit occupies bit 8, and bits [7:0] hold
the received byte. `rdy` asserts at the stop-bit sample, about half a bit
before the transmitter asserts `tx_done` at the end of the stop bit.

`rdy` stays high until `clr_rdy` or the next detected start clears it.
Clearing the flag does not erase the data. `clr_rdy` has priority if it
coincides with completion. Read `rx_data` only while `rdy` is high: it is
the shift-register output and changes as the next frame is received.
Reset is asynchronous and active low.

Key terms and technologies:

- **UART / 8N1:** asynchronous serial communication with eight data bits,
  no parity, and one stop bit; data is sent least-significant bit first.
- **Metastability and synchronization:** RX is asynchronous to the local
  clock; two flip-flops reduce the risk of propagating an unsettled value.
- **Mid-bit sampling:** sampling away from transitions tolerates small
  clock and detection differences between transmitter and receiver.
- **FSM and datapath:** separate control logic operates the baud counter,
  bit counter, and shift register using `always_comb` and `always_ff`.
- **Ready/clear handshake:** a sticky flag tells the consumer a byte is
  available; the consumer acknowledges it using `clr_rdy`.
- **Loopback test:** connect a transmitter to a receiver and automatically
  compare sent and received data in simulation.

The design assumes valid 8N1 frames as in the exercise. It does not add
parity checking, framing-error reporting, or false-start rejection.

## Run in ModelSim

Run from the Ex12 directory, or add these three files to a project:

```tcl
vlog -sv UART_tx.sv UART_rx.sv UART_tb.sv
vsim work.UART_tb
add wave sim:/UART_tb/rst_n
add wave sim:/UART_tb/trmt
add wave -radix hexadecimal sim:/UART_tb/tx_data
add wave sim:/UART_tb/TX
add wave sim:/UART_tb/tx_done
add wave -radix hexadecimal sim:/UART_tb/rx_data
add wave sim:/UART_tb/rdy
add wave sim:/UART_tb/clr_rdy
run -all
wave zoom full
```

Keep the signals digital and zoom into a frame to inspect the serial bits.
Choose No if prompted to close the simulation at `$finish`.
The testbench writes `UART.vcd` in the simulator's working directory.

## Tests and submission

The test sends 0x00, 0xFF, 0xA5, 0x5A, 0x01, 0x80, 0x3C, and 0x7E.
It checks received data, receive timing, exact transmit completion timing,
sticky flags, clearing with `clr_rdy`, clearing on a new start, and reset
during an active frame followed by successful reception.

Submit `../UART_rx.sv`, `../UART_tb.sv`, and `UART_pass.png` as proof.
`simulation_output.txt` contains the actual simulation transcript.

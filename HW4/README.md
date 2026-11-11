# ECE551 Homework 4

Pranav Krovi (`pkrovi`)

## Submission checklist

| Problem | Required submission | Status |
| --- | --- | --- |
| 1: Design Vision tutorial | Your signed confirmation | Handled by you, as confirmed in chat |
| 2: Project team | Your signed team/form confirmation | Handled by you, as confirmed in chat |
| 3: Authentication | `Auth_blk.sv`, `Auth_blk_tb.sv`, [passing proof](outs/Auth_pass.png) | 25 checks, 17 UART bytes, all 8 FSM arcs passed |
| 4: Balance control | `balance_cntrl.sv`, `PID.sv`, `balance_cntrl_chk_tb.sv`, [passing proof](outs/balance_pass.png) | All 1500 supplied vectors passed |
| 5: Synthesis | `balance_cntrl.dc`, `area.txt`, `balance_cntrl.vg` | Genuine CAE outputs copied from Ex17 |
| 6: SPI | `SPI_main.sv`, `SPI_main_tb.sv`, [passing proof](outs/SPI_pass.png) | All 15 sensor transactions passed |

The authentication [bubble diagram](outs/Auth_blk_diagram.png) and
[printable PDF](outs/Auth_blk_diagram.pdf) are included for the design portion
of problem 3. The PDF does not request a phone photograph for this diagram.
All source changes and new outputs are inside HW4; earlier work is unchanged.

## Authentication summary

`Auth_blk` receives UART data from the Bluetooth module through the copied
`UART_rx`. The receiver handles 9600-baud 8N1 frames and signals a received
byte with `rx_rdy`. The authentication FSM acknowledges every byte through
`clr_rx_rdy`, so a received command is processed once.

The three states are:

- **OFF:** `pwr_up=0`. Receiving G (0x47) authorizes power-on.
- **POWERED:** `pwr_up=1`. Receiving S (0x53) powers off immediately if
  `rider_off=1`; otherwise it enters the pending-shutdown state.
- **WAIT_RIDER_OFF:** power stays on while the rider remains. Once
  `rider_off=1`, power turns off. A new G cancels the pending S request.

Unrecognized bytes are ignored in all three states, so "last command" means
the last recognized G/S command. If a new G and rider-off condition occur
together while waiting, the new authorization takes priority. Stepping off
without a preceding S does not cancel authorization. Active-low asynchronous
reset returns to OFF; the receiver and transmitter use the same reset in
the self-checking testbench.

The test uses the actual UART transmitter and full-length frames. It checks
initial idle, invalid bytes, repeated G/S, immediate and deferred shutdown,
cancellation of shutdown, reset in both powered states, reception after reset,
and UART acknowledgment. It records state transitions and requires all eight
valid arcs (including the three self-loops) to have occurred before success.

## Reused work and synthesis provenance

The balance RTL and gate-level netlist are exact copies of Ex17. The random
testbench and supplied stimulus/response files came from Ex16. The HW4
synthesis script differs from Ex17 only in its introductory comment and
writing the area report as `area.txt`, matching the homework filename.

The synthesis outputs are from your real CAE Design Compiler run on
October 30, 2026, not newly generated or estimated results. They describe
the original hardware math (`fast_sim=0`) at the SAED32 RVT slow corner,
0.95 V / 125 C, with an 8 ns clock target. The random-vector test explicitly
uses `fast_sim=1`, as required by Ex16.

From the supplied reports/netlist:

- Total cell area: **2666.732981 um^2**.
- Total area including estimated interconnect: **3180.679067 um^2**.
- Flat netlist: **one module, 886 RVT cell instances**, matching the report.
- Worst reported setup slack: **+0.75 ns**.
- Worst reported minimum-delay slack: **+0.16 ns**.

The timing reports are retained under `outs/` for reference, although HW4
problem 5 requests the area report and netlist only. The mapped netlist has
not been re-simulated locally because its SAED32 cell simulation library is
not available here. The tests use the RTL.

The SPI RTL/model/data were copied from Ex15. Its checks include WHO_AM_I,
INT configuration write/readback, first-two-row pitch/yaw/acceleration reads,
independent INT-clearing checks for pitch and yaw, clock/porch timing, busy
request rejection, and reset. Only whitespace in the copied main RTL and the
testbench's success message were updated. The supplied sensor model's
explicit timescale from Ex15 is retained.

## Key concepts

- **FSM / Moore output:** state stores authorization and whether shutdown
  is pending; `pwr_up` depends on state.
- **UART / 8N1:** serial commands are transferred as start, eight data,
  and stop bits. Synchronization brings asynchronous RX into the clock domain.
- **Ready/clear handshake:** acknowledge a sticky received-byte flag after
  consuming its contents.
- **State and arc coverage:** exercise both the states and the conditions
  that connect them, rather than only a basic power-on/power-off sequence.
- **Random-vector reference checking:** compare packed balance outputs with
  all 1500 supplied expected responses after each clock's updates settle.
- **Synthesis / technology mapping:** generate a flattened SAED32 gate-level
  netlist and inspect area/timing reports under the specified constraints.
- **SPI full duplex:** simultaneous command transmission and sensor response
  reception with 16-bit packets, explicit clock edges, and select margins.
- **Cummings coding guidance:** use nonblocking assignments for registers,
  blocking assignments and defaults for combinational FSM logic, one process
  per written register, and avoid `#0` timing tricks. Tests drive stimulus away
  from sampling edges and allow sequential updates to settle before checks.

## ModelSim

Run from HW4 so the two balance hex files and `inert_data.hex` are found.
Compile the explicit RTL list; **do not compile `balance_cntrl.vg` together
with `balance_cntrl.sv`**, because both declare the same top module:

```tcl
vlog -sv UART_rx.sv UART_tx.sv Auth_blk.sv Auth_blk_tb.sv PID.sv SegwayMath.sv balance_cntrl.sv balance_cntrl_chk_tb.sv SPI_main.sv SPI_iNEMO1.sv SPI_main_tb.sv
vsim work.Auth_blk_tb
run -all
```

Expected authentication message:

```text
Pranav Krovi (pkrovi): all 25 authentication checks passed (17 UART bytes, all 8 FSM arcs)!
```

Then run the other required benches:

```tcl
vsim work.balance_cntrl_chk_tb
run -all
vsim work.SPI_main_tb
run -all
```

Choose No if ModelSim asks to close the simulation at `$finish`.
The authentication run takes approximately 17.71 ms of simulation time,
the balance check 14996 ns, and SPI approximately 698.47 us.
The proof images are actual Icarus Verilog transcripts rendered as images;
they are not ModelSim screenshots. Use these commands for your own console
screenshots if your submission requires ModelSim specifically.

### Synthesis rerun (optional)

HW4 already contains the real CAE area report and netlist. If you rerun,
load the same CAE modules as Ex17, enter `dc_shell`, and source
`balance_cntrl.dc`. It now uses your tutorial's
`.synopsys_dc.setup` for the library/search paths, deriving the library name
from the first configured target .db. It writes `area.txt` and
`balance_cntrl.vg` here. All assignment constraints and `fast_sim=0` are
preserved. The existing October 30 outputs above have not been regenerated;
rerunning under the tutorial's TT corner will change the results from the
original SS-corner run.

## Files needed alongside required submissions

`Auth_blk.sv` requires `UART_rx.sv`; its testbench also requires `UART_tx.sv`.
Balance control requires `SegwayMath.sv`, `PID.sv`, and both balance hex files
for its testbench. SPI's testbench requires `SPI_iNEMO1.sv` and `inert_data.hex`.
Keep those dependencies in the project even when the submission checklist
lists only the specifically requested files.

# Exercise 16: Balance control random testing

## Summary

This exercise tests `balance_cntrl` using 1500 supplied stimulus vectors and
their expected responses. The DUT combines PID balance correction with
SegwayMath steering, motor shaping, saturation, and overspeed detection.
`balance_cntrl.sv`, `PID.sv`, and `SegwayMath.sv` were copied from Ex14 without
changes. Earlier exercise files remain unchanged.

`balance_cntrl_chk_tb.sv` reads the files into two memories using `$readmemh`:

- `stim[0:1499]`: 49 bits per entry.
- `resp[0:1499]`: 25 bits per entry.

Each stimulus is unpacked in this order:

```verilog
{rst_n, vld, ptch, ptch_rt, pwr_up, rider_off, steer_pot, en_steer}
```

Each expected response is compared against:

```verilog
{lft_spd, rght_spd, too_fast}
```

The bench selects `fast_sim=1` and forces `iDUT.ss_tmr` to 0xFF, as required,
so the soft-start ramp does not affect this test. It starts the clock at zero,
toggles every 5 ns, applies one vector per cycle, and checks 1 ns after each
rising edge. This delay allows nonblocking register updates and combinational
logic to settle. All 1500 responses match the supplied reference file.

Key concepts:

- **Random-vector testing:** varied inputs exercise combinations that are
  harder to cover with a few directed examples.
- **Golden response:** a supplied expected result used to judge the DUT.
- **Memory arrays and `$readmemh`:** load hexadecimal vectors from files
  instead of embedding many input values directly in the testbench.
- **Concatenation and bit mapping:** pack or unpack several signals in an
  explicitly defined order, preserving every signal's width.
- **`force`:** a simulation-only override of an internal signal; it does not
  modify the synthesizable design.
- **Case inequality (`!==`):** detects output mismatches including X/Z values.
  The bench also rejects unknown entries caused by missing/incomplete files.

## Run in ModelSim

Run from Ex16 so `$readmemh` can find both hex files. Compile only the Ex16
copies to avoid duplicate module definitions from earlier exercises:

```tcl
vlog -sv PID.sv SegwayMath.sv balance_cntrl.sv balance_cntrl_chk_tb.sv
vsim work.balance_cntrl_chk_tb
run -all
```

Expected output:

```text
Pranav Krovi (pkrovi): all 1500 balance control vectors passed!
```

The test completes at 14996 ns. Choose No if ModelSim asks to close the
simulation at `$finish`. A failure prints the zero-based vector index,
stimulus, actual response, and expected response, then stops.

## Submission

Submit `../balance_cntrl.sv` and `../balance_cntrl_chk_tb.sv` as requested.
Keep `../PID.sv`, `../SegwayMath.sv`, and both hex files available as project
dependencies. `simulation_output.txt` records the actual Icarus Verilog run;
`balance_cntrl_pass.png` is that passing transcript rendered as an image.

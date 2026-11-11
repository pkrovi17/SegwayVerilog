# ECE551 study materials

- [Crash course PDF](ECE551_Crash_Course.pdf): explanations, worked examples, hardware drawings, a corrected practice-midterm answer key, and quick drills.
- [Two-page cheat sheet PDF](ECE551_Midterm_Cheat_Sheet.pdf): revised around the supplied practice exam's short answers, hardware drawings, simulation traces, debugging, and FSM completion.
- [Four-page code examples PDF](ECE551_Midterm_Code_Examples.pdf): common FF/reset/enable/SR/T/JK patterns, complete controller FSMs, synchronization, shifters, PWM, arithmetic, and testbench code.
- [Editable code examples](ECE551_Midterm_Code_Examples.md) and [complete example modules](ECE551_Example_Modules.sv). FF fragments are independent alternatives; the SV file contains ten complete modules and excludes fragments and the externally supplied SPI master.
- [Editable crash course](ECE551_Crash_Course.md) and [editable cheat sheet](ECE551_Midterm_Cheat_Sheet.md).

Read the crash course first, redo the practice midterm without looking at its answers, then use the cheat sheet to check your work. Print the cheat sheet at **100% / actual size**. It is exactly two pages; duplex prints on one sheet. This year's permitted-note rules are not present in the folder. The provided practice exam is from Spring 2020; the guides also cover Fall 2026 UART, PID, steering, PWM, and FIFO work.

`source_inventory.json` inventories the original folder. `source_text/` contains extracted PDF text, text/code copies, and screenshot OCR for review. The PDFs were rendered with ReportLab and visually inspected. Column heights and code widths are checked by `build_study_pdfs.py`; the generated report is in `validation/layout_report.json`.

The earlier course-wide cheat sheet is preserved in `archive/ECE551_Midterm_Cheat_Sheet_Course_Wide_v1.md` and the matching PDF. The revised cheat sheet directly covers all sixteen practice questions and retains only a short current-homework backup. The code reference has a larger font and is a separate study/printing document.

Verification: eight relevant existing arithmetic/control/UART testbenches passed using the existing source files. `validation/semantics_tb.sv` separately checks NBA old-value behavior, short-pulse net-delay filtering, transport-style delayed NBA, and blocking versus nonblocking ring-oscillator self-triggering. Logs are saved under `validation/`. The original homework and exercise files were not edited.

The new complete code modules compile with Icarus Verilog. `validation/code_reference_tb.sv` verifies the reference FF fragments' reset/hold/priority, FSM launches/wait-cycle/sticky completion, steering exit priority, synchronization and edge pulses, pattern matching, parameterized counting, and PWM duty boundaries. The standalone reference adder bench passes all 512 combinations.

To rebuild after editing:

```bash
python study_guides/build_study_pdfs.py
```

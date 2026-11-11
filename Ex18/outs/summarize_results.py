"""Build the Ex18 comparison table from real Design Compiler reports.
Run after both synthesis jobs: python outs/summarize_results.py
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
number = r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?"


def read_result(variant):
    folder = root / "reports" / variant
    files = [folder / name for name in
             ("area.rpt", "power.rpt", "timing_max.rpt", "timing_min.rpt")]
    missing = [str(p.relative_to(root)) for p in files if not p.is_file()]
    if missing:
        raise SystemExit("Run CAE synthesis first. Missing: " + ", ".join(missing))
    area_text, power_text, max_text, min_text = [p.read_text() for p in files]
    area = re.search(r"Total cell area:\s*(" + number + ")", area_text, re.I)
    power = re.search(r"Total Dynamic Power\s*=\s*([^\n(]+)", power_text, re.I)
    if not area or not power:
        raise SystemExit("Cannot find cell area / total dynamic power in " + str(folder))
    slacks = []
    for text in (max_text, min_text):
        values = re.findall(r"slack\s*\((?:MET|VIOLATED)\)\s*(" + number + ")", text, re.I)
        if not values:
            raise SystemExit("No constrained slack found in timing report for " + variant)
        slacks.append(min(float(v) for v in values))
    return float(area.group(1)), power.group(1).strip(), slacks


original = read_result("original")
gated = read_result("gated")
lines = ["# Ex18 area, power, and timing comparison", "",
         "Actual final Design Compiler reports; identical constraints/activity for both runs.", "",
         "| Design | Cell area (um^2) | Total dynamic power (reported units) | Worst setup slack (ns) | Worst hold slack (ns) | Setup/hold timing |",
         "| --- | ---: | ---: | ---: | ---: | --- |"]
for label, (area, power, (setup, hold)) in (("Original", original), ("Gated", gated)):
    status = "PASS" if setup >= 0 and hold >= 0 else "FAIL"
    lines.append(f"| {label} | {area:g} | {power} | {setup:g} | {hold:g} | {status} |")
lines += ["", f"Cell area change: {(gated[0] / original[0] - 1) * 100:+.2f}%.", "",
          "Dynamic power is a vectorless estimate using the activity specified in mult_accum.dc.",
          "Inspect both constraints.rpt files for transition, capacitance, and other violations.",
          "The setup/hold column summarizes the reported path slacks; it is not a check of every design rule.", ""]
result = "\n".join(lines)
(root / "outs" / "comparison.md").write_text(result)
print(result)

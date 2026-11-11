"""Run HW3 simulations and render their actual transcripts as proof images.
Usage: IVERILOG=/path/to/iverilog VVP=/path/to/vvp python outs/run_checks.py
Requires Pillow for PNG output. Simulation builds and VCDs go in /tmp/hw3-sim.
"""
from pathlib import Path
import os
import subprocess
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
out = root / 'outs'
build = Path('/tmp/hw3-sim')
build.mkdir(exist_ok=True)
iverilog = os.environ.get('IVERILOG', 'iverilog')
vvp = os.environ.get('VVP', 'vvp')
cases = [
    ('steer_en_SM_tb', ['steer_en_SM.sv', 'steer_en_SM_tb.sv'], 'all required steering tests passed!', False),
    ('PWM11_tb', ['PWM11.sv', 'PWM11_tb.sv'], 'All 11 PWM duty tests passed', False),
    ('PID_dbg_tb', ['PID.sv', 'PID_dbg_tb.sv'], 'YAHOO!! all tests passed', True),
    ('PID_extra_tb', ['PID.sv', 'PID_extra_tb.sv'], '543 additional PID checks passed!', False),
    ('UART_tx_tb', ['UART_tx.sv', 'UART_tx_tb.sv'], 'all 6 UART frames passed', False),
    ('UART_tb', ['UART_tx.sv', 'UART_rx.sv', 'UART_tb.sv'], 'all 8 UART loopback tests passed!', False),
]
font = ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSansMono.ttf', 18)
combined = []
for top, sources, success, stops_on_success in cases:
    binary = build / (top + '.vvp')
    compile_cmd = [iverilog, '-g2012', '-s', top, '-o', str(binary)] + sources
    compile_result = subprocess.run(compile_cmd, cwd=root, text=True, capture_output=True, timeout=120)
    if compile_result.returncode:
        raise SystemExit(compile_result.stdout + compile_result.stderr)
    run_cmd = [vvp, '-n' if stops_on_success else '-N', str(binary)]
    result = subprocess.run(run_cmd, cwd=build, text=True, capture_output=True, timeout=120)
    transcript = compile_result.stdout + compile_result.stderr + result.stdout + result.stderr
    # Supplied benches use $stop even on success. Check the message as well
    # as the exit code, since -n would also exit normally on a failure stop.
    passed = result.returncode == 0 and success in transcript and 'ERROR' not in transcript
    label = 'PASS' if passed else 'FAIL'
    text = f'HW3 - Pranav Krovi (pkrovi)\n{top}: {label}\nActual Icarus Verilog output\n\n' + transcript
    (out / (top + '_output.txt')).write_text(text)
    print(f'{top}: {label}', flush=True)
    if not passed:
        raise SystemExit(text)
    lines = text.rstrip().splitlines()
    width = max(int(font.getlength(line)) for line in lines) + 48
    image = Image.new('RGB', (width, len(lines) * 28 + 48), 'white')
    draw = ImageDraw.Draw(image)
    for i, line in enumerate(lines):
        color = '#137333' if any(word in line for word in ['PASS', 'GOOD', 'passed']) else '#202124'
        draw.text((24, 24 + i * 28), line, font=font, fill=color)
    image.save(out / (top + '_pass.png'))
    combined.append(text)
(out / 'simulation_output.txt').write_text('\n\n'.join(combined))
print(f'All {len(cases)} HW3 testbenches passed.', flush=True)

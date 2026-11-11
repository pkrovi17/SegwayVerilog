"""Render PWM waveforms from the actual VCD produced by run_checks.py."""
from pathlib import Path
from bisect import bisect_right
from PIL import Image, ImageDraw, ImageFont

out = Path(__file__).resolve().parent
names, history = {}, {}
header, time = True, 0
wanted = ['duty', 'cnt', 'PWM1', 'PWM2', 'PWM_synch', 'ovr_I_blank']
for line in Path('/tmp/hw3-sim/PWM11.vcd').read_text().splitlines():
    if header:
        fields = line.split()
        if line.startswith('$var') and fields[4] in wanted:
            names.setdefault(fields[4], fields[3])
        if line.startswith('$enddefinitions'):
            header = False
            history = {code: [] for code in names.values()}
        continue
    if line.startswith('#'):
        time = int(line[1:])
    elif line and line[0] in '01xz':
        code, value = line[1:], line[0]
        if code in history:
            history[code].append((time, int(value) if value in '01' else None))
    elif line.startswith('b'):
        value, code = line[1:].split()
        if code in history:
            history[code].append((time, int(value, 2) if not set(value) & set('xz') else None))

fontpath = '/usr/share/fonts/TTF/DejaVuSansMono.ttf'
font = ImageFont.truetype(fontpath, 18)
small = ImageFont.truetype(fontpath, 15)
title = ImageFont.truetype(fontpath, 24)
image = Image.new('RGB', (1500, 1430), 'white')
draw = ImageDraw.Draw(image)
draw.text((30, 18), 'HW3 PWM11 - Pranav Krovi (pkrovi)', font=title, fill='#17212b')
draw.text((30, 56), 'Actual Icarus Verilog VCD | 50 MHz clock | 2048 clocks/period | NONOVERLAP = 64', font=small, fill='#465563')
left, right, period = 185, 1460, 40960000
signals = ['PWM1', 'PWM2', 'PWM_synch', 'ovr_I_blank']
colors = ['#1261a0', '#bf4912', '#6d3aa1', '#187747']
for panel, duty in enumerate([0, 512, 1024, 1536, 2047]):
    change = next(t for t, value in history[names['duty']] if value == duty)
    start = next(t for t, value in history[names['cnt']] if value == 0 and t > max(change, 2000))
    end = start + period
    top = 104 + panel * 258
    draw.text((30, top), f'duty = 0x{duty:03X} ({duty}/2048) | absolute time {start/1e6:.3f} to {end/1e6:.3f} us', font=font, fill='#17212b')
    for tick in [0, 512, 1024, 1536, 2048]:
        x = left + tick / 2048 * (right-left)
        draw.line((x, top+32, x, top+204), fill='#dfe4e8')
        draw.text((x-18, top+210), str(tick), font=small, fill='#465563')
    for row, (signal, color) in enumerate(zip(signals, colors)):
        baseline = top + 56 + row * 43
        draw.text((30, baseline-12), signal, font=small, fill=color)
        events = history[names[signal]]
        index = bisect_right([t for t, _ in events], start)-1
        value = events[index][1]
        assert value is not None
        def y(v):
            return baseline-12 if v else baseline+12
        points = [(left, y(value))]
        for t, value in events[index+1:]:
            if t > end:
                break
            x = left + (t-start)/period*(right-left)
            points.extend([(x, points[-1][1]), (x, y(value))])
        points.append((right, points[-1][1]))
        draw.line(points, fill=color, width=2)
    draw.text((600, top+234), 'Clock cycles from period boundary', font=small, fill='#465563')
image.save(out / 'PWM11_waveforms.png')
print('Saved PWM11_waveforms.png from the HW3 simulation VCD.')

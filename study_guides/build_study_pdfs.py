"""Render the editable course notes into PDFs. Requires ReportLab only."""
from pathlib import Path
import re, html, json
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.graphics.shapes import Drawing, Rect, Line, Polygon, String
from reportlab.graphics import renderSVG
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Preformatted, Table, TableStyle,
    KeepTogether, HRFlowable,
)

ROOT = Path(__file__).resolve().parent
FONTS = Path('/usr/share/fonts/liberation')
for name, filename in [
    ('Sans', 'LiberationSans-Regular.ttf'),
    ('SansB', 'LiberationSans-Bold.ttf'),
    ('SansI', 'LiberationSans-Italic.ttf'),
    ('Mono', 'LiberationMono-Regular.ttf'),
    ('MonoB', 'LiberationMono-Bold.ttf'),
]:
    pdfmetrics.registerFont(TTFont(name, str(FONTS / filename)))
pdfmetrics.registerFontFamily('Sans', normal='Sans', bold='SansB', italic='SansI', boldItalic='SansB')
pdfmetrics.registerFontFamily('Mono', normal='Mono', bold='MonoB', italic='Mono', boldItalic='MonoB')
INK = colors.HexColor('#152534')
ACCENT = colors.HexColor('#164d67')
GRAY = colors.HexColor('#edf1f3')


def inline(s):
    parts = re.split(r'(`[^`]+`)', s)
    out = []
    for part in parts:
        if part.startswith('`') and part.endswith('`'):
            out.append('<font name="Mono">' + html.escape(part[1:-1]) + '</font>')
        else:
            part = html.escape(part)
            part = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', part)
            part = re.sub(r'(?<!\*)\*([^*]+)\*(?!\*)', r'<i>\1</i>', part)
            out.append(part)
    return ''.join(out)


def parse(text):
    lines = text.splitlines()
    blocks = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip() or line.startswith('<!--'):
            i += 1
            continue
        if line.startswith('!['):
            blocks.append(('figure', 'hardware')); i += 1
        elif line.startswith('```'):
            i += 1
            code = []
            while i < len(lines) and not lines[i].startswith('```'):
                code.append(lines[i]); i += 1
            blocks.append(('code', '\n'.join(code)))
            i += 1
        elif line.startswith('#'):
            n = len(line) - len(line.lstrip('#'))
            blocks.append(('h'+str(n), line[n:].strip())); i += 1
        elif line.startswith('|'):
            rows = []
            while i < len(lines) and lines[i].startswith('|'):
                cells = [c.strip().replace(r'\|', '|') for c in re.split(r'(?<!\\)\|', lines[i].strip().strip('|'))]
                if not all(re.fullmatch(r':?-+:?', c) for c in cells):
                    rows.append(cells)
                i += 1
            blocks.append(('table', rows))
        else:
            para = [line]
            i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith(('#', '```', '<!--', '|')):
                # List entries are kept as separate paragraphs.
                if lines[i].startswith('- ') or re.match(r'^\d+\. ', lines[i]):
                    break
                para.append(lines[i]); i += 1
            blocks.append(('p', ' '.join(para)))
    return blocks


def hardware_figure():
    d=Drawing(516,154)
    def label(x,y,s,size=8,bold=False):
        d.add(String(x,y,s,fontName='SansB' if bold else 'Sans',fontSize=size,fillColor=INK))
    def line(x1,y1,x2,y2):
        d.add(Line(x1,y1,x2,y2,strokeColor=INK,strokeWidth=.8))
    def arrow(x1,y1,x2,y2):
        line(x1,y1,x2,y2)
        d.add(Polygon([x2,y2,x2-4,y2+2,x2-4,y2-2],fillColor=INK,strokeColor=INK))
    def box(x,y,w,h,name):
        d.add(Rect(x,y,w,h,strokeColor=ACCENT,fillColor=GRAY,strokeWidth=.8))
        label(x+5,y+h/2-3,name,8,True)
    label(3,141,'Q2: latch when case 11 is unassigned',10,True)
    label(16,103,'b'); arrow(25,106,74,106);box(74,87,54,38,'LATCH')
    arrow(128,106,169,106);label(173,103,'out')
    line(101,64,101,87);label(22,50,'Enable = ~(a & b)',9)
    label(12,26,'00 / 01 / 10: transparent',8)
    label(12,13,'11: stores the previous value',8)
    label(228,141,'Q9: two DFFs with synchronous mux control',10,True)
    label(226,114,'d');label(225,89,'0')
    arrow(238,117,278,117);arrow(238,91,278,91)
    box(278,88,37,35,'MUX'); label(282,115,'1',6);label(282,91,'0',6)
    arrow(315,105,349,105);box(349,89,46,32,'DFF1')
    arrow(395,105,457,105);label(462,102,'q1')
    line(296,71,296,88);label(272,63,'rst_n',7)
    line(372,76,372,89);label(353,65,'clk ↑',7)
    line(433,105,433,57);line(433,57,253,57)
    arrow(253,57,278,57);box(278,20,37,44,'MUX');label(282,55,'1',6);label(282,23,'0',6)
    arrow(315,42,349,42);box(349,26,46,32,'DFF2')
    arrow(395,42,457,42);label(462,39,'q2')
    line(437,42,437,10);line(437,10,253,10);line(253,10,253,25);arrow(253,25,278,25)
    line(296,6,296,20);label(266,0,'rst_n',6)
    line(372,13,372,26);label(353,4,'clk ↑',7)
    return d


def cheat_flowables(blocks, scale=1, body_pt=7.25, code_pt=6.4):
    body = ParagraphStyle('sheetbody', fontName='Sans', fontSize=body_pt*scale,
                          leading=(body_pt+.9)*scale, textColor=INK, spaceAfter=2.4*scale)
    heading = ParagraphStyle('sheetheading', parent=body, fontName='SansB',
                             fontSize=(body_pt+.9)*scale, leading=(body_pt+1.85)*scale,
                             textColor=ACCENT, spaceBefore=4*scale, spaceAfter=2.2*scale)
    mono = ParagraphStyle('sheetcode', fontName='Mono', fontSize=code_pt*scale,
                          leading=(code_pt+1.05)*scale, spaceAfter=3*scale, textColor=INK)
    flows=[]
    for kind, value in blocks:
        if kind == 'code': flows.append(Preformatted(value, mono))
        elif kind.startswith('h'): flows.append(Paragraph(inline(value), heading))
        else: flows.append(Paragraph(inline(value), body))
    return flows


def measure(flows, width):
    height=0
    widths=[]
    for f in flows:
        w,h=f.wrap(width, 10000)
        widths.append(w)
        height += f.getSpaceBefore() + h + f.getSpaceAfter()
    return height, max(widths, default=0)


def build_sheet(source_name='ECE551_Midterm_Cheat_Sheet', page_count=2,
                column_count=3, body_pt=7.25, code_pt=6.4):
    source=(ROOT/(source_name+'.md')).read_text()
    chunks=re.split(r'<!-- PAGE (\d) COLUMN (\d) -->', source)
    columns=[]
    for i in range(1,len(chunks),3):
        columns.append((int(chunks[i]), int(chunks[i+1]), parse(chunks[i+2])))
    assert len(columns)==page_count*column_count
    is_code = source_name.endswith('Code_Examples')
    target=ROOT/(source_name+'.pdf')
    c=canvas.Canvas(str(target), pagesize=letter)
    c.setTitle('ECE551 Midterm Code Examples' if is_code else 'ECE551 Midterm Cheat Sheet — two pages')
    c.setAuthor('Course study guide based on local ECE551 materials')
    margin=17
    gap=8
    width=(612-2*margin-(column_count-1)*gap)/column_count
    top=748
    bottom=26
    available=top-bottom
    report=[]
    for page in range(1,page_count+1):
        c.setFillColor(INK)
        c.setFont('SansB',14)
        c.drawString(margin,773,'ECE551  /  EXAM CODE EXAMPLES' if is_code else 'ECE551  /  MIDTERM QUESTION PATTERNS')
        c.setFont('SansB',8)
        c.drawRightString(595,774, f'{page} / {page_count}')
        c.setFont('Sans',6.8)
        subtitle=({1:'Common flip-flops • hold/reset/enable/priority • latch contrast',
                   2:'Complete FSM controllers • the practice two-transaction problem',
                   3:'Steering/timers • synchronization • pattern matching',
                   4:'PWM • arithmetic • parameterized counter • simulation/testbench'}[page]
                  if is_code else ('Short questions • hardware inference • simulation' if page==1 else
                                    'FSM completion • debugging • shifters/edges • PWM • timing'))
        c.drawString(margin,761,subtitle+'   |   Q# = supplied practice midterm')
        c.setStrokeColor(ACCENT); c.setLineWidth(.7)
        c.line(margin,754,595,754)
        for p,col,blocks in columns:
            if p!=page: continue
            x=margin+(col-1)*(width+gap)
            scale=1.0
            while True:
                flows=cheat_flowables(blocks,scale,body_pt,code_pt)
                h,w=measure(flows,width)
                # Preformatted line widths must also fit explicitly.
                code_width=max([max((pdfmetrics.stringWidth(s,'Mono',code_pt*scale)
                                    for s in v.splitlines()),default=0)
                                for k,v in blocks if k=='code'],default=0)
                if h<=available and code_width<=width: break
                scale-=.005
                if scale<.83: raise ValueError(f'Overfull page {page} column {col}: {h}')
            y=top
            for f in flows:
                y-=f.getSpaceBefore()
                _,fh=f.wrap(width,available)
                f.drawOn(c,x,y-fh)
                y-=fh+f.getSpaceAfter()
            assert y>=bottom-.1
            report.append(dict(page=page,column=col,font_pt=round(body_pt*scale,3),
                               code_pt=round(code_pt*scale,3),height=round(h,2),
                               remaining=round(y-bottom,2),code_width=round(code_width,2)))
            if col<column_count:
                c.setStrokeColor(colors.HexColor('#c5cdd2')); c.setLineWidth(.3)
                c.line(x+width+gap/2,top,x+width+gap/2,bottom)
        c.setFillColor(INK);c.setFont('Sans',6)
        c.drawString(margin,14,'Practice-midterm question patterns + lecture/HW code styles; printed-key errors corrected. Print at 100% / actual size.')
        c.showPage()
    c.save()
    if is_code:
        modules=[]
        for block in re.findall(r'```systemverilog\n(.*?)\n```',source,re.S):
            if re.search(r'^module\b',block,re.M):
                modules.append(block)
        (ROOT/'ECE551_Example_Modules.sv').write_text(
            '// Complete modules extracted from ECE551_Midterm_Code_Examples.md.\n'
            '// Alternative fragments and the external SPI master are not included.\n\n'
            +'\n\n'.join(modules)+'\n')
    report_name='code_examples_layout_report.json' if is_code else 'layout_report.json'
    (ROOT/'validation'/report_name).write_text(json.dumps(report,indent=2))
    print(source_name, json.dumps(report,indent=2))


def build_course():
    width=516
    body=ParagraphStyle('body', fontName='Sans', fontSize=10.3, leading=13.6,
                        textColor=INK, spaceAfter=7)
    h1=ParagraphStyle('title', parent=body, fontName='SansB', fontSize=21, leading=25,
                     textColor=ACCENT, spaceAfter=14)
    h2=ParagraphStyle('section', parent=body, fontName='SansB', fontSize=14, leading=17,
                     textColor=ACCENT, spaceBefore=11, spaceAfter=7, keepWithNext=True)
    mono=ParagraphStyle('code',fontName='Mono',fontSize=8.15,leading=10.4,
                        textColor=INK,spaceBefore=3,spaceAfter=8,leftIndent=7)
    cell=ParagraphStyle('cell',parent=body,fontSize=8.6,leading=10.6,spaceAfter=0)
    story=[]
    for kind,value in parse((ROOT/'ECE551_Crash_Course.md').read_text()):
        if kind=='h1': story.append(Paragraph(inline(value),h1))
        elif kind.startswith('h'): story.append(Paragraph(inline(value),h2))
        elif kind=='figure':
            drawing=hardware_figure()
            renderSVG.drawToFile(drawing,str(ROOT/'ECE551_Hardware_Inference.svg'))
            story.extend([drawing,Spacer(1,9)])
        elif kind=='code':
            # Reduce code only if an unusually long line requires it.
            maxwidth=max((pdfmetrics.stringWidth(s,'Mono',8.15) for s in value.splitlines()),default=0)
            code_style=mono
            if maxwidth>width-12:
                ratio=(width-12)/maxwidth
                code_style=ParagraphStyle('narrowcode',parent=mono,fontSize=8.15*ratio,leading=10.4*ratio)
            story.append(Preformatted(value,code_style))
        elif kind=='table':
            n=len(value[0])
            assert all(len(row)==n for row in value), 'Malformed table'
            if n==3: proportions=[.21,.51,.28]
            elif n==2: proportions=[.18,.82]
            elif n==4: proportions=[.26,.25,.25,.24]
            else: proportions=[.34]+[.66/(n-1)]*(n-1)
            rows=[[Paragraph(inline(s),cell) for s in row] for row in value]
            t=Table(rows,colWidths=[width*r for r in proportions],repeatRows=1,hAlign='LEFT')
            t.setStyle(TableStyle([
                ('BACKGROUND',(0,0),(-1,0),GRAY),('VALIGN',(0,0),(-1,-1),'TOP'),
                ('LINEBELOW',(0,0),(-1,0),.6,ACCENT),
                ('LINEBELOW',(0,1),(-1,-1),.25,colors.HexColor('#d2d9de')),
                ('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),
                ('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5),
            ]))
            story.extend([t,Spacer(1,9)])
        else: story.append(Paragraph(inline(value),body))
    def decoration(c,doc):
        c.saveState()
        c.setFont('Sans',8); c.setFillColor(ACCENT)
        c.drawString(48,768,'ECE551  /  CRASH COURSE AND WORKED EXAM PATTERNS')
        c.setStrokeColor(colors.HexColor('#b7c6ce'));c.setLineWidth(.4)
        c.line(48,760,564,760)
        c.setFont('Sans',8)
        c.drawString(48,23,'Fall 2026 folder materials • Spring 2020 practice exam used for priorities')
        c.drawRightString(564,23,str(doc.page))
        c.restoreState()
    doc=SimpleDocTemplate(str(ROOT/'ECE551_Crash_Course.pdf'),pagesize=letter,
                          leftMargin=48,rightMargin=48,topMargin=46,bottomMargin=42,
                          title='ECE551 Crash Course and Worked Exam Patterns',author='ECE551 study guide')
    doc.build(story,onFirstPage=decoration,onLaterPages=decoration)


if __name__=='__main__':
    build_sheet()
    build_sheet('ECE551_Midterm_Code_Examples',4,2,9.2,8.2)
    build_course()

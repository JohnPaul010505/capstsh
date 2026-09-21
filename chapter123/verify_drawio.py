
import xml.etree.ElementTree as ET
import os

FIG_DIR = r'c:\capstsh'
FIGS = [
    'Activity-Fig15-Member-Login-Registration.drawio',
    'Activity-Fig16-Workout-Logging.drawio',
    'Activity-Fig17-QR-CheckIn-CheckOut.drawio',
    'Activity-Fig18-Meal-Logging-AI-Analysis.drawio',
    'Activity-Fig19-Dashboard-View.drawio',
    'Activity-Fig20-Trainer-Feedback-Rating.drawio',
    'Activity-Fig21-Goal-Setting-Plan-Creation.drawio',
]

def local(tag):
    return tag.split('}'}[-1] if '}' in tag else tag

def cells(root):
    return [e for e in root.iter() if local(e.tag) == 'mxCell'

for fname in FIGS:
    path = os.path.join(FIG_DIR, fname)
    print(chr(10) + 'FILE: ' + fname)
    try:
        tree = ET.parse(path)
        root = tree.getroot()
        print('  [XML OK]')
    except ET.ParseError as e:
        print('  [XML ERROR] ' + str(e))
        continue

    all_c = cells(root)
    nd = [c for c in all_c if c.get('vertex') == '1']
    ed = [c for c in all_c if c.get('edge') == '1']
    print('  cells total: ' + str(len(all_c)))
    print('  nodes: ' + str(len(nd)))
    print('  edges: ' + str(len(ed)))

    frame = [c for c in nd
             if c.get('shape') == 'rectangle'
             and c.get('strokeColor') == '#000000'
             and c.get('fill') in ('none', '#ffffff', '')]
    print('  pool frames: ' + str(len(frame)))

    dividers = [c for c in all_c if 'shape=line' in (c.get('style') or '')]
    print('  divider lines: ' + str(len(dividers)))

    start_end_ellipses = [c for c in nd
                          if 'ellipse' in (c.get('style') or '')
                          and c.get('strokeColor') == '#000000']
    print('  start/end ellipses: ' + str(len(start_end_ellipses)))

    bold_vals = []
    for c in nd:
        v = (c.get('value') or '').strip()
        if v and c.get('fontStyle') == '1':
            bold_vals.append(v)
    print('  bold labels: ' + str(len(bold_vals)) + ' -> ' + str(bold_vals))

    yes = [c for c in ed if 'Yes' in (c.get('value') or '')]
    no  = [c for c in ed if 'No'  in (c.get('value') or '')]
    print('  Yes edges: ' + str(len(yes)))
    print('  No edges:  ' + str(len(no)))

    has_start = any((c.get('value') or '').lower().startswith('start') for c in nd)
    has_end   = any((c.get('value') or '').lower().startswith('end')   for c in nd)
    ok = len(frame) >= 1 and len(dividers) >= 1 and has_start and has_end
    print('  SWIMLANE CHECK PASS: ' + str(ok))
    print('-' * 70)

cap = os.path.join(FIG_DIR, 'Activity-Captions-and-Narratives.md')
print(chr(10) + 'CAPTIONS FILE: exists=' + str(os.path.exists(cap)) + ' size=' + str(os.path.getsize(cap)) + ' bytes')

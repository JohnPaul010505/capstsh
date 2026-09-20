# generate_dfd.py
# Generates Gane-Sarson Data Flow Diagrams as single-page draw.io files.
import xml.etree.ElementTree as ET
import os

FONT = 'Times New Roman'

STY_ENT    = ('rounded=0;whiteSpace=wrap;html=1;fontFamily=%s;fontSize=13;fontStyle=1;'
              'fillColor=#FFFFFF;strokeColor=#000000;' % FONT)
STY_PROC   = ('rounded=1;arcSize=8;whiteSpace=wrap;html=1;fillColor=#FFFFFF;'
              'strokeColor=#000000;')
STY_PROC_N = ('text;html=1;align=center;verticalAlign=middle;fontFamily=%s;fontSize=12;'
              'fontStyle=1;strokeColor=none;fillColor=none;' % FONT)
STY_PROC_T = ('text;html=1;align=center;verticalAlign=middle;fontFamily=%s;fontSize=12;'
              'fontStyle=1;strokeColor=none;fillColor=none;' % FONT)
STY_TXT    = ('text;html=1;align=center;verticalAlign=middle;fontFamily=%s;fontSize=13;'
              'fontStyle=1;strokeColor=none;fillColor=none;' % FONT)
STY_TITLE  = ('text;html=1;align=left;verticalAlign=middle;fontFamily=%s;fontSize=16;'
              'fontStyle=1;strokeColor=none;fillColor=none;' % FONT)
STY_CAP    = ('text;html=1;align=center;verticalAlign=middle;fontFamily=%s;fontSize=13;'
              'fontStyle=1;strokeColor=none;fillColor=none;' % FONT)
STY_STORE  = ('rounded=0;whiteSpace=wrap;html=1;fontFamily=%s;fontSize=12;fontStyle=1;'
              'fillColor=#FFFFFF;strokeColor=#000000;align=left;spacingLeft=48;' % FONT)
STY_STORE_I = ('text;html=1;align=center;verticalAlign=middle;fontFamily=%s;fontSize=12;'
               'fontStyle=1;strokeColor=none;fillColor=none;' % FONT)
STY_EDGE   = ('edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=classic;endFill=1;'
              'fontFamily=%s;fontSize=11;fontStyle=1;labelBackgroundColor=#FFFFFF;'
              'strokeColor=#000000;' % FONT)
STY_LINE_H = 'line;strokeWidth=1;html=1;strokeColor=#000000;'
STY_LINE_V = 'line;strokeWidth=1;html=1;strokeColor=#000000;direction=north;'

PROC_DIV_Y = 26.0
STORE_DIV_X = 38.0


def build(d):
    mx = ET.Element('mxfile', {'host': 'app.diagrams.net', 'agent': 'Cline',
                               'version': '24.7.17', 'type': 'device'})
    diag = ET.SubElement(mx, 'diagram', {'id': d['id'], 'name': d['name']})
    model = ET.SubElement(diag, 'mxGraphModel', {
        'dx': '1600', 'dy': '1000', 'grid': '1', 'gridSize': '10', 'guides': '1',
        'tooltips': '1', 'connect': '1', 'arrows': '1', 'fold': '1', 'page': '1',
        'pageScale': '1', 'pageWidth': str(d['pw']), 'pageHeight': str(d['ph']),
        'math': '0', 'shadow': '0'})
    root = ET.SubElement(model, 'root')
    ET.SubElement(root, 'mxCell', {'id': '0'})
    ET.SubElement(root, 'mxCell', {'id': '1', 'parent': '0'})

    geo = {}
    cellmap = {}
    seq = [0]

    def nid():
        seq[0] += 1
        return 'c%d' % seq[0]

    def cell(val, style, x=None, y=None, w=None, h=None):
        cid = nid()
        c = ET.SubElement(root, 'mxCell', {'id': cid, 'value': val, 'style': style,
                                           'vertex': '1', 'parent': '1'})
        g = {'as': 'geometry'}
        if x is not None:
            g['x'] = str(x)
            g['y'] = str(y)
            g['width'] = str(w)
            g['height'] = str(h)
        ET.SubElement(c, 'mxGeometry', g)
        return cid

    if d.get('title'):
        cell(d['title'], STY_TITLE, 40, 16, 460, 28)
    if d.get('sub'):
        cell(d['sub'], STY_TITLE, 40, 46, 260, 24)
    if d.get('cap'):
        cell(d['cap'], STY_CAP, 200, d['ph'] - 60, d['pw'] - 400, 30)

    for n in d['nodes']:
        kind = n[1]
        if kind == 'ent':
            _, _, x, y, w, h, label = n
            cellmap[n[0]] = cell(label, STY_ENT, x, y, w, h)
            geo[n[0]] = (x, y, w, h)
        elif kind == 'proc':
            _, _, x, y, w, h, num, label = n
            cellmap[n[0]] = cell('', STY_PROC, x, y, w, h)
            cell(num, STY_PROC_N, x + 6, y + 4, w - 12, 20)
            cell(label, STY_PROC_T, x + 6, y + PROC_DIV_Y + 6, w - 12,
                 h - PROC_DIV_Y - 10)
            cell('', STY_LINE_H, x, y + PROC_DIV_Y, w, 1)
            geo[n[0]] = (x, y, w, h)
        elif kind == 'store':
            _, _, x, y, w, h, sid, label = n
            cellmap[n[0]] = cell(label, STY_STORE, x, y, w, h)
            cell(sid, STY_STORE_I, x, y, STORE_DIV_X, h)
            cell('', STY_LINE_V, x + STORE_DIV_X, y, 1, h)
            geo[n[0]] = (x, y, w, h)

    edges = d['edges']
    tot = {}
    for e in edges:
        tot[e[0]] = tot.get(e[0], 0) + 1
        tot[e[1]] = tot.get(e[1], 0) + 1
    idx = {}
    for e in edges:
        s, t, label = e[0], e[1], e[2]
        idx[s] = idx.get(s, 0) + 1
        idx[t] = idx.get(t, 0) + 1
        if len(e) >= 7:
            ex, ey, ix, iy = e[3], e[4], e[5], e[6]
        else:
            ex, ey, ix, iy = _anchor(s, t, idx[s] - 1, tot[s], idx[t] - 1, tot[t], geo)
        style = STY_EDGE + ('exitX=%s;exitY=%s;exitDx=0;exitDy=0;'
                            'entryX=%s;entryY=%s;entryDx=0;entryDy=0;'
                            % (ex, ey, ix, iy))
        c = ET.SubElement(root, 'mxCell', {'id': nid(), 'value': label, 'style': style,
                                           'edge': '1', 'parent': '1',
                                           'source': cellmap[s], 'target': cellmap[t]})
        ET.SubElement(c, 'mxGeometry', {'relative': '1', 'as': 'geometry'})
    ET.indent(mx, space='  ')
    return mx


def write(d, outdir='.'):
    path = os.path.join(outdir, d['file'])
    ET.ElementTree(build(d)).write(path, encoding='unicode', xml_declaration=True)
    return path


EXISTING = 'EXISTING'
PROPOSED = 'PROPOSED'

D = []

# ---------------------------------------------------------------- FIGURE 5
D.append({
    'id': 'fig05', 'name': 'FIG 5 - EXISTING OVERALL',
    'file': 'DFD-Fig05-Existing-Overall.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'EXISTING',
    'cap': 'Figure 5: Data Flow Diagram of Existing System',
    'pw': 1400, 'ph': 1050,
    'nodes': [
        ('MEMBER', 'ent', 70, 110, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 430, 210, 110, 'TRAINER / STAFF'),
        ('P10', 'proc', 470, 90, 340, 130, '1.0', 'Record Fitness Data'),
        ('P20', 'proc', 470, 420, 340, 130, '2.0', 'Review Fitness Records'),
        ('P30', 'proc', 470, 750, 340, 130, '3.0', 'Evaluate Progress'),
        ('D1', 'store', 1000, 95, 300, 58, 'D1', 'Workout Log Sheet'),
        ('D2', 'store', 1000, 175, 300, 58, 'D2', 'Body Measurement Record'),
        ('D3', 'store', 1000, 255, 300, 58, 'D3', 'Calorie Estimate Sheet'),
        ('D4', 'store', 1000, 440, 300, 58, 'D4', 'Trainer Feedback Notes'),
        ('D5', 'store', 1000, 770, 300, 58, 'D5', 'Progress Assessment'),
    ],
    'edges': [
        ('MEMBER', 'P10', 'Workout Entry (exercise, sets, reps)'),
        ('MEMBER', 'P10', 'Body Measurements (height, weight)'),
        ('MEMBER', 'P10', 'Calorie Intake Estimate'),
        ('P10', 'D1', 'Workout Record'),
        ('P10', 'D2', 'Measurement Record'),
        ('P10', 'D3', 'Calorie Estimate Record'),
        ('D1', 'P20', 'Recorded Log Entries'),
        ('MEMBER', 'P20', 'Review Request'),
        ('P20', 'D4', 'Feedback Notes'),
        ('TRAINER', 'P20', 'Written Notes'),
        ('P20', 'MEMBER', 'Verbal Advice'),
        ('P20', 'MEMBER', 'Suggested Adjustments'),
        ('P20', 'P30', 'Reviewed Findings'),
        ('TRAINER', 'P30', 'Observation'),
        ('P30', 'D5', 'Progress Assessment'),
        ('P30', 'MEMBER', 'Logging Consistency Result'),
        ('MEMBER', 'P30', 'Satisfaction Response'),
    ],
})

# ---------------------------------------------------------------- FIGURE 6
D.append({
    'id': 'fig06', 'name': 'FIG 6 - EXISTING PROCESS 1',
    'file': 'DFD-Fig06-Existing-Process1.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'EXISTING - PROCESS 1.0',
    'cap': 'Figure 6: Data Flow Diagram of Process 1 (Existing)',
    'pw': 1400, 'ph': 900,
    'nodes': [
        ('MEMBER', 'ent', 70, 110, 210, 110, 'MEMBER'),
        ('P11', 'proc', 470, 90, 340, 120, '1.1', 'Record Workout Entry'),
        ('P12', 'proc', 470, 290, 340, 120, '1.2', 'Record Body Measurements'),
        ('P13', 'proc', 470, 490, 340, 120, '1.3', 'Estimate Calorie Intake'),
        ('D1', 'store', 1000, 95, 300, 58, 'D1', 'Workout Log Sheet'),
        ('D2', 'store', 1000, 300, 300, 58, 'D2', 'Body Measurement Record'),
        ('D3', 'store', 1000, 500, 300, 58, 'D3', 'Calorie Estimate Sheet'),
    ],
    'edges': [
        ('MEMBER', 'P11', 'Workout Entry (exercise, sets, reps)'),
        ('MEMBER', 'P12', 'Body Measurements (height, weight)'),
        ('MEMBER', 'P13', 'Calorie Intake Estimate'),
        ('P11', 'D1', 'Workout Record'),
        ('P12', 'D2', 'Measurement Record'),
        ('P13', 'D3', 'Calorie Estimate Record'),
        ('P11', 'P12', 'Workout Entry Summary'),
        ('P12', 'P13', 'Measurement Summary'),
    ],
})

# ---------------------------------------------------------------- FIGURE 7
D.append({
    'id': 'fig07', 'name': 'FIG 7 - EXISTING PROCESS 2',
    'file': 'DFD-Fig07-Existing-Process2.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'EXISTING - PROCESS 2.0',
    'cap': 'Figure 7: Data Flow Diagram of Process 2 (Existing)',
    'pw': 1400, 'ph': 1150,
    'nodes': [
        ('MEMBER', 'ent', 70, 110, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 700, 210, 110, 'TRAINER / STAFF'),
        ('P21', 'proc', 470, 90, 340, 120, '2.1', 'Submit Log Sheet to Trainer'),
        ('P22', 'proc', 470, 290, 340, 120, '2.2', 'Check Trainer Availability'),
        ('P23', 'proc', 470, 490, 340, 120, '2.3', 'Review Records Manually'),
        ('P24', 'proc', 470, 690, 340, 120, '2.4', 'Provide Verbal Feedback'),
        ('D1', 'store', 1000, 95, 300, 58, 'D1', 'Workout Log Sheet'),
        ('D4', 'store', 1000, 500, 300, 58, 'D4', 'Trainer Feedback Notes'),
    ],
    'edges': [
        ('MEMBER', 'P21', 'Log Sheet / Review Request'),
        ('D1', 'P21', 'Recorded Entries'),
        ('P21', 'P22', 'Submitted Log Sheet'),
        ('TRAINER', 'P22', 'Availability Response'),
        ('P22', 'P23', 'Records for Review'),
        ('P23', 'D4', 'Review Notes'),
        ('P23', 'P24', 'Reviewed Findings'),
        ('TRAINER', 'P24', 'Written Notes'),
        ('P24', 'MEMBER', 'Verbal Advice'),
        ('P24', 'MEMBER', 'Suggested Adjustments'),
    ],
})

# ---------------------------------------------------------------- FIGURE 8
D.append({
    'id': 'fig08', 'name': 'FIG 8 - EXISTING PROCESS 3',
    'file': 'DFD-Fig08-Existing-Process3.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'EXISTING - PROCESS 3.0',
    'cap': 'Figure 8: Data Flow Diagram of Process 3 (Existing)',
    'pw': 1400, 'ph': 1150,
    'nodes': [
        ('MEMBER', 'ent', 70, 110, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 700, 210, 110, 'TRAINER / STAFF'),
        ('P31', 'proc', 470, 90, 340, 120, '3.1', 'Check Logging Consistency'),
        ('P32', 'proc', 470, 290, 340, 120, '3.2', 'Apply Advice Without Monitoring'),
        ('P33', 'proc', 470, 490, 340, 120, '3.3', 'Assess Member Satisfaction'),
        ('P34', 'proc', 470, 690, 340, 120, '3.4', 'Decide Continuation or Abandonment'),
        ('D1', 'store', 1000, 95, 300, 58, 'D1', 'Workout Log Sheet'),
        ('D5', 'store', 1000, 500, 300, 58, 'D5', 'Progress Assessment'),
    ],
    'edges': [
        ('MEMBER', 'P31', 'Weekly Log Check'),
        ('D1', 'P31', 'Recorded Entries'),
        ('P31', 'P32', 'Consistency Result'),
        ('TRAINER', 'P32', 'Observation Notes'),
        ('P32', 'P33', 'Applied Advice Record'),
        ('MEMBER', 'P33', 'Satisfaction Response'),
        ('P33', 'P34', 'Satisfaction Result'),
        ('P34', 'D5', 'Progress Assessment'),
        ('P34', 'MEMBER', 'Continue / Abandon Decision'),
    ],
})

# ---------------------------------------------------------------- FIGURE 9
D.append({
    'id': 'fig09', 'name': 'FIG 9 - PROPOSED OVERALL',
    'file': 'DFD-Fig09-Proposed-Overall.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'PROPOSED',
    'cap': 'Figure 9: Data Flow Diagram of Proposed System',
    'pw': 1600, 'ph': 1300,
    'nodes': [
        ('MEMBER', 'ent', 70, 110, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 430, 210, 110, 'TRAINER'),
        ('ADMIN', 'ent', 70, 760, 210, 110, 'ADMIN'),
        ('GEMINI', 'ent', 70, 1050, 210, 110, 'GOOGLE GEMINI API'),
        ('P10', 'proc', 520, 100, 360, 120, '1.0', 'Manage Accounts and Attendance'),
        ('P20', 'proc', 520, 300, 360, 120, '2.0', 'Manage Workout and Measurements'),
        ('P30', 'proc', 520, 500, 360, 120, '3.0', 'Manage Nutrition and AI Food Analysis'),
        ('P40', 'proc', 520, 700, 360, 120, '4.0', 'Generate Predictions and Goal Plans'),
        ('P50', 'proc', 520, 900, 360, 120, '5.0', 'Generate Reports and Communication'),
        ('D1', 'store', 1180, 100, 320, 56, 'D1', 'User Profiles'),
        ('D2', 'store', 1180, 168, 320, 56, 'D2', 'Enrollment and Assignment Records'),
        ('D3', 'store', 1180, 236, 320, 56, 'D3', 'Check-In and Attendance Records'),
        ('D4', 'store', 1180, 304, 320, 56, 'D4', 'Workout Logs'),
        ('D5', 'store', 1180, 372, 320, 56, 'D5', 'Body Measurements'),
        ('D6', 'store', 1180, 440, 320, 56, 'D6', 'MET Exercise Catalog'),
        ('D7', 'store', 1180, 508, 320, 56, 'D7', 'Meal Logs'),
        ('D8', 'store', 1180, 576, 320, 56, 'D8', 'Nutrition Foods'),
        ('D9', 'store', 1180, 644, 320, 56, 'D9', 'AI Food Analysis'),
        ('D10', 'store', 1180, 712, 320, 56, 'D10', 'Predictions'),
        ('D11', 'store', 1180, 780, 320, 56, 'D11', 'Goal Plans'),
        ('D12', 'store', 1180, 848, 320, 56, 'D12', 'Notifications and Chat'),
        ('D13', 'store', 1180, 916, 320, 56, 'D13', 'Trainer Feedback'),
        ('D14', 'store', 1180, 984, 320, 56, 'D14', 'Admin Logs'),
    ],
    'edges': [
        ('MEMBER', 'P10', 'Registration Details'),
        ('MEMBER', 'P10', 'QR Check-In / Check-Out'),
        ('P10', 'MEMBER', 'Account Confirmation'),
        ('P10', 'MEMBER', 'Notification'),
        ('ADMIN', 'P10', 'Enrollment Details'),
        ('ADMIN', 'P10', 'Trainer Assignment'),
        ('P10', 'ADMIN', 'Attendance Record'),
        ('TRAINER', 'P10', 'Session Attendance'),
        ('P10', 'TRAINER', 'Assigned Member List'),
        ('P10', 'D1', 'Profile Record'),
        ('D1', 'P10', 'Member and Trainer Profile'),
        ('P10', 'D2', 'Enrollment / Assignment Record'),
        ('P10', 'D3', 'Check-In Record'),
        ('P10', 'D12', 'Notification Record'),
        ('MEMBER', 'P20', 'Workout Entry (exercise, sets, reps)'),
        ('MEMBER', 'P20', 'Body Measurement Entry'),
        ('P20', 'MEMBER', 'Calories Burned (MET)'),
        ('P20', 'MEMBER', 'BMI Result'),
        ('P20', 'D4', 'Workout Record'),
        ('D4', 'P20', 'Workout History'),
        ('P20', 'D5', 'Measurement Record'),
        ('D6', 'P20', 'MET Value'),
        ('TRAINER', 'P20', 'MET Verification'),
        ('P20', 'TRAINER', 'Member Workout Summary'),
        ('MEMBER', 'P30', 'Meal Log Entry'),
        ('MEMBER', 'P30', 'Food Photograph'),
        ('P30', 'MEMBER', 'Food Recommendation'),
        ('P30', 'MEMBER', 'Nutrient Breakdown'),
        ('P30', 'D7', 'Meal Record'),
        ('D7', 'P30', 'Meal History'),
        ('D8', 'P30', 'Food Composition Data'),
        ('P30', 'D9', 'AI Analysis Result'),
        ('P30', 'GEMINI', 'Food Image / Nutrition Query'),
        ('GEMINI', 'P30', 'Recognized Food Item'),
        ('GEMINI', 'P30', 'Nutrient Breakdown Data'),
    ],
})
D[-1]['edges'].extend([
    ('MEMBER', 'P40', 'Goal Setting'),
    ('P40', 'MEMBER', 'Predicted Progress'),
    ('P40', 'MEMBER', 'Adjusted Goal Suggestion'),
    ('TRAINER', 'P40', 'Plan Assignment'),
    ('P40', 'TRAINER', 'Retention Risk Alert'),
    ('P40', 'TRAINER', 'Plan Completion Status'),
    ('D4', 'P40', 'Workout History Data'),
    ('D5', 'P40', 'Measurement History Data'),
    ('D7', 'P40', 'Nutrition History Data'),
    ('P40', 'D10', 'Prediction Record'),
    ('P40', 'D11', 'Goal Plan Record'),
    ('MEMBER', 'P50', 'Chat Message'),
    ('MEMBER', 'P50', 'Trainer Rating'),
    ('P50', 'MEMBER', 'Progress Report'),
    ('TRAINER', 'P50', 'Chat Message'),
    ('TRAINER', 'P50', 'Member Feedback'),
    ('P50', 'TRAINER', 'Member Report'),
    ('ADMIN', 'P50', 'Report Request'),
    ('ADMIN', 'P50', 'Broadcast Content'),
    ('P50', 'ADMIN', 'Analytics Report'),
    ('P50', 'ADMIN', 'Inactive Member Alert'),
    ('P50', 'D12', 'Chat / Notification Record'),
    ('D13', 'P50', 'Feedback Record'),
    ('P50', 'D13', 'Trainer Feedback Record'),
    ('P50', 'D14', 'Admin Log'),
])



def _frac(i, n):
    if n <= 1:
        return 0.5
    return round(0.10 + 0.80 * (i / float(n - 1)), 3)


def _anchor(src, tgt, es, ts, et, tt, geo):
    s = geo[src]
    t = geo[tgt]
    s_x2 = s[0] + s[2]
    t_x2 = t[0] + t[2]
    if s[0] < t_x2 and t[0] < s_x2:
        if s[1] < t[1]:
            return (0.5, 1.0, 0.5, 0.0)
        return (0.5, 0.0, 0.5, 1.0)
    if s_x2 <= t[0]:
        ex, ix = 1.0, 0.0
    else:
        ex, ix = 0.0, 1.0
    return (ex, _frac(es, ts), ix, _frac(et, tt))


# ---------------------------------------------------------------- FIGURE 10
D.append({
    'id': 'fig10', 'name': 'FIG 10 - PROPOSED PROCESS 1',
    'file': 'DFD-Fig10-Proposed-Process1.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'PROPOSED - PROCESS 1.0',
    'cap': 'Figure 10: Data Flow Diagram of Process 1 (Proposed)',
    'pw': 1400, 'ph': 1750,
    'nodes': [
        ('ADMIN', 'ent', 70, 90, 210, 110, 'ADMIN'),
        ('MEMBER', 'ent', 70, 330, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 600, 210, 110, 'TRAINER'),
        ('P11', 'proc', 470, 90, 340, 120, '1.1', 'Maintain Member Account'),
        ('P12', 'proc', 470, 240, 340, 120, '1.2', 'Maintain Trainer Account'),
        ('P13', 'proc', 470, 390, 340, 120, '1.3', 'Assign Trainer to Member'),
        ('P14', 'proc', 470, 540, 340, 120, '1.4', 'Maintain Enrollment Record'),
        ('P15', 'proc', 470, 690, 340, 120, '1.5', 'Record QR Check-In / Check-Out'),
        ('P16', 'proc', 470, 840, 340, 120, '1.6', 'Generate Attendance Record'),
        ('P17', 'proc', 470, 990, 340, 120, '1.7', 'Send Notification'),
        ('D1', 'store', 1000, 90, 300, 56, 'D1', 'User Profiles'),
        ('D2', 'store', 1000, 250, 300, 56, 'D2', 'Enrollment and Assignment Records'),
        ('D3', 'store', 1000, 700, 300, 56, 'D3', 'Check-In and Attendance Records'),
        ('D12', 'store', 1000, 990, 300, 56, 'D12', 'Notifications and Chat'),
    ],
    'edges': [
        ('ADMIN', 'P11', 'Member Account Details'),
        ('MEMBER', 'P11', 'Registration Details'),
        ('P11', 'D1', 'Member Profile Record'),
        ('D1', 'P11', 'Member Profile'),
        ('ADMIN', 'P12', 'Trainer Account Details'),
        ('P12', 'D1', 'Trainer Profile Record'),
        ('D1', 'P12', 'Trainer Profile'),
        ('ADMIN', 'P13', 'Trainer Assignment'),
        ('TRAINER', 'P13', 'Specialty and Availability'),
        ('P13', 'D2', 'Assignment Record'),
        ('D2', 'P13', 'Assignment Record'),
        ('ADMIN', 'P14', 'Enrollment Details'),
        ('MEMBER', 'P14', 'Membership Details'),
        ('P14', 'D2', 'Enrollment Record'),
        ('MEMBER', 'P15', 'QR Code Scan'),
        ('P15', 'D3', 'Check-In / Check-Out Record'),
        ('D3', 'P16', 'Check-In Data'),
        ('P16', 'D3', 'Attendance Record'),
        ('P16', 'D12', 'Attendance Notification'),
        ('P17', 'D12', 'Notification Record'),
        ('P17', 'MEMBER', 'Notification'),
        ('P17', 'TRAINER', 'Notification'),
    ],
})

# ---------------------------------------------------------------- FIGURE 11
D.append({
    'id': 'fig11', 'name': 'FIG 11 - PROPOSED PROCESS 2',
    'file': 'DFD-Fig11-Proposed-Process2.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'PROPOSED - PROCESS 2.0',
    'cap': 'Figure 11: Data Flow Diagram of Process 2 (Proposed)',
    'pw': 1400, 'ph': 1600,
    'nodes': [
        ('MEMBER', 'ent', 70, 90, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 700, 210, 110, 'TRAINER'),
        ('P21', 'proc', 470, 90, 340, 120, '2.1', 'Record Workout Log'),
        ('P22', 'proc', 470, 240, 340, 120, '2.2', 'Estimate Calories Burned (MET)'),
        ('P23', 'proc', 470, 390, 340, 120, '2.3', 'Maintain Exercise Catalog'),
        ('P24', 'proc', 470, 540, 340, 120, '2.4', 'Record Body Measurements'),
        ('P25', 'proc', 470, 690, 340, 120, '2.5', 'Compute BMI'),
        ('P26', 'proc', 470, 840, 340, 120, '2.6', 'View Workout and BMI History'),
        ('D4', 'store', 1000, 90, 300, 56, 'D4', 'Workout Logs'),
        ('D5', 'store', 1000, 550, 300, 56, 'D5', 'Body Measurements'),
        ('D6', 'store', 1000, 390, 300, 56, 'D6', 'MET Exercise Catalog'),
    ],
    'edges': [
        ('MEMBER', 'P21', 'Workout Entry (exercise, sets, reps)'),
        ('P21', 'D4', 'Workout Record'),
        ('D4', 'P21', 'Workout History'),
        ('P21', 'P22', 'Workout Entry Data'),
        ('D6', 'P22', 'MET Value'),
        ('P22', 'MEMBER', 'Calories Burned (MET)'),
        ('P22', 'D4', 'Total Calories Record'),
        ('TRAINER', 'P23', 'Exercise Verification'),
        ('P23', 'D6', 'Exercise Catalog Record'),
        ('D6', 'P23', 'Exercise Catalog'),
        ('MEMBER', 'P24', 'Body Measurement Entry'),
        ('P24', 'D5', 'Measurement Record'),
        ('D5', 'P24', 'Measurement History'),
        ('P24', 'P25', 'Measurement Data'),
        ('P25', 'MEMBER', 'BMI Result'),
        ('P25', 'D5', 'BMI Record'),
        ('P26', 'MEMBER', 'Workout and BMI History'),
        ('D4', 'P26', 'Workout History Data'),
        ('D5', 'P26', 'Measurement History Data'),
    ],
})

# ---------------------------------------------------------------- FIGURE 12
D.append({
    'id': 'fig12', 'name': 'FIG 12 - PROPOSED PROCESS 3',
    'file': 'DFD-Fig12-Proposed-Process3.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'PROPOSED - PROCESS 3.0',
    'cap': 'Figure 12: Data Flow Diagram of Process 3 (Proposed)',
    'pw': 1400, 'ph': 1600,
    'nodes': [
        ('MEMBER', 'ent', 70, 90, 210, 110, 'MEMBER'),
        ('GEMINI', 'ent', 70, 700, 210, 110, 'GOOGLE GEMINI API'),
        ('P31', 'proc', 470, 90, 340, 120, '3.1', 'Record Meal Log'),
        ('P32', 'proc', 470, 240, 340, 120, '3.2', 'Upload Food Photograph'),
        ('P33', 'proc', 470, 390, 340, 120, '3.3', 'Identify Food Item (Gemini)'),
        ('P34', 'proc', 470, 540, 340, 120, '3.4', 'Compute Nutrient Breakdown'),
        ('P35', 'proc', 470, 690, 340, 120, '3.5', 'Generate Food Recommendation'),
        ('P36', 'proc', 470, 840, 340, 120, '3.6', 'Maintain Nutrition Database'),
        ('D7', 'store', 1000, 90, 300, 56, 'D7', 'Meal Logs'),
        ('D8', 'store', 1000, 550, 300, 56, 'D8', 'Nutrition Foods'),
        ('D9', 'store', 1000, 690, 300, 56, 'D9', 'AI Food Analysis'),
    ],
    'edges': [
        ('MEMBER', 'P31', 'Meal Entry (food name, calories)'),
        ('P31', 'D7', 'Meal Record'),
        ('D7', 'P31', 'Meal History'),
        ('MEMBER', 'P32', 'Food Photograph'),
        ('P32', 'D7', 'Meal Photo Record'),
        ('P32', 'P33', 'Food Image'),
        ('GEMINI', 'P33', 'Recognized Food Item'),
        ('P33', 'GEMINI', 'Food Image / Nutrition Query'),
        ('P33', 'D9', 'Food Identification Record'),
        ('P33', 'P34', 'Identified Food Data'),
        ('D8', 'P34', 'Food Composition Data'),
        ('P34', 'MEMBER', 'Nutrient Breakdown'),
        ('P34', 'D9', 'Nutrient Analysis Record'),
        ('P34', 'P35', 'Nutrient Data'),
        ('P35', 'MEMBER', 'Food Recommendation'),
        ('P35', 'D9', 'Recommendation Record'),
        ('D8', 'P36', 'Food Composition Data'),
        ('P36', 'D8', 'Nutrition Database Record'),
    ],
})

# ---------------------------------------------------------------- FIGURE 13
D.append({
    'id': 'fig13', 'name': 'FIG 13 - PROPOSED PROCESS 4',
    'file': 'DFD-Fig13-Proposed-Process4.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'PROPOSED - PROCESS 4.0',
    'cap': 'Figure 13: Data Flow Diagram of Process 4 (Proposed)',
    'pw': 1400, 'ph': 1750,
    'nodes': [
        ('MEMBER', 'ent', 70, 90, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 850, 210, 110, 'TRAINER'),
        ('P41', 'proc', 470, 90, 340, 120, '4.1', 'Analyze Progress Trend'),
        ('P42', 'proc', 470, 240, 340, 120, '4.2', 'Predict Fitness Progress'),
        ('P43', 'proc', 470, 390, 340, 120, '4.3', 'Assess Retention Risk'),
        ('P44', 'proc', 470, 540, 340, 120, '4.4', 'Generate Goal Adjustment'),
        ('P45', 'proc', 470, 690, 340, 120, '4.5', 'Set Member Goal'),
        ('P46', 'proc', 470, 840, 340, 120, '4.6', 'Create Trainer Plan'),
        ('P47', 'proc', 470, 990, 340, 120, '4.7', 'Monitor Plan Completion'),
        ('D10', 'store', 1000, 240, 300, 56, 'D10', 'Predictions'),
        ('D11', 'store', 1000, 690, 300, 56, 'D11', 'Goal Plans'),
        ('D4', 'store', 1000, 90, 300, 56, 'D4', 'Workout Logs'),
        ('D5', 'store', 1000, 160, 300, 56, 'D5', 'Body Measurements'),
        ('D7', 'store', 1000, 1130, 300, 56, 'D7', 'Meal Logs'),
    ],
    'edges': [
        ('D4', 'P41', 'Workout History Data'),
        ('D5', 'P41', 'Measurement History Data'),
        ('D7', 'P41', 'Nutrition History Data'),
        ('P41', 'P42', 'Progress Trend Data'),
        ('P42', 'D10', 'Prediction Record'),
        ('D10', 'P42', 'Prediction History'),
        ('P42', 'MEMBER', 'Predicted Fitness Progress'),
        ('P42', 'P43', 'Prediction Data'),
        ('P43', 'TRAINER', 'Retention Risk Alert'),
        ('P43', 'P44', 'Risk Assessment Data'),
        ('P44', 'MEMBER', 'Adjusted Goal Suggestion'),
        ('P44', 'D11', 'Goal Adjustment Record'),
        ('MEMBER', 'P45', 'Goal Setting'),
        ('P45', 'D11', 'Member Goal Record'),
        ('D11', 'P45', 'Goal History'),
        ('TRAINER', 'P46', 'Plan Assignment (food, exercise)'),
        ('P46', 'D11', 'Trainer Plan Record'),
        ('D11', 'P46', 'Trainer Plan'),
        ('P46', 'P47', 'Plan Details'),
        ('D11', 'P47', 'Plan Completion Data'),
        ('P47', 'TRAINER', 'Plan Completion Status'),
        ('P47', 'D10', 'Completion Prediction Record'),
    ],
})

# ---------------------------------------------------------------- FIGURE 14
D.append({
    'id': 'fig14', 'name': 'FIG 14 - PROPOSED PROCESS 5',
    'file': 'DFD-Fig14-Proposed-Process5.drawio',
    'title': '3.5 DATA FLOW DIAGRAM', 'sub': 'PROPOSED - PROCESS 5.0',
    'cap': 'Figure 14: Data Flow Diagram of Process 5 (Proposed)',
    'pw': 1400, 'ph': 1750,
    'nodes': [
        ('MEMBER', 'ent', 70, 90, 210, 110, 'MEMBER'),
        ('TRAINER', 'ent', 70, 850, 210, 110, 'TRAINER'),
        ('ADMIN', 'ent', 70, 1150, 210, 110, 'ADMIN'),
        ('P51', 'proc', 470, 90, 340, 120, '5.1', 'Generate Attendance Report'),
        ('P52', 'proc', 470, 240, 340, 120, '5.2', 'Generate Progress Report'),
        ('P53', 'proc', 470, 390, 340, 120, '5.3', 'Generate Analytics Dashboard'),
        ('P54', 'proc', 470, 540, 340, 120, '5.4', 'Detect Inactive Member'),
        ('P55', 'proc', 470, 690, 340, 120, '5.5', 'Broadcast Notification'),
        ('P56', 'proc', 470, 840, 340, 120, '5.6', 'Manage Trainer-Member Chat'),
        ('P57', 'proc', 470, 990, 340, 120, '5.7', 'Record Trainer Feedback'),
        ('D12', 'store', 1000, 690, 300, 56, 'D12', 'Notifications and Chat'),
        ('D13', 'store', 1000, 990, 300, 56, 'D13', 'Trainer Feedback'),
        ('D14', 'store', 1000, 90, 300, 56, 'D14', 'Admin Logs'),
        ('D3', 'store', 1000, 160, 300, 56, 'D3', 'Check-In and Attendance Records'),
        ('D4', 'store', 1000, 540, 300, 56, 'D4', 'Workout Logs'),
    ],
    'edges': [
        ('D3', 'P51', 'Check-In / Attendance Data'),
        ('D14', 'P51', 'Admin Activity Data'),
        ('P51', 'D14', 'Report Generation Log'),
        ('P51', 'ADMIN', 'Attendance Report'),
        ('P52', 'D4', 'Workout History Read'),
        ('D4', 'P52', 'Workout Data'),
        ('P52', 'MEMBER', 'Progress Report'),
        ('P52', 'TRAINER', 'Member Progress Report'),
        ('P52', 'D14', 'Report Log'),
        ('P53', 'D14', 'Analytics Data Log'),
        ('P53', 'ADMIN', 'Analytics Dashboard'),
        ('P54', 'D3', 'Activity History Read'),
        ('D3', 'P54', 'Attendance History'),
        ('P54', 'ADMIN', 'Inactive Member Alert'),
        ('P54', 'D12', 'Alert Record'),
        ('ADMIN', 'P55', 'Broadcast Content'),
        ('P55', 'D12', 'Notification Record'),
        ('P55', 'MEMBER', 'Notification'),
        ('P55', 'TRAINER', 'Notification'),
        ('MEMBER', 'P56', 'Chat Message'),
        ('TRAINER', 'P56', 'Chat Message'),
        ('P56', 'D12', 'Chat Record'),
        ('P56', 'MEMBER', 'Chat Response'),
        ('P56', 'TRAINER', 'Chat Response'),
        ('TRAINER', 'P57', 'Trainer Feedback Content'),
        ('MEMBER', 'P57', 'Trainer Rating'),
        ('P57', 'D13', 'Trainer Feedback Record'),
        ('P57', 'MEMBER', 'Feedback Confirmation'),
    ],
})

# ---------------------------------------------------------------- MAIN
if __name__ == '__main__':
    written = []
    for d in D:
        written.append(write(d))
    for p in written:
        print('wrote %s' % p)
    print('%d diagrams generated' % len(written))




# -*- coding: utf-8 -*-
"""
Generate swimlane-style Activity Diagrams (Figures 15-21) for the
Triple J Fitness Center capstone - Chapter 3.6.

Format follows the reference document (Figure 14: Activity Diagram (Login)):
  - Pool frame with actor lane(s) on the left and a "Proposed System" lane on
    the right, separated by vertical divider lines that run through the header.
  - Solid black initial node at the top of the initiating actor's lane.
  - Bold rounded "Start" activity box directly under the initial node.
  - Rounded-rectangle activities placed in the lane of whoever performs them
    (no "Actor:" prefixes - the lane conveys the actor).
  - Diamond decisions with Yes/No (or role) labels, straddling the lane
    divider where a branch crosses lanes.
  - Bullseye end node with an "End" label beneath it.
  - Times New Roman, white fill / black stroke academic style throughout.
"""
import os
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

POOL_Y, MARGIN, HEADER_H = 20, 30, 40
OUT_DIR = r"c:\capstsh"

ACT   = ("rounded=1;whiteSpace=wrap;html=1;arcSize=40;fillColor=#FFFFFF;"
         "strokeColor=#000000;fontFamily=Times New Roman;fontSize=12;fontStyle=1;")
DEC   = ("rhombus;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;"
         "fontFamily=Times New Roman;fontSize=11;fontStyle=1;")
INIT  = "ellipse;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#000000;"
ENDO  = "ellipse;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;"
ENDI  = "ellipse;whiteSpace=wrap;html=1;fillColor=#000000;strokeColor=#000000;"
POOL  = "rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#000000;"
DIV   = "endArrow=none;html=1;strokeColor=#000000;"
EBASE = "edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#000000;"
ELBL  = ("fontFamily=Times New Roman;fontSize=11;fontStyle=1;"
         "labelBackgroundColor=#FFFFFF;")


def text_style(size, bold=True):
    return ("text;html=1;align=center;verticalAlign=middle;"
            "fontFamily=Times New Roman;fontSize=%d;%sstrokeColor=none;fillColor=none;"
            % (size, "fontStyle=1;" if bold else ""))


def vtx(cid, style, value, x, y, w, h):
    return ('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1">'
            '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry" />'
            '</mxCell>' % (cid, escape(value), style, x, y, w, h))


def edge_xml(eid, s, d, label=None, ex=None, ey=None, nx=None, ny=None, wp=None):
    st = EBASE
    if label:
        st += ELBL
    if ex is not None:
        st += "exitX=%s;exitY=%s;exitDx=0;exitDy=0;" % (ex, ey)
    if nx is not None:
        st += "entryX=%s;entryY=%s;entryDx=0;entryDy=0;" % (nx, ny)
    geo = '<mxGeometry relative="1" as="geometry" />'
    if wp:
        pts = "".join('<mxPoint x="%d" y="%d" />' % p for p in wp)
        geo = ('<mxGeometry relative="1" as="geometry">'
               '<Array as="points">%s</Array></mxGeometry>' % pts)
    val = ' value="%s"' % escape(label) if label else ' value=""'
    return ('<mxCell id="%s"%s style="%s" edge="1" parent="1" '
            'source="%s" target="%s">%s</mxCell>'
            % (eid, val, st, s, d, geo))


def divider_xml(did, x, y_top, y_bot):
    return ('<mxCell id="%s" style="%s" edge="1" parent="1">'
            '<mxGeometry relative="1" as="geometry">'
            '<mxPoint x="%d" y="%d" as="sourcePoint" />'
            '<mxPoint x="%d" y="%d" as="targetPoint" />'
            '</mxGeometry></mxCell>' % (did, DIV, x, y_top, x, y_bot))


def build_figure(filename, diag_id, name, caption, lanes, nodes, edges, def_w=220):
    """lanes: [(title,width)]; nodes: dicts(id,kind,lane,label,y,w,h,dx);
    lane = lane index or ('div', i) for the i-th internal boundary.
    edges: dicts(s,d,label,ex,ey,nx,ny,wp)."""
    total_w = sum(w for _, w in lanes)
    bounds, x = [], MARGIN
    for _, w in lanes:
        bounds.append((x, x + w))
        x += w

    def center(lane):
        if isinstance(lane, tuple):
            return bounds[lane[1]][1]
        return (bounds[lane][0] + bounds[lane][1]) / 2.0

    cells, max_bottom = [], 0.0
    for n in nodes:
        kind, cx = n["kind"], center(n["lane"]) + n.get("dx", 0)
        y = n["y"]
        if kind == "initial":
            cells.append(vtx(n["id"], INIT, "", int(cx - 12), y, 24, 24))
            max_bottom = max(max_bottom, y + 24)
        elif kind == "end":
            cells.append(vtx(n["id"] + "1", ENDO, "", int(cx - 15), y, 30, 30))
            cells.append(vtx(n["id"] + "2", ENDI, "", int(cx - 9), y + 6, 18, 18))
            cells.append(vtx(n["id"] + "l", text_style(12), "End",
                             int(cx - 40), y + 34, 80, 20))
            max_bottom = max(max_bottom, y + 54)
        else:
            w, h = n.get("w", def_w), n.get("h", 50)
            style = {"start": ACT, "action": ACT, "decision": DEC}[kind]
            cells.append(vtx(n["id"], style, n["label"], int(cx - w / 2), y, w, h))
            max_bottom = max(max_bottom, y + h)

    pool_h = int(max_bottom + 24 - POOL_Y)
    cells.insert(0, vtx("pool", POOL, "", MARGIN, POOL_Y, total_w, pool_h))
    for i, (title, w) in enumerate(lanes):
        cells.append(vtx("hdr%d" % i, text_style(13), title,
                         bounds[i][0], POOL_Y, w, HEADER_H))
    for i in range(len(lanes) - 1):
        cells.append(divider_xml("dv%d" % i, bounds[i][1], POOL_Y, POOL_Y + pool_h))
    for e in edges:
        id_map = lambda nid: nid + "1" if any(
            n["id"] == nid and n["kind"] == "end" for n in nodes) else nid
        cells.append(edge_xml(id_map(e["s"]) + "-" + id_map(e["d"]),
                              id_map(e["s"]), id_map(e["d"]),
                              e.get("label"), e.get("ex"), e.get("ey"),
                              e.get("nx"), e.get("ny"), e.get("wp")))
    cap_y = POOL_Y + pool_h + 15
    cells.append(vtx("cap", text_style(13), caption, MARGIN, cap_y, total_w, 30))
    xml = ('<mxfile host="app.diagrams.net" agent="Cline">'
           '<diagram id="%s" name="%s">'
           '<mxGraphModel dx="1600" dy="1000" grid="1" gridSize="10" guides="1" '
           'tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" '
           'pageWidth="%d" pageHeight="%d" math="0" shadow="0">'
           '<root><mxCell id="0" /><mxCell id="1" parent="0" />%s'
           '</root></mxGraphModel></diagram></mxfile>'
           % (diag_id, escape(name), total_w + 2 * MARGIN, cap_y + 70,
              "".join(cells)))
    path = os.path.join(OUT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(xml)
    return path, pool_h


def validate(path, lanes, nodes, def_w):
    """XML well-formedness + edge endpoint + lane-containment checks."""
    tree = ET.parse(path)
    ids = {c.get("id") for c in tree.iter("mxCell")}
    problems, n_nodes, n_edges = [], 0, 0
    for c in tree.iter("mxCell"):
        cid = c.get("id", "")
        if c.get("edge") == "1":
            if cid.startswith("dv"):
                continue
            n_edges += 1
            for ref in (c.get("source"), c.get("target")):
                if ref and ref not in ids:
                    problems.append("edge %s -> missing %s" % (cid, ref))
        elif c.get("vertex") == "1":
            if cid in ("pool", "cap") or cid.startswith("hdr"):
                continue
            n_nodes += 1
    bounds, x = [], MARGIN
    for _, w in lanes:
        bounds.append((x, x + w))
        x += w
    for n in nodes:
        if n["kind"] not in ("action", "decision", "start"):
            continue
        if isinstance(n["lane"], tuple):
            continue  # straddling decisions intentionally cross a divider
        w = n.get("w", def_w)
        cx = (bounds[n["lane"]][0] + bounds[n["lane"]][1]) / 2.0 + n.get("dx", 0)
        lo, hi = bounds[n["lane"]]
        if cx - w / 2.0 < lo - 0.5 or cx + w / 2.0 > hi + 0.5:
            problems.append("%s overflows lane %d" % (n["id"], n["lane"]))
    return n_nodes, n_edges, problems


def_w_cache = {}
SPECS = []


def spec(filename, diag_id, name, caption, lanes, nodes, edges, def_w=220):
    def_w_cache[filename] = def_w
    SPECS.append((filename, diag_id, name, caption, lanes, nodes, edges, def_w))


L2 = [("Member", 320), ("Proposed System", 340)]

# ------------------------------------------------------------------ Figure 15
FIG15_LBL = "Figure 15: Activity Diagram (Member Login and Registration)"
FIG15_NODES = [
    dict(id="ini", kind="initial", lane=0, label="", y=80),
    dict(id="s0", kind="start", lane=0, label="Start", y=124, h=40),
    dict(id="a1", kind="action", lane=0, label="Open the Fitness Application", y=194),
    dict(id="s1", kind="action", lane=1, label="Display Login Form", y=274),
    dict(id="a2", kind="action", lane=0, label="Enter Email and Password", y=354),
    dict(id="d1", kind="decision", lane=0, label="Registered Account?", y=434, w=150, h=80),
    dict(id="s3", kind="action", lane=1, label="Validate Credentials", y=554),
    dict(id="a3", kind="action", lane=0, label="Fill Out Registration Form", y=554),
    dict(id="a4", kind="action", lane=0, label="Submit Registration Details", y=634),
    dict(id="d2", kind="decision", lane=("div", 0), label="Are Credentials Valid?", y=654, w=150, h=80),
    dict(id="s4", kind="action", lane=1, label="Display Error Message", y=669, w=180, dx=40),
    dict(id="s2", kind="action", lane=1, label="Create Account and Send Confirmation", y=724),
    dict(id="s5", kind="action", lane=1, label="Display Member Dashboard", y=794),
    dict(id="a5", kind="action", lane=0, label="Receive Account Confirmation", y=804),
    dict(id="end", kind="end", lane=1, label="", y=864),
]
FIG15_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="a1"),
    dict(s="a1", d="s1"),
    dict(s="s1", d="a2"),
    dict(s="a2", d="d1"),
    dict(s="d1", d="a3", label="No"),
    dict(s="a3", d="a4"),
    dict(s="a4", d="s2", wp=[(190, 754), (520, 754)]),
    dict(s="s2", d="a5"),
    dict(s="a5", d="a2", ex=0, ey=0.5, nx=0, ny=0.5, wp=[(50, 829), (50, 379)]),
    dict(s="d1", d="s3", label="Yes", ex=1, ey=0.5, nx=0, ny=0.5,
         wp=[(355, 474), (355, 579)]),
    dict(s="s3", d="d2"),
    dict(s="d2", d="s5", label="Yes", ex=0.5, ey=1, nx=0.5, ny=0, wp=[(350, 779)]),
    dict(s="d2", d="s4", label="No", ex=1, ey=0.5, nx=0, ny=0.5),
    dict(s="s4", d="a2", ex=1, ey=0.5, nx=1, ny=0.5, wp=[(672, 694), (672, 379)]),
    dict(s="s5", d="end"),
]
spec("Activity-Fig15-Member-Login-Registration.drawio", "act-fig15",
     "FIG 15 - ACTIVITY DIAGRAM LOGIN AND REGISTRATION", FIG15_LBL,
     L2, FIG15_NODES, FIG15_EDGES)

# ------------------------------------------------------------------ Figure 16
FIG16_LBL = "Figure 16: Activity Diagram (Workout Logging with Exercise Tracking)"
FIG16_NODES = [
    dict(id="ini", kind="initial", lane=0, label="", y=80),
    dict(id="s0", kind="start", lane=0, label="Start", y=124, h=40),
    dict(id="a1", kind="action", lane=0, label="Start Workout Session", y=194),
    dict(id="a2", kind="action", lane=0, label="Select Exercise from Catalog", y=274),
    dict(id="a3", kind="action", lane=0, label="Enter Sets, Repetitions, and Duration", y=354),
    dict(id="d1", kind="decision", lane=("div", 0), label="Record Proof Video?", y=434, w=150, h=80),
    dict(id="a4", kind="action", lane=0, label="Record or Upload Proof Video", y=554),
    dict(id="s1", kind="action", lane=1, label="Retrieve MET Value from Exercise Catalog", y=554),
    dict(id="s2", kind="action", lane=1, label="Compute Calories Burned", y=634),
    dict(id="d2", kind="decision", lane=("div", 0), label="Add Another Exercise?", y=714, w=150, h=80),
    dict(id="a5", kind="action", lane=0, label="Finish Workout Session", y=794),
    dict(id="s3", kind="action", lane=1, label="Save Entries to Workout Logs", y=874),
    dict(id="s4", kind="action", lane=1, label="Display Workout Summary and Calories Burned", y=954),
    dict(id="end", kind="end", lane=1, label="", y=1024),
]
FIG16_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="a1"),
    dict(s="a1", d="a2"),
    dict(s="a2", d="a3"),
    dict(s="a3", d="d1"),
    dict(s="d1", d="a4", label="Yes", ex=0, ey=0.5, nx=0.5, ny=0),
    dict(s="d1", d="s1", label="No", ex=0.5, ey=1, nx=0.5, ny=0),
    dict(s="a4", d="s1", ex=1, ey=0.5, nx=0, ny=0.5),
    dict(s="s1", d="s2"),
    dict(s="s2", d="d2"),
    dict(s="d2", d="a2", label="Yes", ex=1, ey=0.5, nx=1, ny=0.5,
         wp=[(670, 754), (670, 299)]),
    dict(s="d2", d="a5", label="No", ex=0, ey=0.5, nx=0.5, ny=0),
    dict(s="a5", d="s3"),
    dict(s="s3", d="s4"),
    dict(s="s4", d="end"),
]
spec("Activity-Fig16-Workout-Logging.drawio", "act-fig16",
     "FIG 16 - ACTIVITY DIAGRAM WORKOUT LOGGING", FIG16_LBL,
     L2, FIG16_NODES, FIG16_EDGES)

# ------------------------------------------------------------------ Figure 17
FIG17_LBL = "Figure 17: Activity Diagram (QR Code Check-In and Check-Out)"
FIG17_NODES = [
    dict(id="ini", kind="initial", lane=0, label="", y=80),
    dict(id="s0", kind="start", lane=0, label="Start", y=124, h=40),
    dict(id="a1", kind="action", lane=0, label="Open the Fitness Application", y=194),
    dict(id="a2", kind="action", lane=0, label="Tap Check-In and Activate QR Scanner", y=274),
    dict(id="a3", kind="action", lane=0, label="Scan Gym QR Code", y=354),
    dict(id="s1", kind="action", lane=1, label="Validate QR Code", y=434),
    dict(id="d1", kind="decision", lane=("div", 0), label="Valid Gym Location?", y=514, w=150, h=80),
    dict(id="s2", kind="action", lane=1, label="Display Invalid QR Code Error", y=529, w=180, dx=40),
    dict(id="s3", kind="action", lane=1, label="Record Check-In Timestamp", y=634),
    dict(id="s4", kind="action", lane=1, label="Display Checked-In Confirmation", y=714),
    dict(id="a8", kind="action", lane=0, label="Perform Workout", y=794),
    dict(id="a9", kind="action", lane=0, label="Tap Check-Out Button", y=874),
    dict(id="s5", kind="action", lane=1, label="Record Check-Out Timestamp", y=954),
    dict(id="s6", kind="action", lane=1, label="Update Attendance Record", y=1034),
    dict(id="s7", kind="action", lane=1, label="Display Checked-Out Confirmation", y=1114),
    dict(id="end", kind="end", lane=1, label="", y=1184),
]
FIG17_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="a1"),
    dict(s="a1", d="a2"),
    dict(s="a2", d="a3"),
    dict(s="a3", d="s1"),
    dict(s="s1", d="d1"),
    dict(s="d1", d="s2", label="No", ex=1, ey=0.5, nx=0, ny=0.5),
    dict(s="s2", d="a3", ex=1, ey=0.5, nx=1, ny=0.5, wp=[(672, 554), (672, 379)]),
    dict(s="d1", d="s3", label="Yes", ex=0.5, ey=1, nx=0.5, ny=0),
    dict(s="s3", d="s4"),
    dict(s="s4", d="a8"),
    dict(s="a8", d="a9"),
    dict(s="a9", d="s5"),
    dict(s="s5", d="s6"),
    dict(s="s6", d="s7"),
    dict(s="s7", d="end"),
]
spec("Activity-Fig17-QR-CheckIn-CheckOut.drawio", "act-fig17",
     "FIG 17 - ACTIVITY DIAGRAM QR CHECK-IN CHECK-OUT", FIG17_LBL,
     L2, FIG17_NODES, FIG17_EDGES)

# ------------------------------------------------------------------ Figure 18
FIG18_LBL = "Figure 18: Activity Diagram (Meal Logging and AI Food Analysis)"
FIG18_NODES = [
    dict(id="ini", kind="initial", lane=0, label="", y=80),
    dict(id="s0", kind="start", lane=0, label="Start", y=124, h=40),
    dict(id="a1", kind="action", lane=0, label="Open Meal Logging Page", y=194),
    dict(id="a2", kind="action", lane=0,
         label="Enter Meal Details (Food Name, Meal Type, and Calories)", y=274, h=60),
    dict(id="d1", kind="decision", lane=("div", 0), label="Upload Food Photograph?", y=364, w=150, h=80),
    dict(id="a2a", kind="action", lane=0, label="Capture or Upload Food Photograph", y=444),
    dict(id="s1", kind="action", lane=1,
         label="Send Food Image and Nutrition Query to Google Gemini API", y=524, h=60),
    dict(id="s2", kind="action", lane=1, label="Receive Recognized Food Item from Gemini API", y=624, h=60),
    dict(id="s3", kind="action", lane=1, label="Compute Nutrient Breakdown from Nutrition Foods", y=714, h=60),
    dict(id="s4", kind="action", lane=1, label="Generate Food Recommendation", y=804),
    dict(id="s5", kind="action", lane=1,
         label="Display Nutrient Breakdown and Food Recommendation", y=884, h=60),
    dict(id="s6", kind="action", lane=1, label="Save Meal Record to Meal Logs", y=974),
    dict(id="end", kind="end", lane=1, label="", y=1044),
]
FIG18_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="a1"),
    dict(s="a1", d="a2"),
    dict(s="a2", d="d1"),
    dict(s="d1", d="a2a", label="Yes", ex=0, ey=0.5, nx=0.5, ny=0),
    dict(s="d1", d="s1", label="No", ex=1, ey=0.5, nx=0.5, ny=0),
    dict(s="a2a", d="s1", ex=1, ey=0.5, nx=0, ny=0.5, wp=[(380, 469), (380, 554)]),
    dict(s="s1", d="s2"),
    dict(s="s2", d="s3"),
    dict(s="s3", d="s4"),
    dict(s="s4", d="s5"),
    dict(s="s5", d="s6"),
    dict(s="s6", d="end"),
]
spec("Activity-Fig18-Meal-Logging-AI-Analysis.drawio", "act-fig18",
     "FIG 18 - ACTIVITY DIAGRAM MEAL LOGGING AI ANALYSIS", FIG18_LBL,
     L2, FIG18_NODES, FIG18_EDGES)

# ------------------------------------------------------------------ Figure 19
FIG19_LANES = [("Member", 300), ("Trainer", 300), ("Admin", 300),
               ("Proposed System", 300)]
FIG19_LBL = "Figure 19: Activity Diagram (Dashboard View)"
FIG19_NODES = [
    dict(id="ini", kind="initial", lane=0, label="", y=80),
    dict(id="s0", kind="start", lane=0, label="Start", y=124, h=40),
    dict(id="a1", kind="action", lane=0, label="Log In to the System", y=194),
    dict(id="d1", kind="decision", lane=("div", 1), label="What Is the User Role?", y=274, w=160, h=90),
    dict(id="a2", kind="action", lane=0, label="View Workout History, BMI Trend, and Predictions", y=434, h=70),
    dict(id="a3", kind="action", lane=1, label="View Assigned Members, Retention Risk Alerts, and Plan Status", y=434, h=70),
    dict(id="a4", kind="action", lane=2, label="View Attendance Reports, Analytics, and Inactive Member Alerts", y=434, h=70),
    dict(id="s1", kind="action", lane=3, label="Retrieve Role-Specific Data", y=434),
    dict(id="s2", kind="action", lane=3, label="Display Dashboard with Charts and Real-Time Status", y=534, h=60),
    dict(id="end", kind="end", lane=3, label="", y=624),
]
FIG19_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="a1"),
    dict(s="a1", d="d1"),
    dict(s="d1", d="a2", label="Member", ex=0, ey=0.5, nx=0.5, ny=0,
         wp=[(180, 319), (180, 399)]),
    dict(s="d1", d="a3", label="Trainer", ex=0, ey=0.5, nx=0.5, ny=0,
         wp=[(480, 319), (480, 399)]),
    dict(s="d1", d="a4", label="Admin", ex=1, ey=0.5, nx=0.5, ny=0,
         wp=[(780, 319), (780, 399)]),
    dict(s="a2", d="s1", wp=[(180, 514), (1034, 514)], nx=0.3, ny=1),
    dict(s="a3", d="s1", wp=[(480, 514), (1034, 514)], nx=0.3, ny=1),
    dict(s="a4", d="s1", wp=[(780, 514), (1034, 514)], nx=0.3, ny=1),
    dict(s="s1", d="s2"),
    dict(s="s2", d="end"),
]
spec("Activity-Fig19-Dashboard-View.drawio", "act-fig19",
     "FIG 19 - ACTIVITY DIAGRAM DASHBOARD VIEW", FIG19_LBL,
     FIG19_LANES, FIG19_NODES, FIG19_EDGES, def_w=230)

# ------------------------------------------------------------------ Figure 20
FIG20_LANES = [("Trainer", 300), ("Member", 300), ("Proposed System", 340)]
FIG20_LBL = "Figure 20: Activity Diagram (Trainer Feedback and Member Rating)"
FIG20_NODES = [
    dict(id="ini", kind="initial", lane=0, label="", y=80),
    dict(id="s0", kind="start", lane=0, label="Start", y=124, h=40),
    dict(id="a1", kind="action", lane=0, label="Select Member", y=194),
    dict(id="a2", kind="action", lane=0, label="Review Workout Logs and Progress", y=274),
    dict(id="a3", kind="action", lane=0, label="Provide Written Feedback", y=354),
    dict(id="s1", kind="action", lane=2, label="Save Feedback to Trainer Feedback", y=434, h=60),
    dict(id="s2", kind="action", lane=2, label="Send Notification to Member", y=534),
    dict(id="a6", kind="action", lane=1, label="View Trainer Feedback", y=614),
    dict(id="d1", kind="decision", lane=("div", 1), label="Rate the Trainer?", y=694, w=150, h=80),
    dict(id="a7", kind="action", lane=1, label="Provide Star Rating (1-5)", y=804),
    dict(id="s3", kind="action", lane=2, label="Save Trainer Rating", y=884),
    dict(id="s4", kind="action", lane=2, label="Display Feedback Confirmation", y=964),
    dict(id="end", kind="end", lane=2, label="", y=1054),
]
FIG20_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="a1"),
    dict(s="a1", d="a2"),
    dict(s="a2", d="a3"),
    dict(s="a3", d="s1"),
    dict(s="s1", d="s2"),
    dict(s="s2", d="a6"),
    dict(s="a6", d="d1"),
    dict(s="d1", d="a7", label="Yes", ex=0, ey=0.5, nx=0.5, ny=0),
    dict(s="d1", d="s4", label="No", ex=1, ey=0.5, nx=1, ny=0.5,
         wp=[(940, 734), (940, 989)]),
    dict(s="a7", d="s3", ex=1, ey=0.5, nx=0.5, ny=0, wp=[(640, 829), (640, 859)]),
    dict(s="s3", d="s4"),
    dict(s="s4", d="end"),
]
spec("Activity-Fig20-Trainer-Feedback-Rating.drawio", "act-fig20",
     "FIG 20 - ACTIVITY DIAGRAM TRAINER FEEDBACK RATING", FIG20_LBL,
     FIG20_LANES, FIG20_NODES, FIG20_EDGES)

# ------------------------------------------------------------------ Figure 21
FIG21_LANES = [("Member", 320), ("Trainer", 320), ("Proposed System", 360)]
FIG21_LBL = "Figure 21: Activity Diagram (Goal Setting and Plan Creation)"
FIG21_NODES = [
    dict(id="ini", kind="initial", lane=2, label="", y=80),
    dict(id="s0", kind="start", lane=2, label="Start", y=124, h=40),
    dict(id="s1", kind="action", lane=2,
         label="Analyze Progress Trend from Workout, Measurement, and Nutrition Histories", y=194, h=70, w=250),
    dict(id="s2", kind="action", lane=2, label="Generate Predicted Fitness Progress", y=304, h=60),
    dict(id="s3", kind="action", lane=2, label="Assess Retention Risk and Notify Trainer", y=404, h=60),
    dict(id="s4", kind="action", lane=2, label="Display Adjusted Goal Suggestion to Member", y=504, h=60),
    dict(id="a5", kind="action", lane=0, label="Set or Refine Fitness Goal", y=604),
    dict(id="s6", kind="action", lane=2, label="Save Goal to Goal Plans", y=684),
    dict(id="t7", kind="action", lane=1, label="Review Goal and Create Food and Exercise Plan", y=764, h=60),
    dict(id="s8", kind="action", lane=2, label="Save Trainer Plan to Goal Plans", y=864, h=60),
    dict(id="s9", kind="action", lane=2, label="Monitor Plan Completion", y=964),
    dict(id="s10", kind="action", lane=2, label="Display Completion Status to Trainer and Member", y=1044, h=60),
    dict(id="end", kind="end", lane=2, label="", y=1134),
]
FIG21_EDGES = [
    dict(s="ini", d="s0"),
    dict(s="s0", d="s1"),
    dict(s="s1", d="s2"),
    dict(s="s2", d="s3"),
    dict(s="s3", d="s4"),
    dict(s="s4", d="a5"),
    dict(s="a5", d="s6"),
    dict(s="s6", d="t7"),
    dict(s="t7", d="s8"),
    dict(s="s8", d="s9"),
    dict(s="s9", d="s10"),
    dict(s="s10", d="end"),
]
spec("Activity-Fig21-Goal-Setting-Plan-Creation.drawio", "act-fig21",
     "FIG 21 - ACTIVITY DIAGRAM GOAL SETTING PLAN CREATION", FIG21_LBL,
     FIG21_LANES, FIG21_NODES, FIG21_EDGES)


def main():
    for filename, diag_id, name, caption, lanes, nodes, edges, def_w in SPECS:
        path, pool_h = build_figure(filename, diag_id, name, caption,
                                    lanes, nodes, edges, def_w)
        n_nodes, n_edges, problems = validate(path, lanes, nodes, def_w)
        status = "OK" if not problems else "PROBLEMS"
        print("%-52s nodes=%2d edges=%2d poolH=%4d %s"
              % (os.path.basename(path), n_nodes, n_edges, pool_h, status))
        for p in problems:
            print("    !! " + p)


if __name__ == "__main__":
    main()





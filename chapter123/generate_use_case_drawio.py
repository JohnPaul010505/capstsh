# -*- coding: utf-8 -*-
"""Generate Use Case Figures 26-28 for the Triple J Fitness Center capstone - Ch. 3.8.

Section 3.8 USE CASE is split into three per-actor figures (no overall
diagram), one for each role defined in Chapter 1 - Member, Trainer, Admin -
keeping the reference document's caption convention ("Use Case of the ...").
Shared AI use cases produced by the ai-service (identify food photo,
food recommendation, nutrient breakdown, MET, prediction, goal suggestion)
are drawn as include/extend targets and may repeat across figures, in the
same way the profiles hub entity is repeated in the ERD figures. The
Gemini API appears as a secondary actor in Figure 26 only, where the AI
dependency is a direct external call.

Style follows the DFD/Activity/ERD diagram family: Times New Roman, white
fill / black stroke, caption text cell above the figure, legend cell,
umlActor stick figures outside the system boundary, ellipse use cases
inside, solid association lines, dashed "include"/"extend" dependencies,
and explicit exit/entry anchors so no two lines cross.

Use case source of truth: mobile router, admin routes, admin/server API,
ai-service endpoints, supabase/migrations 00001-00021.
"""
import os
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET

OUT_DIR = r"c:\capstsh"

CAP = ("text;html=1;align=center;verticalAlign=middle;fontFamily=Times New Roman;"
       "fontSize=13;fontStyle=1;strokeColor=none;fillColor=none;")
ACTOR_STY = ("shape=umlActor;verticalLabelPosition=bottom;verticalAlign=top;"
             "html=1;fillColor=#FFFFFF;strokeColor=#000000;"
             "fontFamily=Times New Roman;fontSize=12;fontStyle=1;")
BOUND_STY = ("rounded=0;whiteSpace=wrap;html=1;fillColor=none;strokeColor=#000000;"
             "fontFamily=Times New Roman;fontSize=13;fontStyle=1;"
             "verticalAlign=top;spacingTop=8;")
OVAL_STY = ("ellipse;whiteSpace=wrap;html=1;fillColor=#FFFFFF;strokeColor=#000000;"
            "fontFamily=Times New Roman;fontSize=11;")
ASSOC = "endArrow=none;html=1;strokeColor=#000000;"
DEP = ("endArrow=open;endFill=0;dashed=1;html=1;strokeColor=#000000;"
       "fontFamily=Times New Roman;fontSize=10;fontStyle=1;"
       "labelBackgroundColor=#FFFFFF;")

SYSTEM = ("Intelligent Fitness Progress Monitoring Application "
          "Using Predictive Analytics")
LEGEND = ("Actor = system role   oval = use case   solid line = association   "
          "dashed arrow = \u00abinclude\u00bb / \u00abextend\u00bb dependency")

# One entry per figure. columns.assoc = use cases linked to the primary
# actor (ordered top to bottom; an extend extension sits directly below its
# base); columns.inc = shared use cases reached only through dashed
# dependencies; includes = (base, target); extends = (extension, base);
# secondary = [(actor, use case)] extra associations (Gemini API).
FIGS = [
    dict(fig=26, slug="Member", actor="Member", module="Member Module",
         secondary=["Gemini API"],
         columns=dict(
             assoc=["Register and Login",
                    "Log Workout",
                    "Record Exercise Proof Video",
                    "Log Meal",
                    "QR Check-In and Check-Out",
                    "View Member Dashboard",
                    "View BMI and Body Measurements",
                    "Set Fitness Goal",
                    "View Goal Plan and Day Completion",
                    "View Progress Prediction",
                    "Chat with Trainer",
                    "View Trainer Feedback and Rate Trainer",
                    "Receive Notifications",
                    "Manage Profile and Settings"],
             inc=["Estimate MET Energy Expenditure",
                  "Identify Food Photo",
                  "Generate Food Recommendation",
                  "Compute Nutrient Breakdown",
                  "Generate Goal Suggestion",
                  "Generate Progress Prediction"]),
         includes=[("Log Workout", "Estimate MET Energy Expenditure"),
                   ("Log Meal", "Identify Food Photo"),
                   ("Log Meal", "Generate Food Recommendation"),
                   ("Log Meal", "Compute Nutrient Breakdown"),
                   ("Set Fitness Goal", "Generate Goal Suggestion"),
                   ("View Progress Prediction", "Generate Progress Prediction")],
         extends=[("Record Exercise Proof Video", "Log Workout")]),
    dict(fig=27, slug="Trainer", actor="Trainer", module="Trainer Module",
         secondary=[],
         columns=dict(
             assoc=["Login",
                    "View Trainer Dashboard with Retention Risk",
                    "View Assigned Members and Member Logs",
                    "Record Body Measurements",
                    "Create 7-Day Food and Exercise Plan",
                    "Monitor Plan Completion",
                    "Give Feedback",
                    "Chat with Member",
                    "Receive Notifications",
                    "Manage Profile"],
             inc=["Assess Retention Risk",
                  "Generate Goal Suggestion",
                  "Search MET Exercise Catalog"]),
         includes=[("View Trainer Dashboard with Retention Risk",
                    "Assess Retention Risk"),
                   ("Create 7-Day Food and Exercise Plan",
                    "Generate Goal Suggestion"),
                   ("Create 7-Day Food and Exercise Plan",
                    "Search MET Exercise Catalog")],
         extends=[]),
    dict(fig=28, slug="Admin", actor="Admin", module="Admin Module",
         secondary=[],
         columns=dict(
             assoc=["Login",
                    "View Admin Dashboard",
                    "Manage Members",
                    "Manage Trainers",
                    "Assign Trainer to Member",
                    "Confirm Enrollment",
                    "Manage Memberships",
                    "View Attendance Records",
                    "View Workout Records",
                    "Generate Inactive Member Report",
                    "Generate Coach Feedback Report",
                    "Manage QR Codes",
                    "Send and Broadcast Notifications",
                    "View Progress Predictions",
                    "View Activity Logs",
                    "Configure Settings"],
             inc=["Detect Inactive Members",
                  "Generate Progress Prediction"]),
         includes=[("Generate Inactive Member Report", "Detect Inactive Members"),
                   ("View Progress Predictions", "Generate Progress Prediction")],
         extends=[]),
]

# ---- geometry constants ----
OVAL_W, OVAL_H = 210, 56
ROW_GAP = 34
EXT_EXTRA = 52          # extra gap under a use case that is extend-base
COL_GAP = 50
BOUND_PAD_X = 40        # padding between boundary edge and first column
LABEL_H = 64            # boundary label strip
BOUND_PAD_BOT = 30
ACTOR_W, ACTOR_H = 40, 60
BOUND_X = 220           # boundary left edge
ACTOR_X = 70
CAP_W = 1100
TOP_Y = 110             # boundary top (caption 10..40, legend 50..78)
PAGE_MARGIN = 40
SEC_GAP = 60            # gap between boundary and secondary actor
PAGE_W_EXTRA = 80


def vtx(cid, value, x, y, w, h, style):
    return ('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1">'
            '<mxGeometry x="%d" y="%d" width="%d" height="%d" as="geometry" />'
            '</mxCell>' % (cid, escape(value), style, x, y, w, h))


def edge_cell(eid, style, label, s, d, ex, ey, nx, ny):
    st = style + ("exitX=%.3f;exitY=%.3f;exitDx=0;exitDy=0;"
                  "entryX=%.3f;entryY=%.3f;entryDx=0;entryDy=0;"
                  % (ex, ey, nx, ny))
    val = ' value="%s"' % escape(label) if label else ' value=""'
    return ('<mxCell id="%s"%s style="%s" edge="1" parent="1" '
            'source="%s" target="%s">'
            '<mxGeometry relative="1" as="geometry" /></mxCell>'
            % (eid, val, st, s, d))


def build(part):
    assoc = part["columns"]["assoc"]
    inc = part["columns"]["inc"]
    boundary_w = BOUND_PAD_X + OVAL_W + COL_GAP + OVAL_W + BOUND_PAD_X
    ax = BOUND_X + BOUND_PAD_X                 # assoc column x
    ix = ax + OVAL_W + COL_GAP                 # include column x

    # row layout for the assoc column (extra gap under extend bases)
    ext_base = dict((b, e) for e, b in part["extends"])
    pos, y = {}, TOP_Y + LABEL_H
    for name in assoc:
        pos[name] = (ax, y)
        y += OVAL_H + (ROW_GAP + EXT_EXTRA if name in ext_base else ROW_GAP)
    assoc_bottom = y - ROW_GAP
    # include column rows
    iy = TOP_Y + LABEL_H
    for name in inc:
        pos[name] = (ix, iy)
        iy += OVAL_H + ROW_GAP
    inc_bottom = iy - ROW_GAP

    boundary_h = LABEL_H + max(assoc_bottom, inc_bottom) - TOP_Y + BOUND_PAD_BOT
    cells = ['<mxCell id="0" />', '<mxCell id="1" parent="0" />']
    caption = "Figure %d: Use Case of the %s" % (part["fig"], part["module"])

    sec_links = []
    if part["fig"] == 26:
        sec_links = [("Gemini API", "Identify Food Photo")]
    page_w = (BOUND_X + boundary_w + PAGE_MARGIN
              + ((SEC_GAP + ACTOR_W + PAGE_W_EXTRA) if sec_links else 0))
    cells.append(vtx("cap", caption, (page_w - CAP_W) // 2, 10, CAP_W, 30, CAP))
    cells.append(vtx("legend", LEGEND, (page_w - CAP_W) // 2, 50, CAP_W, 28, CAP))
    cells.append(vtx("bound", SYSTEM, BOUND_X, TOP_Y, boundary_w, boundary_h,
                     BOUND_STY))
    for name in assoc:
        x, yy = pos[name]
        cells.append(vtx("uc_" + name, name, x, yy, OVAL_W, OVAL_H, OVAL_STY))
    for name in inc:
        x, yy = pos[name]
        cells.append(vtx("uc_" + name, name, x, yy, OVAL_W, OVAL_H, OVAL_STY))

    # primary actor vertically centred on its association fan
    a_top, a_bot = pos[assoc[0]][1], pos[assoc[-1]][1] + OVAL_H
    actor = part["actor"]
    ay = int((a_top + a_bot) / 2 - ACTOR_H / 2)
    cells.append(vtx("act_" + actor, actor, ACTOR_X, ay,
                     ACTOR_W, ACTOR_H, ACTOR_STY))
    # primary associations: actor right edge fans out, ovals entered mid-left
    n = len(assoc)
    for i, name in enumerate(assoc):
        cells.append(edge_cell("as%d" % i, ASSOC, "", "act_" + actor,
                               "uc_" + name, 1.0, (i + 1) / float(n + 1),
                               0.0, 0.5))
    # secondary actors on the right, aligned with their linked use case
    for k, (sec, target) in enumerate(sec_links):
        sx = BOUND_X + boundary_w + SEC_GAP
        ty = pos[target][1] + OVAL_H / 2 - ACTOR_H / 2
        cells.append(vtx("act_" + sec, sec, sx, int(ty),
                         ACTOR_W, ACTOR_H, ACTOR_STY))
        cells.append(edge_cell("sec%d" % k, ASSOC, "", "act_" + sec,
                               "uc_" + target, 0.0, 0.5, 1.0, 0.5))
        page_w = max(page_w, sx + ACTOR_W + PAGE_W_EXTRA)
    # include dependencies: base right edge -> target left edge
    by_base = {}
    for j, (base, target) in enumerate(part["includes"]):
        by_base.setdefault(base, []).append((j, target))
    for base, lst in by_base.items():
        m = len(lst)
        for j, (eid, target) in enumerate(lst):
            cells.append(edge_cell("inc%d" % eid, DEP, "\u00abinclude\u00bb",
                                   "uc_" + base, "uc_" + target,
                                   1.0, (j + 1) / float(m + 1), 0.0, 0.5))
    # extend dependencies: extension top -> base bottom (adjacent rows)
    for k, (extension, base) in enumerate(part["extends"]):
        assert assoc.index(extension) == assoc.index(base) + 1, \
            "extend pair must be adjacent: %s -> %s" % (extension, base)
        cells.append(edge_cell("ext%d" % k, DEP, "\u00abextend\u00bb",
                               "uc_" + extension, "uc_" + base,
                               0.5, 0.0, 0.5, 1.0))

    page_h = TOP_Y + boundary_h + PAGE_MARGIN
    doc = ('<mxfile host="app.diagrams.net" agent="Cline">'
           '<diagram id="uc%d" name="FIG %d - USE CASE %s">'
           '<mxGraphModel dx="2000" dy="1600" grid="1" gridSize="10" '
           'guides="1" tooltips="1" connect="1" arrows="1" fold="1" '
           'page="1" pageScale="1" pageWidth="%d" pageHeight="%d" '
           'math="0" shadow="0"><root>%s</root></mxGraphModel>'
           "</diagram></mxfile>"
           % (part["fig"], part["fig"], escape(part["module"]),
              page_w, page_h, "".join(cells)))
    path = os.path.join(OUT_DIR, "UseCase-Fig%d-%s.drawio"
                        % (part["fig"], part["slug"]))
    with open(path, "w", encoding="utf-8") as f:
        f.write(doc)
    return path, caption, page_w, page_h


def validate(part, path, caption, page_w, page_h):
    problems = []
    try:
        root = ET.parse(path).getroot()
    except Exception as exc:
        return ["XML parse failed: %s" % exc]
    blob = open(path, encoding="utf-8").read()
    cells = root.findall(".//mxCell")
    ovals = [c for c in cells if c.get("vertex") == "1"
             and "ellipse" in (c.get("style") or "")]
    actors = [c for c in cells if c.get("vertex") == "1"
              and "umlActor" in (c.get("style") or "")]
    edges = [c for c in cells if c.get("edge") == "1"]
    assoc_e = [c for c in edges if "endArrow=none" in (c.get("style") or "")]
    dep_e = [c for c in edges if "endArrow=open" in (c.get("style") or "")]
    want_ovals = len(part["columns"]["assoc"]) + len(part["columns"]["inc"])
    want_actors = 1 + len(part["secondary"])
    if caption not in blob:
        problems.append("caption %r not found" % caption)
    if LEGEND not in blob:
        problems.append("legend not found")
    if SYSTEM not in blob:
        problems.append("system boundary label not found")
    if len(ovals) != want_ovals:
        problems.append("oval count %d != %d" % (len(ovals), want_ovals))
    if len(actors) != want_actors:
        problems.append("actor count %d != %d" % (len(actors), want_actors))
    if len(assoc_e) != want_ovals - len(part["columns"]["inc"]) \
            + len(part["secondary"]):
        problems.append("association edge count %d unexpected" % len(assoc_e))
    if len(dep_e) != len(part["includes"]) + len(part["extends"]):
        problems.append("dependency edge count %d != %d"
                        % (len(dep_e), len(part["includes"])
                           + len(part["extends"])))
    for r in part["includes"] + part["extends"]:
        if ("uc_" + r[0]) not in blob or ("uc_" + r[1]) not in blob:
            problems.append("dependency endpoint missing: %s" % (r,))
    print("  Fig %d: ovals=%d actors=%d assoc=%d dep=%d page=%dx%d %s"
          % (part["fig"], len(ovals), len(actors), len(assoc_e), len(dep_e),
             page_w, page_h, "OK" if not problems else "PROBLEMS"))
    return problems


def main():
    all_problems = []
    for part in FIGS:
        path, caption, page_w, page_h = build(part)
        problems = validate(part, path, caption, page_w, page_h)
        all_problems.extend("%s (Fig %d): %s" % (os.path.basename(path),
                                                 part["fig"], p)
                            for p in problems)
    n_assoc = sum(len(p["columns"]["assoc"]) for p in FIGS)
    n_inc = sum(len(p["columns"]["inc"]) for p in FIGS)
    print("generated %d figures, %d actor use cases + %d shared use cases"
          % (len(FIGS), n_assoc, n_inc))
    if all_problems:
        print("PROBLEMS:")
        for p in all_problems:
            print("    !! " + p)
    else:
        print("all figure validations OK")


if __name__ == "__main__":
    main()

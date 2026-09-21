# -*- coding: utf-8 -*-
"""Generate ERD Figures 22-25 for the Triple J Fitness Center capstone - Ch. 3.7.

The full 24-entity diagram does not fit readably on a single page, so it is
split into four self-contained figures, following the same convention as the
reference capstone document (which repeats its hub entity `Items` in every
part). `profiles` is our hub entity and is repeated in every part:

  Figure 22  Accounts, Membership and Attendance
  Figure 23  Fitness Tracking, Goals and Trainer Feedback
  Figure 24  Nutrition, Meal Logging and Reference Data
  Figure 25  Communication, Notifications and Administration

Style follows the DFD/Activity diagrams: Times New Roman, white fill /
black stroke, caption text cell above the figure. Crow's-foot notation is
approximated with open-arrow heads plus "1" / "N" cardinality labels on
each relationship edge. Edges use explicit exit/entry anchor points so the
hub fans out on its hub-facing edge and no two lines cross.

Schema source of truth: supabase/migrations 00001-00021.
"""
import os
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET

OUT_DIR = r"c:\capstsh"

HDR = ("rounded=1;arcSize=6;whiteSpace=wrap;html=1;fillColor=#FFFFFF;"
       "strokeColor=#000000;fontFamily=Times New Roman;fontSize=12;")
CAP = ("text;html=1;align=center;verticalAlign=middle;fontFamily=Times New Roman;"
       "fontSize=13;fontStyle=1;strokeColor=none;fillColor=none;")
NOTE = ("text;html=1;align=center;verticalAlign=middle;fontFamily=Times New Roman;"
        "fontSize=10;fontStyle=2;strokeColor=none;fillColor=none;")
EBASE = ("edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeColor=#000000;"
         "endArrow=open;endFill=0;fontFamily=Times New Roman;fontSize=10;"
         "fontStyle=1;labelBackgroundColor=#FFFFFF;")
EBASE_OPT = EBASE + "dashed=1;"

# (name, [(column, key)])  key: PK / FK / PKFK / ""
ENTITIES = [
    [
        "enrollments",
        [
            [
                "id",
                "PK"
            ],
            [
                "full_name",
                ""
            ],
            [
                "email",
                ""
            ],
            [
                "phone",
                ""
            ],
            [
                "date_of_birth",
                ""
            ],
            [
                "gender",
                ""
            ],
            [
                "address",
                ""
            ],
            [
                "emergency_contact_name",
                ""
            ],
            [
                "emergency_contact_phone",
                ""
            ],
            [
                "status",
                ""
            ],
            [
                "confirmed_by",
                "FK"
            ],
            [
                "confirmed_at",
                ""
            ]
        ]
    ],
    [
        "profiles",
        [
            [
                "id",
                "PK"
            ],
            [
                "role",
                ""
            ],
            [
                "full_name",
                ""
            ],
            [
                "email",
                ""
            ],
            [
                "phone",
                ""
            ],
            [
                "avatar_url",
                ""
            ],
            [
                "date_of_birth",
                ""
            ],
            [
                "gender",
                ""
            ],
            [
                "code",
                ""
            ],
            [
                "emergency_contact_name",
                ""
            ],
            [
                "emergency_contact_phone",
                ""
            ],
            [
                "specialty",
                ""
            ],
            [
                "available_days",
                ""
            ],
            [
                "fitness_goal",
                ""
            ],
            [
                "is_active",
                ""
            ]
        ]
    ],
    [
        "memberships",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "plan_name",
                ""
            ],
            [
                "price",
                ""
            ],
            [
                "start_date",
                ""
            ],
            [
                "end_date",
                ""
            ],
            [
                "status",
                ""
            ]
        ]
    ],
    [
        "trainer_assignments",
        [
            [
                "id",
                "PK"
            ],
            [
                "trainer_id",
                "FK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "assigned_at",
                ""
            ],
            [
                "status",
                ""
            ]
        ]
    ],
    [
        "attendance",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "check_in_time",
                ""
            ],
            [
                "check_in_date",
                ""
            ],
            [
                "check_out_time",
                ""
            ],
            [
                "expires_at",
                ""
            ]
        ]
    ],
    [
        "check_ins",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "check_in_time",
                ""
            ]
        ]
    ],
    [
        "workout_logs",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "exercise_name",
                ""
            ],
            [
                "sets",
                ""
            ],
            [
                "reps",
                ""
            ],
            [
                "weight",
                ""
            ],
            [
                "weight_kg",
                ""
            ],
            [
                "duration_minutes",
                ""
            ],
            [
                "duration_seconds",
                ""
            ],
            [
                "workout_name",
                ""
            ],
            [
                "total_calories",
                ""
            ],
            [
                "notes",
                ""
            ],
            [
                "proof_url",
                ""
            ],
            [
                "proof_type",
                ""
            ],
            [
                "logged_at",
                ""
            ]
        ]
    ],
    [
        "body_measurements",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "weight_kg",
                ""
            ],
            [
                "height_cm",
                ""
            ],
            [
                "body_fat_pct",
                ""
            ],
            [
                "chest_cm",
                ""
            ],
            [
                "waist_cm",
                ""
            ],
            [
                "hips_cm",
                ""
            ],
            [
                "arm_cm",
                ""
            ],
            [
                "thigh_cm",
                ""
            ],
            [
                "measured_at",
                ""
            ]
        ]
    ],
    [
        "goals",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "title",
                ""
            ],
            [
                "description",
                ""
            ],
            [
                "target_value",
                ""
            ],
            [
                "current_value",
                ""
            ],
            [
                "unit",
                ""
            ],
            [
                "deadline",
                ""
            ],
            [
                "status",
                ""
            ]
        ]
    ],
    [
        "trainer_feedback",
        [
            [
                "id",
                "PK"
            ],
            [
                "trainer_id",
                "FK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "content",
                ""
            ],
            [
                "created_at",
                ""
            ]
        ]
    ],
    [
        "member_goal_plans",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "trainer_id",
                "FK"
            ],
            [
                "start_date",
                ""
            ],
            [
                "end_date",
                ""
            ],
            [
                "timeframe",
                ""
            ],
            [
                "notes",
                ""
            ],
            [
                "food_plan",
                ""
            ],
            [
                "exercise_plan",
                ""
            ]
        ]
    ],
    [
        "plan_day_completions",
        [
            [
                "id",
                "PK"
            ],
            [
                "plan_id",
                "FK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "day_number",
                ""
            ],
            [
                "date",
                ""
            ],
            [
                "completed_exercises",
                ""
            ],
            [
                "completed_foods",
                ""
            ],
            [
                "is_complete",
                ""
            ],
            [
                "notified_member",
                ""
            ],
            [
                "notified_trainer",
                ""
            ]
        ]
    ],
    [
        "meal_records",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "meal_type",
                ""
            ],
            [
                "food_name",
                ""
            ],
            [
                "calories",
                ""
            ],
            [
                "protein_g",
                ""
            ],
            [
                "carbs_g",
                ""
            ],
            [
                "fat_g",
                ""
            ],
            [
                "photo_url",
                ""
            ],
            [
                "meal_time",
                ""
            ]
        ]
    ],
    [
        "meal_logs",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "meal_type",
                ""
            ],
            [
                "food_name",
                ""
            ],
            [
                "calories",
                ""
            ],
            [
                "protein_g",
                ""
            ],
            [
                "carbs_g",
                ""
            ],
            [
                "fat_g",
                ""
            ],
            [
                "photo_url",
                ""
            ],
            [
                "meal_time",
                ""
            ]
        ]
    ],
    [
        "food_recommendations",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "recommended_foods",
                ""
            ],
            [
                "recommendation_type",
                ""
            ],
            [
                "generated_at",
                ""
            ]
        ]
    ],
    [
        "food_identification_logs",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "photo_url",
                ""
            ],
            [
                "ai_candidates",
                ""
            ],
            [
                "selected_food",
                ""
            ],
            [
                "member_edited",
                ""
            ],
            [
                "created_at",
                ""
            ]
        ]
    ],
    [
        "nutrition_foods",
        [
            [
                "id",
                "PK"
            ],
            [
                "food_name",
                ""
            ],
            [
                "aliases",
                ""
            ],
            [
                "category",
                ""
            ],
            [
                "serving_label",
                ""
            ],
            [
                "serving_size_g",
                ""
            ],
            [
                "calories_kcal",
                ""
            ],
            [
                "protein_g",
                ""
            ],
            [
                "carbs_g",
                ""
            ],
            [
                "fat_g",
                ""
            ],
            [
                "source",
                ""
            ]
        ]
    ],
    [
        "met_exercises",
        [
            [
                "id",
                "PK"
            ],
            [
                "name",
                ""
            ],
            [
                "category",
                ""
            ],
            [
                "met_value",
                ""
            ],
            [
                "is_ai_estimated",
                ""
            ],
            [
                "is_verified",
                ""
            ],
            [
                "confidence",
                ""
            ],
            [
                "verified_by",
                "FK"
            ],
            [
                "verified_at",
                ""
            ]
        ]
    ],
    [
        "chat_rooms",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "trainer_id",
                "FK"
            ],
            [
                "room_name",
                ""
            ],
            [
                "created_at",
                ""
            ]
        ]
    ],
    [
        "chat_messages",
        [
            [
                "id",
                "PK"
            ],
            [
                "room_id",
                "FK"
            ],
            [
                "sender_id",
                "FK"
            ],
            [
                "message_text",
                ""
            ],
            [
                "sent_at",
                ""
            ],
            [
                "read_at",
                ""
            ]
        ]
    ],
    [
        "notifications",
        [
            [
                "id",
                "PK"
            ],
            [
                "user_id",
                "FK"
            ],
            [
                "message",
                ""
            ],
            [
                "notification_type",
                ""
            ],
            [
                "is_read",
                ""
            ],
            [
                "created_at",
                ""
            ]
        ]
    ],
    [
        "predictions",
        [
            [
                "id",
                "PK"
            ],
            [
                "member_id",
                "FK"
            ],
            [
                "predicted_value",
                ""
            ],
            [
                "metric_type",
                ""
            ],
            [
                "confidence",
                ""
            ],
            [
                "generated_at",
                ""
            ]
        ]
    ],
    [
        "admin_logs",
        [
            [
                "id",
                "PK"
            ],
            [
                "admin_id",
                "FK"
            ],
            [
                "action",
                ""
            ],
            [
                "details",
                ""
            ],
            [
                "created_at",
                ""
            ]
        ]
    ],
    [
        "addresses",
        [
            [
                "member_id",
                "PKFK"
            ],
            [
                "line1",
                ""
            ],
            [
                "line2",
                ""
            ],
            [
                "city",
                ""
            ],
            [
                "state",
                ""
            ],
            [
                "postal_code",
                ""
            ],
            [
                "country",
                ""
            ]
        ]
    ]
]

# (src, dst, fk_column, optional)  src is always the many (N) side
RELATIONSHIPS = [('enrollments', 'profiles', 'confirmed_by', True), ('memberships', 'profiles', 'member_id', False), ('trainer_assignments', 'profiles', 'trainer_id', False), ('trainer_assignments', 'profiles', 'member_id', False), ('attendance', 'profiles', 'member_id', False), ('check_ins', 'profiles', 'member_id', False), ('workout_logs', 'profiles', 'member_id', False), ('body_measurements', 'profiles', 'member_id', False), ('goals', 'profiles', 'member_id', False), ('trainer_feedback', 'profiles', 'trainer_id', True), ('trainer_feedback', 'profiles', 'member_id', False), ('member_goal_plans', 'profiles', 'member_id', False), ('member_goal_plans', 'profiles', 'trainer_id', False), ('plan_day_completions', 'member_goal_plans', 'plan_id', False), ('plan_day_completions', 'profiles', 'member_id', False), ('meal_records', 'profiles', 'member_id', False), ('meal_logs', 'profiles', 'member_id', False), ('food_recommendations', 'profiles', 'member_id', False), ('food_identification_logs', 'profiles', 'member_id', False), ('met_exercises', 'profiles', 'verified_by', True), ('chat_rooms', 'profiles', 'member_id', False), ('chat_rooms', 'profiles', 'trainer_id', False), ('chat_messages', 'chat_rooms', 'room_id', False), ('chat_messages', 'profiles', 'sender_id', False), ('notifications', 'profiles', 'user_id', False), ('predictions', 'profiles', 'member_id', False), ('admin_logs', 'profiles', 'admin_id', False), ('addresses', 'profiles', 'member_id', False)]

COLS = dict((n, c) for n, c in ENTITIES)
ALL_NAMES = set(COLS)

LEGEND = ("PK = Primary Key   FK = Foreign Key   1 = one side   "
          "N = many side   dashed line = optional relationship")

# short verb shown on each relationship edge, keyed by the FK column
VERBS = {
    "member_id": "belongs to",
    "trainer_id": "assigned to",
    "confirmed_by": "is confirmed by",
    "verified_by": "is verified by",
    "plan_id": "is part of",
    "room_id": "posted in",
    "sender_id": "sent by",
    "user_id": "owned by",
    "admin_id": "recorded by",
}

# One entry per generated figure. rels are (src, dst, fk) keys into
# RELATIONSHIPS; `internal` edges run vertically between two satellites of
# the same column instead of to the hub; `standalone` entities have no
# foreign-key edge and carry a reference-table note instead.
PARTS = [
    dict(fig=22, slug="Accounts-Membership",
         label="Accounts, Membership and Attendance",
         left=["enrollments", "trainer_assignments", "check_ins"],
         right=["addresses", "memberships", "attendance"],
         rels=[("enrollments", "profiles", "confirmed_by"),
               ("trainer_assignments", "profiles", "trainer_id"),
               ("trainer_assignments", "profiles", "member_id"),
               ("check_ins", "profiles", "member_id"),
               ("addresses", "profiles", "member_id"),
               ("memberships", "profiles", "member_id"),
               ("attendance", "profiles", "member_id")],
         internal=[],
         standalone=[]),
    dict(fig=23, slug="Fitness-Tracking",
         label="Fitness Tracking, Goals and Trainer Feedback",
         left=["workout_logs", "body_measurements", "goals"],
         right=["member_goal_plans", "plan_day_completions", "trainer_feedback"],
         rels=[("workout_logs", "profiles", "member_id"),
               ("body_measurements", "profiles", "member_id"),
               ("goals", "profiles", "member_id"),
               ("member_goal_plans", "profiles", "member_id"),
               ("member_goal_plans", "profiles", "trainer_id"),
               ("plan_day_completions", "member_goal_plans", "plan_id"),
               ("plan_day_completions", "profiles", "member_id"),
               ("trainer_feedback", "profiles", "member_id"),
               ("trainer_feedback", "profiles", "trainer_id")],
         internal=[("plan_day_completions", "member_goal_plans", "plan_id")],
         standalone=[]),
    dict(fig=24, slug="Nutrition-Meal-Logging",
         label="Nutrition, Meal Logging and Reference Data",
         left=["meal_records", "meal_logs", "food_recommendations"],
         right=["food_identification_logs", "met_exercises", "nutrition_foods"],
         rels=[("meal_records", "profiles", "member_id"),
               ("meal_logs", "profiles", "member_id"),
               ("food_recommendations", "profiles", "member_id"),
               ("food_identification_logs", "profiles", "member_id"),
               ("met_exercises", "profiles", "verified_by")],
         internal=[],
         standalone=["nutrition_foods"]),
    dict(fig=25, slug="Communication-Administration",
         label="Communication, Notifications and Administration",
         left=["chat_rooms", "chat_messages", "notifications"],
         right=["predictions", "admin_logs"],
         rels=[("chat_rooms", "profiles", "trainer_id"),
               ("chat_rooms", "profiles", "member_id"),
               ("chat_messages", "chat_rooms", "room_id"),
               ("chat_messages", "profiles", "sender_id"),
               ("notifications", "profiles", "user_id"),
               ("predictions", "profiles", "member_id"),
               ("admin_logs", "profiles", "admin_id")],
         internal=[("chat_messages", "chat_rooms", "room_id")],
         standalone=[]),
]

BOX_W = 280
LEFT_X = 40
HUB_X = 560
RIGHT_X = 1060
TOP_Y = 130
COL_GAP = 40
PAGE_MARGIN = 40
CAP_W = 1300


def entity_value(name, columns):
    rows = ['<table border="1" cellpadding="4" cellspacing="0" width="100%">']
    rows.append('<tr><td align="center"><b>%s</b></td></tr>' % name)
    rows.append('<tr><td>------------------------------</td></tr>')
    for col, key in columns:
        if key == "PK":
            label = "<b><u>%s (PK)</u></b>" % col
        elif key == "FK":
            label = "%s (FK)" % col
        elif key == "PKFK":
            label = "<b><u>%s (PK, FK)</u></b>" % col
        else:
            label = col
        rows.append("<tr><td>%s</td></tr>" % label)
    rows.append("</table>")
    return escape("".join(rows), {'"': "&quot;"})


def vtx(cid, value, x, y, w, h, style=HDR):
    return ('<mxCell id="%s" value="%s" style="%s" vertex="1" parent="1">'
            '<mxGeometry x="%d" y="%d" width="%d" height="%d" '
            'as="geometry" /></mxCell>' % (cid, value, style, x, y, w, h))


def edge_cell(eid, s, d, label, opt, ex, ey, nx, ny):
    st = (EBASE_OPT if opt else EBASE) + (
        "exitX=%.3f;exitY=%.3f;exitDx=0;exitDy=0;"
        "entryX=%.3f;entryY=%.3f;entryDx=0;entryDy=0;" % (ex, ey, nx, ny))
    return ('<mxCell id="%s" value="%s" style="%s" edge="1" '
            'parent="1" source="%s" target="%s">'
            '<mxGeometry relative="1" as="geometry" /></mxCell>'
            % (eid, escape(label), st, s, d))


def rel_lookup():
    """(src, dst, fk) -> (dst, optional) from the master RELATIONSHIPS list."""
    lut = {}
    for src, dst, fk, opt in RELATIONSHIPS:
        lut[(src, dst, fk)] = (dst, opt)
    return lut


def layout(part):
    """Return (boxes, lut, page_w, page_h). boxes: name -> (id, x, y, w, h)."""
    lut = rel_lookup()
    height = lambda n: 44 + 20 * len(COLS[n])
    boxes = {}
    # satellite columns: stack from the top with a fixed gap
    col_x = {"left": LEFT_X, "right": RIGHT_X}
    col_bottom = {}
    for side in ("left", "right"):
        y = TOP_Y
        for n in part[side]:
            h = height(n)
            boxes[n] = ("e%d" % len(boxes), col_x[side], y, BOX_W, h)
            y += h + COL_GAP
        col_bottom[side] = y - COL_GAP
    # hub vertically centred against the taller satellite column
    hub_h = height("profiles")
    tallest = max(col_bottom["left"], col_bottom["right"]) - TOP_Y
    hub_y = TOP_Y + max(0, (tallest - hub_h) // 2)
    boxes["profiles"] = ("ehub", HUB_X, hub_y, BOX_W, hub_h)
    page_w = RIGHT_X + BOX_W + PAGE_MARGIN
    bottom = max(max(col_bottom.values()), hub_y + hub_h)
    # room for the standalone reference-table notes
    if part["standalone"]:
        bottom += 30
    page_h = bottom + PAGE_MARGIN
    return boxes, lut, page_w, page_h


def build(part):
    boxes, lut, page_w, page_h = layout(part)
    caption = "Figure %d: Entity Relationship Diagram (%s)" % (
        part["fig"], part["label"])
    cells = ['<mxCell id="0" />', '<mxCell id="1" parent="0" />']
    cells.append(vtx("cap", escape(caption), (page_w - CAP_W) // 2, 10,
                     CAP_W, 30, CAP))
    cells.append(vtx("legend", escape(LEGEND), (page_w - CAP_W) // 2, 50,
                     CAP_W, 28, CAP))
    for name, (cid, x, y, w, h) in boxes.items():
        cells.append(vtx(cid, entity_value(name, COLS[name]), x, y, w, h))
    for name in part["standalone"]:
        _, x, y, w, h = boxes[name]
        cells.append(vtx("note_" + name,
                         escape("(reference table - no foreign key)"),
                         x, y + h + 4, w, 22, NOTE))

    # --- edge anchor distribution -------------------------------------
    # Hub-facing edges are grouped per side (left / right satellite
    # column); the hub entry points are spread evenly down the hub edge
    # that faces that column, and each satellite is entered on the edge
    # facing the hub (single edge -> mid; two edges -> 0.30 / 0.70).
    internal = set(part["internal"])
    sides = {}
    for r in part["rels"]:
        if r in internal:
            continue
        src, dst, fk = r
        side = "left" if src in part["left"] else "right"
        sides.setdefault(side, []).append(r)
    hub_entry = {}
    for side, rels in sides.items():
        n = len(rels)
        for i, r in enumerate(rels):
            hub_entry[r] = (i + 1) / float(n + 1)
    # only hub-facing edges need a satellite-side anchor: internal
    # (vertical) edges use hardcoded bottom/top anchors instead
    sat_edges = {}
    for r in part["rels"]:
        if r not in internal:
            sat_edges.setdefault(r[0], []).append(r)
    sat_entry = {}
    for name, rels in sat_edges.items():
        n = len(rels)
        for i, r in enumerate(rels):
            sat_entry[r, name] = 0.5 if n == 1 else (0.3, 0.7)[i]

    for j, r in enumerate(part["rels"]):
        src, dst, fk = r
        _, opt = lut[r]
        label = "%s  |  %s  |  1 - N (%s)" % (
            VERBS[fk], fk, "optional" if opt else "mandatory")
        if r in internal:
            # vertical: source satellite bottom -> target satellite top
            cells.append(edge_cell("r%d" % j, boxes[src][0], boxes[dst][0],
                                   label, opt, 0.5, 1.0, 0.5, 0.0))
            continue
        side = "left" if src in part["left"] else "right"
        # left column: satellite exits its right edge into the hub's left
        # edge; right column: mirror image
        sat_ex = 1.0 if side == "left" else 0.0
        hub_nx = 0.0 if side == "left" else 1.0
        cells.append(edge_cell("r%d" % j, boxes[src][0], boxes["profiles"][0],
                               label, opt, sat_ex, sat_entry[r, src],
                               hub_nx, hub_entry[r]))

    doc = ('<mxfile host="app.diagrams.net" agent="Cline">'
           '<diagram id="fig%d" name="FIG %d - ERD %s">'
           '<mxGraphModel dx="3000" dy="2200" grid="1" gridSize="10" '
           'guides="1" tooltips="1" connect="1" arrows="1" fold="1" '
           'page="1" pageScale="1" pageWidth="%d" pageHeight="%d" '
           'math="0" shadow="0"><root>%s</root></mxGraphModel>'
           "</diagram></mxfile>"
           % (part["fig"], part["fig"], escape(part["label"]),
              page_w, page_h, "".join(cells)))
    path = os.path.join(OUT_DIR, "ERD-Fig%d-%s.drawio"
                        % (part["fig"], part["slug"]))
    with open(path, "w", encoding="utf-8") as f:
        f.write(doc)
    return path, caption, page_w, page_h


def validate(part, path, caption, page_w, page_h):
    problems = []
    lut = rel_lookup()
    try:
        root = ET.parse(path).getroot()
    except Exception as exc:
        return ["XML parse failed: %s" % exc]
    blob = open(path, encoding="utf-8").read()
    cells = root.findall(".//mxCell")
    edges = [c for c in cells if c.get("edge") == "1"]
    want_names = list(part["left"]) + list(part["right"]) + ["profiles"]
    missing = [n for n in want_names
                if ("&lt;b&gt;%s&lt;/b&gt;" % n) not in blob]
    if missing:
        problems.append("missing entities: %s" % ", ".join(missing))
    if caption not in blob:
        problems.append("caption %r not found" % caption)
    if LEGEND not in blob:
        problems.append("legend not found")
    if len(edges) != len(part["rels"]):
        problems.append("edge count %d != %d relationships"
                        % (len(edges), len(part["rels"])))
    n_opt = sum(1 for r in part["rels"] if lut[r][1])
    n_dash = sum(1 for c in edges if "dashed=1" in (c.get("style") or ""))
    if n_opt != n_dash:
        problems.append("dashed edges %d != optional rels %d" % (n_dash, n_opt))
    for r in part["rels"]:
        src, dst, fk = r
        opt = lut[r][1]
        label = "%s  |  %s  |  1 - N (%s)" % (
            VERBS[fk], fk, "optional" if opt else "mandatory")
        if escape(label) not in blob:
            problems.append("missing edge label: %s" % label)
    print("  Fig %d: entities=%d edges=%d optional=%d page=%dx%d %s"
          % (part["fig"], len(want_names), len(edges), n_opt,
             page_w, page_h,
             "OK" if not problems else "PROBLEMS"))
    return problems


def main():
    all_problems = []
    for part in PARTS:
        path, caption, page_w, page_h = build(part)
        problems = validate(part, path, caption, page_w, page_h)
        all_problems.extend("%s (Fig %d): %s" % (os.path.basename(path),
                                                 part["fig"], p)
                            for p in problems)
    n_rels = sum(len(p["rels"]) for p in PARTS)
    print("generated %d figures, %d/%d relationships covered"
          % (len(PARTS), n_rels, len(RELATIONSHIPS)))
    if all_problems:
        print("PROBLEMS:")
        for p in all_problems:
            print("    !! " + p)
    else:
        print("all figure validations OK")


if __name__ == "__main__":
    main()

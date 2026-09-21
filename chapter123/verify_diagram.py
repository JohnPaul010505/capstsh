import xml.etree.ElementTree as ET
import os

BASE = r"c:\capstsh"
FILES = [
    "Activity-Fig15-Member-Login-Registration.drawio",
    "Activity-Fig16-Workout-Logging.drawio",
    "Activity-Fig17-QR-CheckIn-CheckOut.drawio",
    "Activity-Fig18-Meal-Logging-AI-Analysis.drawio",
    "Activity-Fig19-Dashboard-View.drawio",
    "Activity-Fig20-Trainer-Feedback-Rating.drawio",
    "Activity-Fig21-Goal-Setting-Plan-Creation.drawio",
]


def parse_style(style):
    d = {}
    if not style:
        return d
    for part in style.split(";"):
        part = part.strip()
        if "=" in part:
            k, v = part.split("=", 1)
            d[k.strip()] = v.strip()
    return d


def tag_local(tag):
    return tag.split("}")[-1] if "}" in tag else tag


for fname in FILES:
    path = os.path.join(BASE, fname)
    print("=" * 64)
    print("FILE:", fname)

    tree = ET.parse(path)
    root = tree.getroot()
    print("  XML well-formed: YES")

    cells = [e for e in root.iter() if tag_local(e.tag) == "mxCell"]
    nodes = [c for c in cells if c.get("vertex") == "1"]
    edges = [c for c in cells if c.get("edge") == "1"]
    print("  cells total:", len(cells))
    print("  nodes:", len(nodes), " edges:", len(edges))

    pool_frames = []
    for c in nodes:
        st = parse_style(c.get("style", ""))
        if (st.get("shape") == "rectangle"
                and st.get("fillColor") == "none"
                and st.get("strokeColor") == "#000000"):
            pool_frames.append(c)
    print("  pool frames (black stroke, no fill):", len(pool_frames))
    for pf in pool_frames:
        g = pf.find("mxGeometry")
        if g is not None:
            print("    frame geometry: x=%s y=%s w=%s h=%s" % (
                pf.get("x") or g.get("x"), pf.get("y") or g.get("y"),
                g.get("width"), g.get("height")))

    dividers = [c for c in cells if parse_style(c.get("style", "")).get("shape") == "line"]
    print("  lane divider lines:", len(dividers))

    start_ellipse = [c for c in nodes
                     if parse_style(c.get("style", "")).get("shape") == "ellipse"
                     and parse_style(c.get("style", "")).get("fillColor") == "#000000"]
    print("  initial node (black ellipse):", len(start_ellipse))

    start_label = []
    end_label = []
    for c in nodes:
        v = (c.get("value") or "").strip()
        st = parse_style(c.get("style", ""))
        if not v:
            continue
        if st.get("fontStyle") == "1":
            if v.lower().startswith("start"):
                start_label.append(v)
            elif v.lower().startswith("end"):
                end_label.append(v)
    print("  'Start' label:", start_label)
    print("  'End' label:", end_label)

    yes_edges = [c for c in edges if "Yes" in (c.get("value") or "")]
    no_edges = [c for c in edges if "No" in (c.get("value") or "")]
    print("  Yes-labeled edges:", len(yes_edges), " No-labeled edges:", len(no_edges))

    node_ids = {c.get("id") for c in cells}
    bad = 0
    for e in edges:
        for attr in ("source", "target"):
            ref = e.get(attr)
            if ref and ref not in node_ids:
                bad += 1
                print("  WARNING: edge %s %s -> %s" % (e.get("id"), attr, ref))
    print("  endpoint integrity issues:", bad)

    ok = (len(pool_frames) >= 1
          and len(dividers) >= 1
          and len(start_ellipse) >= 1
          and bool(start_label)
          and bool(end_label)
          and bad == 0)
    print("  SWIMLANE CHECK PASS:", ok)

print("=" * 64)
cap = os.path.join(BASE, "Activity-Captions-and-Narratives.md")
print("CAPTIONS FILE:", os.path.basename(cap))
print("  exists:", os.path.exists(cap), " size:", os.path.getsize(cap), "bytes")

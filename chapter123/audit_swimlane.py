import xml.etree.ElementTree as ET
import os

base = "c:\\capstsh\\"
files = [
    "Activity-Fig15-Member-Login-Registration.drawio",
    "Activity-Fig16-Workout-Logging.drawio",
    "Activity-Fig17-QR-CheckIn-CheckOut.drawio",
    "Activity-Fig18-Meal-Logging-AI-Analysis.drawio",
    "Activity-Fig19-Dashboard-View.drawio",
    "Activity-Fig20-Trainer-Feedback-Rating.drawio",
    "Activity-Fig21-Goal-Setting-Plan-Creation.drawio",
]

def find_all(path, predicate):
    t = ET.parse(path)
    root = t.getroot()
    results = []
    for e in root.iter():
        if e.tag.endswith("mxCell"):
            if predicate(e):
                results.append(e)
    return results

def has_black_fill(e):
    style = e.get("style", "")
    return "fillColor=#000000" in style and "ellipse" in style.split(";")[0]

def is_start_circle(e):
    return e.get("id") == "ini" and has_black_fill(e)

def is_end_bullseye_outer(e):
    return e.get("id") == "end2" and has_black_fill(e)

def is_pool_frame(e):
    style = e.get("style", "")
    return (e.get("vertex") == "1"
            and "fillColor=none" in style
            and "strokeColor=#000000" in style
            and "rounded=0" in style)

def is_lane_header(e, name):
    val = (e.get("value") or "").strip()
    style = e.get("style", "")
    return (val == name
            and "fontStyle=1" in style
            and "fontSize=13" in style
            and e.get("vertex") == "1")

def is_end_label(e):
    return (e.get("value") or "").strip() == "End" and e.get("vertex") == "1"

def is_divider_edge(e):
    style = e.get("style", "")
    return (e.get("edge") == "1"
            and "endArrow=none" in style
            and "strokeColor=#000000" in style)

def has_yes_label(e):
    return e.get("edge") == "1" and "Yes" in (e.get("value") or "")

def has_no_label(e):
    return e.get("edge") == "1" and "No" in (e.get("value") or "")

print("=== Swimlane Verification ===\n")
for f in files:
    p = os.path.join(base, f)
    print("FILE:", f)
    try:
        ET.parse(p)
        print("  XML: OK")
    except Exception as ex:
        print("  XML: FAIL -", ex)
        continue
    
    start_nodes = find_all(p, is_start_circle)
    end_bullseyes = find_all(p, is_end_bullseye_outer)
    pool_frames = find_all(p, is_pool_frame)
    
    if "Fig15" in f or "Fig16" in f or "Fig17" in f or "Fig18" in f:
        expected_headers = ["Member", "Proposed System"]
    elif "Fig19" in f:
        expected_headers = ["Member", "Trainer", "Admin", "Proposed System"]
    elif "Fig20" in f:
        expected_headers = ["Trainer", "Member", "Proposed System"]
    elif "Fig21" in f:
        expected_headers = ["Member", "Trainer", "Proposed System"]
    else:
        expected_headers = []
    
    lane_headers = []
    for h in expected_headers:
        hdrs = find_all(p, lambda e, n=h: is_lane_header(e, n))
        if hdrs:
            lane_headers.append(h)
    
    end_labels = find_all(p, is_end_label)
    dividers = find_all(p, is_divider_edge)
    yes_edges = find_all(p, has_yes_label)
    no_edges = find_all(p, has_no_label)
    
    print("  Start node (black circle):", len(start_nodes), "OK" if len(start_nodes) >= 1 else "MISSING")
    print("  End bullseye (black ellipse):", len(end_bullseyes), "OK" if len(end_bullseyes) >= 1 else "MISSING")
    print("  Pool frame:", len(pool_frames), "OK" if len(pool_frames) >= 1 else "MISSING")
    print("  Lane headers:", lane_headers, "OK" if set(lane_headers) == set(expected_headers) else "MISMATCH (expected: " + str(expected_headers) + ")")
    print("  End label box:", len(end_labels), "OK" if len(end_labels) >= 1 else "MISSING")
    print("  Divider edges:", len(dividers), "OK" if len(dividers) >= 1 else "MISSING")
    print("  Yes edges:", len(yes_edges))
    print("  No edges:", len(no_edges))
    
    all_ok = (len(start_nodes) >= 1 and len(end_bullseyes) >= 1
              and len(pool_frames) >= 1 and set(lane_headers) == set(expected_headers)
              and len(end_labels) >= 1 and len(dividers) >= 1)
    print("  Overall:", "PASS" if all_ok else "FAIL")
    print()

cap_path = os.path.join(base, "Activity-Captions-and-Narratives.md")
print("Captions file:")
print("  Exists:", os.path.exists(cap_path))
if os.path.exists(cap_path):
    print("  Size:", os.path.getsize(cap_path), "bytes")
    with open(cap_path) as f:
        content = f.read()
    for i in range(15, 22):
        fig = "Figure " + str(i)
        print("  " + fig + " mentioned:", fig in content)

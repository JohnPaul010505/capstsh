import xml.etree.ElementTree as ET
import sys

path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()


def style_dict(style):
    d = {}
    if not style:
        return d
    for part in style.split(";"):
        if "=" in part:
            k, v = part.split("=", 1)
            d[k.strip()] = v.strip()
    return d


def tag_local(tag):
    return tag.split("}")[-1] if "}" in tag else tag


print("=== Diagram", path, "===\n")
for e in root.iter():
    if tag_local(e.tag) != "mxCell":
        continue
    sid = e.get("id")
    st = style_dict(e.get("style", ""))
    val = (e.get("value") or "").strip()
    v = e.get("vertex")
    ed = e.get("edge")
    shape = st.get("shape", "")
    stroke = st.get("strokeColor", "")
    fill = st.get("fillColor", "")
    if ed == "1":
        print("%s EDGE src=%s tgt=%s label=[%s]" % (sid, e.get("source", "?"), e.get("target", "?"), val))
    elif v == "1":
        extra = ""
        if shape:
            extra = "shape=%s" % shape
        print("%s NODE %s val=[%s] stroke=%s fill=%s" % (sid, extra, val, stroke, fill))
PYEOF

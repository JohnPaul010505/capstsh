"""Integrity check for every .drawio file in this folder.

XML well-formedness alone is NOT enough. A hand edit can lose the "<" on
<mxGeometry> and the file still parses - the geometry just degrades into
text inside the cell, and draw.io then refuses to open it with an
"atob" error. So each edge cell must have an mxGeometry CHILD element,
and no mxGeometry may appear as bare text. Dangling source/target
references are caught too.

Usage:  python verify_drawio_integrity.py [dir]
Exit 0 = all clean, 1 = problems found.
"""
import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

# "> <newline/space> mxGeometry" means the "<" was lost
BARE = re.compile(r">\s+mxGeometry")


def check(path):
    """Return (name, [problems]) for one file."""
    name = os.path.basename(path)
    problems = []
    src = open(path, encoding="utf-8").read()

    for match in BARE.finditer(src):
        line = src[:match.start()].count("\n") + 1
        problems.append("line %d: mxGeometry written as text (missing '<')"
                        % line)

    try:
        root = ET.fromstring(src)
    except ET.ParseError as exc:
        return name, problems + ["XML parse failed: %s" % exc], 0

    ids = {c.get("id") for c in root.findall(".//mxCell") if c.get("id")}
    edges = [c for c in root.findall(".//mxCell") if c.get("edge") == "1"]

    for cell in edges:
        cid = cell.get("id")
        geo = cell.find("mxGeometry")
        if geo is None:
            problems.append("edge %s has NO mxGeometry child element" % cid)
        elif geo.get("as") != "geometry":
            problems.append("edge %s: mxGeometry lacks as=\"geometry\"" % cid)
        for end in ("source", "target"):
            ref = cell.get(end)
            if ref and ref not in ids:
                problems.append("edge %s: %s=%r points at a missing cell"
                                % (cid, end, ref))
    return name, problems, len(edges)


def main():
    base = sys.argv[1] if len(sys.argv) > 1 \
        else os.path.dirname(os.path.abspath(__file__))
    files = sorted(glob.glob(os.path.join(base, "*.drawio")))
    if not files:
        print("no .drawio files in %s" % base)
        return 1

    bad = 0
    total_edges = 0
    for path in files:
        name, problems, n_edges = check(path)
        total_edges += n_edges
        if problems:
            bad += 1
            print("FAIL  %s" % name)
            for p in problems:
                print("        %s" % p)

    print("\n%d files checked, %d edges, %d file(s) with problems"
          % (len(files), total_edges, bad))
    if bad:
        print("RESULT: problems found")
        return 1
    print("RESULT: all well-formed, every edge has real geometry")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

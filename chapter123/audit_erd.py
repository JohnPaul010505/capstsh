# -*- coding: utf-8 -*-
"""Audit the four split ERD draw.io files (Figures 22-25) against the
migration schema and the caption/narrative document."""
import importlib.util
import os
import re
import xml.etree.ElementTree as ET

BASE = r"c:\capstsh"
GEN = os.path.join(BASE, "generate_erd_drawio.py")
CAP = os.path.join(BASE, "ERD-Captions-and-Narratives.md")

RESULTS = []


def check(cond, msg):
    RESULTS.append((bool(cond), msg))


# import the generator as data-only (main() is guarded by __name__)
_spec = importlib.util.spec_from_file_location("gen", GEN)
gen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(gen)

GEN_RELS = set((s, d, f, bool(o)) for s, d, f, o in gen.RELATIONSHIPS)
GEN_ENTS = set(n for n, _ in gen.ENTITIES)


def load(path):
    root = ET.parse(path).getroot()
    cells = root.findall(".//mxCell")
    verts = dict((c.get("id"), c) for c in cells if c.get("vertex") == "1")
    edges = [c for c in cells if c.get("edge") == "1"
             and "endArrow=open" in (c.get("style") or "")]
    return root, verts, edges


def ent_name(vert):
    # ET.parse already unescapes &lt; back to <, so match real tags
    m = re.search(r"<b>([a-z_0-9]+)</b>", vert.get("value") or "")
    return m.group(1) if m else None


def rect(vert):
    g = vert.find("mxGeometry")
    if g is None:
        return None
    return tuple(float(g.get(k)) for k in ("x", "y", "width", "height"))


def overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


def audit_part(part):
    fname = "ERD-Fig%d-%s.drawio" % (part["fig"], part["slug"])
    path = os.path.join(BASE, fname)
    tag = "Fig %d" % part["fig"]
    check(os.path.isfile(path), "%s: %s exists" % (tag, fname))
    if not os.path.isfile(path):
        return set(), set()
    try:
        root, verts, edges = load(path)
        check(True, "%s: XML well-formed" % tag)
    except Exception as exc:
        check(False, "%s: XML parse failed: %s" % (tag, exc))
        return set(), set()

    caption = "Figure %d: Entity Relationship Diagram (%s)" % (
        part["fig"], part["label"])
    blob = open(path, encoding="utf-8").read()
    check(caption in blob, "%s: caption cell %r present" % (tag, caption))
    check(gen.LEGEND in blob, "%s: legend cell present" % tag)

    names = set(n for n in (ent_name(v) for v in verts.values()) if n)
    want = set(part["left"]) | set(part["right"]) | {"profiles"}
    check(want <= names, "%s: all %d expected entities present"
          % (tag, len(want)))
    check("profiles" in names, "%s: hub entity profiles present" % tag)
    extra = names - want
    check(not extra, "%s: no unexpected entities%s"
          % (tag, "" if not extra else " (%s)" % ", ".join(sorted(extra))))

    # expected relationship set for this part
    lut = {}
    for s, d, f, o in gen.RELATIONSHIPS:
        lut[(s, d, f)] = bool(o)
    want_rels = set()
    for r in part["rels"]:
        s, d, f = r
        want_rels.add((s, d, f, lut[r]))
    check(len(part["rels"]) == len(want_rels),
          "%s: no duplicate rels in generator PARTS" % tag)

    # resolve every drawn edge back to (src, dst, fk, optional)
    drawn = set()
    drawn_list = []
    problems = []
    for e in edges:
        sv, tv = verts.get(e.get("source")), verts.get(e.get("target"))
        if sv is None or tv is None:
            problems.append("edge %s has unresolved endpoints" % e.get("id"))
            continue
        s, d = ent_name(sv), ent_name(tv)
        m = re.search(r"\|\s*([a-z_]+)\s*\|\s*1 - N \((optional|mandatory)\)",
                      e.get("value") or "")
        if not m:
            problems.append("edge %s label missing fk/cardinality"
                            % e.get("id"))
            continue
        fk, opt = m.group(1), m.group(2) == "optional"
        dashed = "dashed=1" in (e.get("style") or "")
        if dashed != opt:
            problems.append("edge %s dashed flag != optional label" % e.get("id"))
        drawn.add((s, d, fk, opt))
        drawn_list.append((s, d, fk, opt))
    check(not problems, "%s: every edge resolves to a labelled relationship%s"
          % (tag, "" if not problems else " -- " + "; ".join(problems)))
    check(len(edges) == len(part["rels"]),
          "%s: edge count %d == %d" % (tag, len(edges), len(part["rels"])))
    check(drawn == want_rels,
          "%s: drawn relationships match the schema subset exactly" % tag)

    # geometry: entity boxes must not overlap; caption/legend stay clear
    boxes = dict((ent_name(v), rect(v)) for v in verts.values() if ent_name(v))
    keys = sorted(boxes)
    bad = [(a, b) for i, a in enumerate(keys) for b in keys[i + 1:]
           if overlap(boxes[a], boxes[b])]
    check(not bad, "%s: no overlapping entity boxes%s"
          % (tag, "" if not bad else " -- %s" % bad))
    cap_v, leg_v = verts.get("cap"), verts.get("legend")
    ok_cap = cap_v is not None and not any(overlap(rect(cap_v), r)
                                           for r in boxes.values())
    ok_leg = leg_v is not None and not any(overlap(rect(leg_v), r)
                                           for r in boxes.values())
    check(ok_cap and ok_leg, "%s: caption/legend cells clear of all boxes" % tag)

    if part["standalone"]:
        for name in part["standalone"]:
            note = verts.get("note_" + name)
            check(note is not None
                  and "no foreign key" in (note.get("value") or ""),
                  "%s: standalone reference-table note for %s present"
                  % (tag, name))
            touched = [e for e in edges
                       if name in (ent_name(verts.get(e.get("source"))),
                                   ent_name(verts.get(e.get("target"))))]
            check(not touched,
                  "%s: %s has no FK edge (standalone)" % (tag, name))

    return names, drawn_list


def main():
    all_ents, all_rels = set(), []
    for part in gen.PARTS:
        names, rels = audit_part(part)
        all_ents |= names
        all_rels.extend(rels)

    # ---- set-level coverage across the four parts --------------------
    check(len(all_ents) == len(GEN_ENTS) and all_ents == GEN_ENTS,
          "union of entities across parts == all 24 schema entities"
          " (found %d)" % len(all_ents))
    check(len(all_rels) == len(set(all_rels)),
          "no relationship drawn in more than one part"
          " (%d drawn, %d unique)" % (len(all_rels), len(set(all_rels))))
    check(set(all_rels) == GEN_RELS,
          "union of relationships == all 28 schema relationships"
          " (found %d unique)" % len(set(all_rels)))

    fig24 = os.path.join(BASE, "ERD-Fig24-Nutrition-Meal-Logging.drawio")
    check(os.path.isfile(fig24) and "nutrition_foods" in open(fig24,
          encoding="utf-8").read(), "nutrition_foods present in Figure 24")

    # ---- captions and narratives document ----------------------------
    if os.path.isfile(CAP):
        cap = open(CAP, encoding="utf-8").read()
        for part in gen.PARTS:
            sec = "## Figure %d" % part["fig"]
            i = cap.find(sec)
            j = cap.find("\n## ", i + 1)
            body = cap[i:j if j > i else len(cap)]
            check(i >= 0 and "**Caption:**" in body and "**Narrative:**" in body,
                  "captions doc: Figure %d section with caption + narrative"
                  % part["fig"])
            check(part["label"] in body,
                  "captions doc: Figure %d mentions module label %r"
                  % (part["fig"], part["label"]))
        check("of Proposed System" not in cap,
              "captions doc: old single-figure caption removed")
        check("Figure 26" in cap,
              "captions doc: notes that section 3.8 starts at Figure 26")
    else:
        check(False, "captions doc exists")

    # ---- report ------------------------------------------------------
    print("coverage table")
    print("  %-8s %-10s %-6s %-9s" % ("figure", "entities", "rels", "optional"))
    for part in gen.PARTS:
        n_opt = sum(1 for r in part["rels"]
                    if [x for x in gen.RELATIONSHIPS
                        if (x[0], x[1], x[2]) == r][0][3])
        print("  %-8s %-10s %-6s %-9s" % (
            "Fig %d" % part["fig"],
            len(part["left"]) + len(part["right"]) + 1,
            len(part["rels"]), n_opt))
    print("  %-8s %-10s %-6s %-9s" % (
        "total", "%d unique" % len(all_ents), len(set(all_rels)),
        sum(1 for _, _, _, o in all_rels if o)))

    failed = 0
    for passed, message in RESULTS:
        print("[%s] %s" % ("PASS" if passed else "FAIL", message))
        if not passed:
            failed += 1
    print("result: %s (%d/%d passed)"
          % ("OK" if failed == 0 else "PROBLEMS", len(RESULTS) - failed,
             len(RESULTS)))


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""Audit the three Use Case draw.io files (Figures 26-28) against the
roles defined in Chapter 1 and the caption/narrative document."""
import importlib.util
import os
import re
import xml.etree.ElementTree as ET

BASE = r"c:\capstsh"
GEN = os.path.join(BASE, "generate_use_case_drawio.py")
CAP = os.path.join(BASE, "Use-Case-Captions-and-Narratives.md")

RESULTS = []


def check(cond, msg):
    RESULTS.append((bool(cond), msg))


# role-level use cases shared by more than one figure (repeated on
# purpose, like the shared AI use cases and the profiles hub in the ERD)
COMMON_UC = {"Login", "Receive Notifications"}

_spec = importlib.util.spec_from_file_location("ucgen", GEN)
ucgen = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ucgen)


def load(path):
    root = ET.parse(path).getroot()
    cells = root.findall(".//mxCell")
    verts = dict((c.get("id"), c) for c in cells if c.get("vertex") == "1")
    edges = [c for c in cells if c.get("edge") == "1"]
    model = root.find(".//mxGraphModel")
    return root, verts, edges, model


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
    fname = "UseCase-Fig%d-%s.drawio" % (part["fig"], part["slug"])
    path = os.path.join(BASE, fname)
    tag = "Fig %d" % part["fig"]
    check(os.path.isfile(path), "%s: %s exists" % (tag, fname))
    if not os.path.isfile(path):
        return
    try:
        root, verts, edges, model = load(path)
        check(True, "%s: XML well-formed" % tag)
    except Exception as exc:
        check(False, "%s: XML parse failed: %s" % (tag, exc))
        return

    caption = "Figure %d: Use Case of the %s" % (part["fig"], part["module"])
    blob = open(path, encoding="utf-8").read()
    check(caption in blob, "%s: caption cell %r present" % (tag, caption))
    check(ucgen.LEGEND in blob, "%s: legend cell present" % tag)
    check(ucgen.SYSTEM in blob, "%s: system boundary label present" % tag)

    assoc = part["columns"]["assoc"]
    inc = part["columns"]["inc"]
    want_actors = [part["actor"]] + list(part["secondary"])
    got_actors = sorted(v.get("value") for v in verts.values()
                        if "umlActor" in (v.get("style") or ""))
    check(got_actors == sorted(want_actors),
          "%s: actors == %s (found %s)" % (tag, want_actors, got_actors))

    ovals = dict((k[3:], v) for k, v in verts.items() if k.startswith("uc_"))
    check(sorted(ovals) == sorted(assoc + inc),
          "%s: ovals == assoc + shared lists exactly (%d ovals)"
          % (tag, len(ovals)))

    # association edges: primary actor -> every assoc use case, exactly once
    prim = "act_" + part["actor"]
    as_ok, as_missing = 0, []
    for name in assoc:
        hits = [e for e in edges if "endArrow=none" in (e.get("style") or "")
                and e.get("source") == prim and e.get("target") == "uc_" + name]
        if len(hits) == 1:
            as_ok += 1
        else:
            as_missing.append((name, len(hits)))
    check(not as_missing,
          "%s: primary actor associated with all %d use cases exactly once%s"
          % (tag, len(assoc), "" if not as_missing
             else " -- " + str(as_missing)))
    # secondary associations
    for sec in part["secondary"]:
        links = [e for e in edges if "endArrow=none" in (e.get("style") or "")
                 and e.get("source") == "act_" + sec]
        check(len(links) >= 1,
              "%s: secondary actor %s has association(s)" % (tag, sec))

    # include/extend edges: dashed, open arrow, labelled, correct endpoints
    prob = []
    for base, target in part["includes"]:
        hits = [e for e in edges if "dashed=1" in (e.get("style") or "")
                and "endArrow=open" in (e.get("style") or "")
                and e.get("source") == "uc_" + base
                and e.get("target") == "uc_" + target
                and "\u00abinclude\u00bb" in (e.get("value") or "")]
        if len(hits) != 1:
            prob.append("include %s->%s x%d" % (base, target, len(hits)))
    for extension, base in part["extends"]:
        hits = [e for e in edges if "dashed=1" in (e.get("style") or "")
                and "endArrow=open" in (e.get("style") or "")
                and e.get("source") == "uc_" + extension
                and e.get("target") == "uc_" + base
                and "\u00abextend\u00bb" in (e.get("value") or "")]
        if len(hits) != 1:
            prob.append("extend %s->%s x%d" % (extension, base, len(hits)))
    check(not prob, "%s: every include/extend drawn once, dashed + labelled%s"
          % (tag, "" if not prob else " -- " + "; ".join(prob)))

    # no orphan ovals; shared ovals reached only via dependencies
    touched = set()
    for e in edges:
        touched.add(e.get("source"))
        touched.add(e.get("target"))
    orphans = [n for n in assoc + inc if ("uc_" + n) not in touched]
    check(not orphans, "%s: no orphan use cases%s"
          % (tag, "" if not orphans else " -- " + ", ".join(orphans)))

    # geometry: ovals do not overlap each other or the actors;
    # caption/legend stay clear; everything inside the page
    orects = dict((n, rect(v)) for n, v in ovals.items())
    arects = dict((v.get("value"), rect(v)) for v in verts.values()
                  if "umlActor" in (v.get("style") or ""))
    keys = sorted(orects)
    bad = [(a, b) for i, a in enumerate(keys) for b in keys[i + 1:]
           if overlap(orects[a], orects[b])]
    check(not bad, "%s: no overlapping use case ovals%s"
          % (tag, "" if not bad else " -- %s" % bad))
    bad2 = [(a, b) for a in orects for b in arects
            if overlap(orects[a], arects[b])]
    check(not bad2, "%s: no oval overlaps an actor%s"
          % (tag, "" if not bad2 else " -- %s" % bad2))
    clear_ok = True
    for cid in ("cap", "legend"):
        v = verts.get(cid)
        if v is None:
            clear_ok = False
            continue
        r = rect(v)
        for other in list(orects.values()) + list(arects.values()) \
                + [rect(verts["bound"])]:
            if overlap(r, other):
                clear_ok = False
    check(clear_ok, "%s: caption/legend cells clear of all shapes" % tag)
    try:
        pw, ph = float(model.get("pageWidth")), float(model.get("pageHeight"))
        inside = all(r[0] >= 0 and r[1] >= 0
                     and r[0] + r[2] <= pw and r[1] + r[3] <= ph
                     for r in list(orects.values()) + list(arects.values()))
        check(inside, "%s: all shapes inside page bounds %dx%d"
              % (tag, int(pw), int(ph)))
    except Exception as exc:
        check(False, "%s: page bounds check failed: %s" % (tag, exc))

    # extend pair adjacency (extension directly below its base)
    adj = []
    for extension, base in part["extends"]:
        ry = rect(ovals[extension])[1]
        by = rect(ovals[base])[1]
        if not (ry > by and ry - by <= ucgen.OVAL_H + ucgen.ROW_GAP
                + ucgen.EXT_EXTRA + 1):
            adj.append((extension, base))
    check(not adj, "%s: extend extensions sit directly below their base%s"
          % (tag, "" if not adj else " -- " + str(adj)))


def main():
    assoc_union = []
    inc_union = []
    for part in ucgen.FIGS:
        audit_part(part)
        assoc_union.extend(part["columns"]["assoc"])
        inc_union.extend(part["columns"]["inc"])

    # ---- cross-figure coverage ---------------------------------------
    specific = [n for n in assoc_union if n not in COMMON_UC]
    check(len(specific) == len(set(specific)),
          "role-specific use cases appear in exactly one figure"
          " (%d drawn, %d unique)" % (len(specific), len(set(specific))))
    dups = set(n for n in assoc_union if assoc_union.count(n) > 1)
    check(dups == COMMON_UC,
          "only the common role use cases repeat across figures"
          " (repeats: %s)" % (", ".join(sorted(dups)) or "none"))
    check(len(assoc_union) == 40,
          "all 40 role use case slots covered (found %d)" % len(assoc_union))
    inc_names = set(inc_union)
    check(inc_names == {"Estimate MET Energy Expenditure", "Identify Food Photo",
                        "Generate Food Recommendation", "Compute Nutrient Breakdown",
                        "Generate Goal Suggestion", "Generate Progress Prediction",
                        "Assess Retention Risk", "Search MET Exercise Catalog",
                        "Detect Inactive Members"},
          "shared AI use case pool matches the ai-service endpoints")
    per_fig_inc = [set(p["columns"]["inc"]) for p in ucgen.FIGS]
    check(all(set(t for _, t in p["includes"]) == s
              for p, s in zip(ucgen.FIGS, per_fig_inc)),
          "each figure's shared ovals == its include targets")
    check(all(b in p["columns"]["assoc"]
              for p in ucgen.FIGS for b, _ in p["includes"]
              + p["extends"]),
          "every dependency base is an actor-associated use case")
    actors = set(p["actor"] for p in ucgen.FIGS) | set(
        s for p in ucgen.FIGS for s in p["secondary"])
    check(actors == {"Member", "Trainer", "Admin", "Gemini API"},
          "actor roster covered: Member, Trainer, Admin (+ Gemini API secondary)")

    # ---- captions and narratives document ----------------------------
    if os.path.isfile(CAP):
        cap = open(CAP, encoding="utf-8").read()
        check("3.8 USE CASE" in cap, "captions doc: 3.8 USE CASE heading present")
        for part in ucgen.FIGS:
            sec = "## Figure %d" % part["fig"]
            i = cap.find(sec)
            j = cap.find("\n## ", i + 1)
            body = cap[i:j if j > i else len(cap)]
            caption = "Figure %d: Use Case of the %s" % (part["fig"],
                                                         part["module"])
            check(i >= 0 and "**Caption:**" in body and "**Narrative:**" in body,
                  "captions doc: Figure %d section with caption + narrative"
                  % part["fig"])
            check(caption in body,
                  "captions doc: Figure %d caption text matches generator"
                  % part["fig"])
            check(part["actor"] in body and "access rights" in body,
                  "captions doc: Figure %d covers %s access rights"
                  % (part["fig"], part["actor"]))
        check("Gemini API" in cap and "secondary actor" in cap,
              "captions doc: Gemini API secondary actor explained")
        check("\u00abinclude\u00bb" in cap and "\u00abextend\u00bb" in cap,
              "captions doc: include/extend notation explained")
    else:
        check(False, "captions doc exists")

    # ---- report ------------------------------------------------------
    print("coverage table")
    print("  %-8s %-9s %-7s %-8s %-9s %-8s" % (
        "figure", "actor", "assoc", "shared", "includes", "extends"))
    for part in ucgen.FIGS:
        print("  %-8s %-9s %-7s %-8s %-9s %-8s" % (
            "Fig %d" % part["fig"], part["actor"],
            len(part["columns"]["assoc"]), len(part["columns"]["inc"]),
            len(part["includes"]), len(part["extends"])))
    print("  %-8s %-9s %-7s %-8s %-9s %-8s" % (
        "total", "3+1", len(assoc_union), len(inc_union), "-", "-"))

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

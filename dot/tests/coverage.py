#!/usr/bin/env python3
"""Coverage for dot, two kinds, one report.

line coverage   which lines of dot ran, across the unit tests (kcov's cobertura.xml, which also
                says which lines are code at all) and every distro of the matrix (bash xtrace
                files from DOT_TRACE, since kcov is not packaged everywhere)
item coverage   every manifest item (package, link, config check, service...) on every distro,
                from the `dot verify --report` JSON lines: pass / fail / not applicable

    coverage.py --cobertura FILE --runs DIR [--md OUT.md] [--json OUT.json]
                [--min-lines PCT] [--min-items PCT]

Exits 1 when a minimum is given and not met.
"""
import argparse
import collections
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

TRACE_LINE = re.compile(r"^\++(\S+?):(\d+): ")


def rel(path):
    """Any absolute path into a dot checkout → dot-relative path (lib/core.sh)."""
    m = re.search(r"(?:^|/)dot/((?:bin|lib|modules|hosts)/.*)$", path)
    return m.group(1) if m else None


def load_cobertura(path):
    """{file: {line: hits}} for every line kcov considers executable."""
    lines = collections.defaultdict(dict)
    root = ET.parse(path).getroot()
    for cls in root.iter("class"):
        f = rel("dot/" + cls.get("filename"))
        if not f:
            continue
        for ln in cls.iter("line"):
            lines[f][int(ln.get("number"))] = int(ln.get("hits"))
    return lines


def load_traces(runs):
    """{file: set(lines)} executed in the containers, plus which run touched what."""
    hit = collections.defaultdict(set)
    per_run = {}
    for t in sorted(glob.glob(os.path.join(runs, "*.trace"))):
        name = os.path.basename(t)[: -len(".trace")]
        seen = collections.defaultdict(set)
        with open(t, errors="replace") as fh:
            for line in fh:
                m = TRACE_LINE.match(line)
                if not m:
                    continue
                f = rel(m.group(1))
                if f:
                    seen[f].add(int(m.group(2)))
        for f, s in seen.items():
            hit[f] |= s
        per_run[name] = seen
    return hit, per_run


def load_items(runs):
    """[(distro, record)] from every verify report."""
    out = []
    for r in sorted(glob.glob(os.path.join(runs, "*.jsonl"))):
        name = os.path.basename(r)[: -len(".jsonl")]
        with open(r) as fh:
            for line in fh:
                line = line.strip()
                if line:
                    rec = json.loads(line)
                    out.append((name, rec))
    return out


def pct(a, b):
    return 100.0 * a / b if b else 100.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cobertura")
    ap.add_argument("--runs", required=True)
    ap.add_argument("--md")
    ap.add_argument("--json")
    ap.add_argument("--min-lines", type=float)
    ap.add_argument("--min-items", type=float)
    a = ap.parse_args()

    code = load_cobertura(a.cobertura) if a.cobertura and os.path.exists(a.cobertura) else {}
    traced, per_run = load_traces(a.runs)

    # line coverage: kcov decides what is code; a line counts when the unit tests or any distro ran it
    files = {}
    for f, lines in sorted(code.items()):
        unit = {n for n, h in lines.items() if h > 0}
        e2e = traced.get(f, set()) & set(lines)
        files[f] = {
            "lines": len(lines),
            "unit": len(unit),
            "e2e": len(e2e),
            "covered": len(unit | e2e),
            "uncovered": sorted(set(lines) - unit - e2e),
        }
    total = sum(v["lines"] for v in files.values())
    covered = sum(v["covered"] for v in files.values())
    unit_total = sum(v["unit"] for v in files.values())

    # item coverage: item × run
    items = load_items(a.runs)
    runs = sorted({r for r, _ in items})
    grid = collections.defaultdict(dict)
    for r, rec in items:
        grid[(rec["kind"], rec["item"])][r] = rec
    per_run_items = {}
    for r in runs:
        res = [rec["result"] for (rr, rec) in items if rr == r]
        p, fl = res.count("pass"), res.count("fail")
        per_run_items[r] = {"pass": p, "fail": fl, "skip": res.count("skip"), "pct": pct(p, p + fl)}
    ip = sum(v["pass"] for v in per_run_items.values())
    ifl = sum(v["fail"] for v in per_run_items.values())

    summary = {
        "lines": {"total": total, "covered": covered, "pct": pct(covered, total),
                  "unit_pct": pct(unit_total, total), "files": files},
        "items": {"checks": ip + ifl, "pass": ip, "fail": ifl, "pct": pct(ip, ip + ifl),
                  "runs": per_run_items, "distinct": len(grid)},
    }

    md = []
    md.append("# dot coverage\n")
    md.append(f"**Lines:** {summary['lines']['pct']:.1f}% ({covered}/{total}) · unit tests alone "
              f"{summary['lines']['unit_pct']:.1f}% · plus {len(per_run)} distro run(s)\n")
    md.append(f"**Items:** {summary['items']['pct']:.1f}% ({ip}/{ip + ifl} checks pass) · "
              f"{len(grid)} distinct items over {len(runs)} run(s)\n")
    md.append("\n## Items by run\n")
    md.append("| run | pass | fail | n/a | % |\n|---|---:|---:|---:|---:|")
    for r, v in per_run_items.items():
        md.append(f"| {r} | {v['pass']} | {v['fail']} | {v['skip']} | {v['pct']:.0f}% |")
    if runs:
        md.append("\n## Item × run\n")
        md.append("✓ pass · ✗ fail · – not applicable · blank: not part of that run's host\n")
        md.append("| item | " + " | ".join(runs) + " |")
        md.append("|---|" + "---|" * len(runs))
        sym = {"pass": "✓", "fail": "✗", "skip": "–"}
        for (kind, item), cells in sorted(grid.items()):
            row = [sym[cells[r]["result"]] if r in cells else "" for r in runs]
            md.append(f"| `{kind}` {item} | " + " | ".join(row) + " |")
        fails = [(r, rec) for r, rec in items if rec["result"] == "fail"]
        if fails:
            md.append("\n## Failures\n")
            for r, rec in fails:
                md.append(f"- **{r}** `{rec['kind']}` {rec['item']}: {rec.get('detail', '')}")
    md.append("\n## Lines by file\n")
    md.append("| file | lines | unit | +distros | covered |\n|---|---:|---:|---:|---:|")
    for f, v in sorted(files.items(), key=lambda kv: pct(kv[1]["covered"], kv[1]["lines"])):
        md.append(f"| {f} | {v['lines']} | {v['unit']} | {v['covered'] - v['unit']} | "
                  f"{pct(v['covered'], v['lines']):.0f}% |")
    text = "\n".join(md) + "\n"

    if a.md:
        with open(a.md, "w") as fh:
            fh.write(text)
    if a.json:
        with open(a.json, "w") as fh:
            json.dump(summary, fh, indent=1)
    print(f"lines {summary['lines']['pct']:.1f}% ({covered}/{total}, unit alone "
          f"{summary['lines']['unit_pct']:.1f}%) · items {summary['items']['pct']:.1f}% "
          f"({ip}/{ip + ifl}) over {len(runs)} run(s)")

    rc = 0
    if a.min_lines is not None and summary["lines"]["pct"] < a.min_lines:
        print(f"line coverage {summary['lines']['pct']:.1f}% is below {a.min_lines}%", file=sys.stderr)
        rc = 1
    if a.min_items is not None and summary["items"]["pct"] < a.min_items:
        print(f"item coverage {summary['items']['pct']:.1f}% is below {a.min_items}%", file=sys.stderr)
        rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())

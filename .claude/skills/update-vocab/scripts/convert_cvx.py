#!/usr/bin/env python3
"""Convert the CDC CVX code list (pipe-delimited cvx.txt) to vaccines.json.

Usage: convert_cvx.py cvx.txt vaccines.json [--cols SHORT,FULL,CODE,STATUS]

Output schema (must match VaccineEntry in
ios/GeethaHealth/Services/VocabularyStore.swift):
  [{"n": short name, "f": full clinical name, "c": CVX code, "st": status}, ...]

cvx.txt has no header, so columns are auto-detected: the code column is the
one that's consistently a 1-4 digit integer, the status column matches known
CVX statuses, and of the remaining text columns the shorter-on-average is the
short name. Pass --cols with 0-based indices to override if detection fails.
Sorted case-insensitively by short name; compact single-line JSON.
"""
import json
import re
import sys

STATUSES = {"Active", "Inactive", "Pending", "Never Active", "Non-US", "non-US"}


def detect_columns(rows):
    ncols = min(len(r) for r in rows)
    def frac(i, pred):
        return sum(1 for r in rows if pred(r[i].strip())) / len(rows)
    code = max(range(ncols), key=lambda i: frac(i, lambda v: v.isdigit() and len(v) <= 4))
    status = max(range(ncols), key=lambda i: frac(i, lambda v: v in STATUSES))
    if frac(code, lambda v: v.isdigit()) < 0.9 or frac(status, lambda v: v in STATUSES) < 0.9:
        sys.exit("could not auto-detect code/status columns — inspect cvx.txt "
                 "and pass --cols SHORT,FULL,CODE,STATUS")
    def is_name(v):
        return len(v) > 2 and v not in ("True", "False") \
            and not re.match(r"\d{4}/\d{2}/\d{2}$", v)
    text = [i for i in range(ncols) if i not in (code, status)
            and frac(i, is_name) > 0.9]
    # the two longest text columns are the names; notes/date/flag columns
    # are mostly empty or excluded above
    text.sort(key=lambda i: sum(len(r[i]) for r in rows), reverse=True)
    if len(text) < 2:
        sys.exit("could not find two name columns — pass --cols")
    short, full = sorted(text[:2], key=lambda i: sum(len(r[i]) for r in rows))
    return short, full, code, status


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    src, dst = argv[1], argv[2]
    with open(src, encoding="utf-8-sig", errors="replace") as f:
        rows = [line.rstrip("\n").split("|") for line in f if line.strip()]
    if "--cols" in argv:
        short, full, code, status = map(int, argv[argv.index("--cols") + 1].split(","))
    else:
        short, full, code, status = detect_columns(rows)
        print(f"detected columns: short={short} full={full} code={code} status={status}")

    # CVX also lists non-vaccine products (immune globulins etc.) flagged by a
    # True/False column — the app only wants actual vaccines
    nonvax = next((i for i in range(min(len(r) for r in rows))
                   if i not in (short, full, code, status)
                   and all(r[i].strip() in ("True", "False") for r in rows)), None)
    out = []
    for r in rows:
        if max(short, full, code, status) >= len(r) or not r[code].strip().isdigit():
            continue
        if nonvax is not None and r[nonvax].strip() == "True":
            continue
        out.append({"n": r[short].strip(), "f": r[full].strip(),
                    "c": r[code].strip(), "st": r[status].strip()})

    if len(out) < 200:
        sys.exit(f"only {len(out)} vaccines parsed — refusing to write; "
                 "inspect the input file")
    anchor = next((v for v in out if v["c"] == "143"), None)
    if not anchor or "adenovirus" not in anchor["n"].lower():
        sys.exit(f"anchor check failed: CVX 143 should be an adenovirus "
                 f"vaccine, got {anchor} — column mapping is likely wrong")

    out.sort(key=lambda v: v["n"].casefold())
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"), ensure_ascii=False)
    print(f"wrote {len(out)} vaccines to {dst}")


if __name__ == "__main__":
    main(sys.argv)

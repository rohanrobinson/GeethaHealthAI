#!/usr/bin/env python3
"""Convert an NLM RxTerms release file to the app's medications.json.

Usage: convert_rxterms.py RxTermsYYYYMM.txt medications.json

Input: pipe-delimited RxTerms release file with a header row
(https://data.lhncbc.nlm.nih.gov/public/rxterms/release/).
Output schema (must match DrugEntry/DrugStrength in
ios/GeethaHealth/Services/VocabularyStore.swift):
  [{"n": display name, "c": drug-group SXDG_RXCUI,
    "s": [{"s": strength label, "c": strength-specific RXCUI}, ...]}, ...]

Rules (from docs/autocomplete.md): drop retired/suppressed rows, group rows
by DISPLAY_NAME, sort strengths numerically, sort drugs case-insensitively,
emit compact single-line JSON.
"""
import json
import re
import sys


def strength_sort_key(label):
    m = re.search(r"\d+(?:\.\d+)?", label)
    return (float(m.group()) if m else float("inf"), label.casefold())


def main(src, dst):
    with open(src, encoding="utf-8") as f:
        header = f.readline().rstrip("\n").split("|")
        idx = {name.strip(): i for i, name in enumerate(header)}
        required = ["DISPLAY_NAME", "RXCUI", "STRENGTH", "SXDG_RXCUI",
                    "IS_RETIRED", "SUPPRESS_FOR"]
        missing = [c for c in required if c not in idx]
        if missing:
            sys.exit(f"missing columns {missing} — RxTerms format changed? "
                     f"header: {header}")

        drugs = {}
        rows = kept = 0
        for line in f:
            row = line.rstrip("\n").split("|")
            if len(row) < len(header):
                continue
            rows += 1
            if row[idx["IS_RETIRED"]].strip() or row[idx["SUPPRESS_FOR"]].strip():
                continue
            name = row[idx["DISPLAY_NAME"]].strip()
            group_cui = row[idx["SXDG_RXCUI"]].strip()
            if not name or not group_cui:
                continue
            kept += 1
            entry = drugs.setdefault(name, {"c": group_cui, "strengths": {}})
            strength = row[idx["STRENGTH"]].strip()
            rxcui = row[idx["RXCUI"]].strip()
            if strength and rxcui and strength not in entry["strengths"]:
                entry["strengths"][strength] = rxcui

    out = []
    for name in sorted(drugs, key=str.casefold):
        e = drugs[name]
        strengths = [{"s": s, "c": c} for s, c in
                     sorted(e["strengths"].items(),
                            key=lambda kv: strength_sort_key(kv[0]))]
        out.append({"n": name, "c": e["c"], "s": strengths})

    # sanity checks — the 202606 release yielded ~9.3k drugs from ~30k rows
    if len(out) < 5000:
        sys.exit(f"only {len(out)} drugs from {rows} rows — refusing to write; "
                 "inspect the input file")
    # drug-group code is the literal string "NA" for packs — keep those,
    # matching the original conversion
    bad = [d for d in out if (d["c"] != "NA" and not d["c"].isdigit())
           or any(not s["c"].isdigit() for s in d["s"])]
    if bad:
        sys.exit(f"{len(bad)} entries have non-numeric RXCUIs, e.g. {bad[0]}")

    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"), ensure_ascii=False)
    print(f"wrote {len(out)} drugs ({kept}/{rows} rows kept) to {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])

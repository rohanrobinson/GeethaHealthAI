#!/usr/bin/env python3
"""Convert the curated symptom source (TSV) to symptoms.json.

Usage: convert_symptoms.py symptoms_source.tsv symptoms.json

Unlike medications (RxTerms) and vaccines (CVX), there is no free upstream
release for patient-facing symptoms — SNOMED CT is license-gated. So the
canonical source is the hand-curated TSV in update-vocab/data/. This script
just validates and compiles it into the compact JSON the app bundles; edit
the TSV, never the JSON output.

Source TSV format (tab-delimited, one symptom per line):
  <display name>\t<SNOMED CT concept id>\t<synonym|synonym|...>
The synonyms column is optional. Blank lines and lines starting with # ignored.

Output schema (must match SymptomEntry in
ios/GeethaHealth/Services/VocabularyStore.swift):
  [{"n": name, "c": snomed code, "syn": [synonyms...]}, ...]
Sorted case-insensitively by name; compact single-line JSON.
"""
import json
import sys


def main(argv):
    if len(argv) < 3:
        sys.exit(__doc__)
    src, dst = argv[1], argv[2]

    out = []
    seen_codes = {}
    seen_names = set()
    with open(src, encoding="utf-8") as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                sys.exit(f"line {lineno}: expected at least name<TAB>code, got: {line!r}")
            name = parts[0].strip()
            code = parts[1].strip()
            syn_field = parts[2].strip() if len(parts) > 2 else ""
            synonyms = [s.strip() for s in syn_field.split("|") if s.strip()]

            if not name:
                sys.exit(f"line {lineno}: empty symptom name")
            if not code.isdigit():
                sys.exit(f"line {lineno}: SNOMED code {code!r} is not numeric for {name!r}")
            key = name.casefold()
            if key in seen_names:
                sys.exit(f"line {lineno}: duplicate symptom name {name!r}")
            if code in seen_codes:
                sys.exit(f"line {lineno}: SNOMED code {code} reused "
                         f"({seen_codes[code]!r} and {name!r})")
            seen_names.add(key)
            seen_codes[code] = name
            out.append({"n": name, "c": code, "syn": synonyms})

    if len(out) < 30:
        sys.exit(f"only {len(out)} symptoms parsed — refusing to write; "
                 "inspect the source TSV")
    # anchor check: a few well-known codes must map to their expected symptom
    anchors = {"404640003": "Dizziness", "422587007": "Nausea", "84229001": "Fatigue"}
    by_code = {e["c"]: e["n"] for e in out}
    for code, expected in anchors.items():
        if by_code.get(code) != expected:
            sys.exit(f"anchor check failed: SNOMED {code} should be {expected!r}, "
                     f"got {by_code.get(code)!r} — source is likely corrupted")

    out.sort(key=lambda e: e["n"].casefold())
    with open(dst, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"), ensure_ascii=False)
        f.write("\n")
    print(f"wrote {len(out)} symptoms to {dst}")


if __name__ == "__main__":
    main(sys.argv)

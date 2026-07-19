---
name: update-vocab
description: Refresh the bundled autocomplete vocabularies — medications.json from the latest NLM RxTerms release and/or vaccines.json from the CDC CVX code list. Use when asked to update, refresh, or regenerate the medication or vaccine vocabularies/autocomplete data.
argument-hint: "[meds|vaccines|both]"
disable-model-invocation: true
allowed-tools: Bash(curl *) Bash(unzip *) Bash(python3 *) Read
---

Refresh the on-device autocomplete vocabularies. Target: **$ARGUMENTS** (if
empty, do both). Background: [docs/autocomplete.md](${CLAUDE_PROJECT_DIR}/docs/autocomplete.md).

The canonical files are `ios/GeethaHealth/Resources/medications.json` and
`ios/GeethaHealth/Resources/vaccines.json` (compact single-line JSON; schema
defined by the Decodable structs in
`ios/GeethaHealth/Services/VocabularyStore.swift`). Ignore the stale
`medications.json`/`vaccines.json` at the repo root — do not update those.

Work in a temp dir (`mktemp -d`) for downloads. If not already on a feature
branch, create one — Rohan merges via GitHub PRs, never directly to main.

## 1. Download

**RxTerms (meds):** monthly releases at
`https://data.lhncbc.nlm.nih.gov/public/rxterms/release/RxTermsYYYYMM.zip`.
Try the current month; on HTTP 404 step back a month at a time (releases lag).
Unzip; the data file is `RxTermsYYYYMM.txt` (ignore the Ingredients file).

**CVX (vaccines):**
`curl -L -o cvx.txt "https://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/cvx.txt"`

Inspect the first few lines of each download before converting — confirm
pipe-delimited data, not an HTML error page.

## 2. Convert

```
python3 ${CLAUDE_SKILL_DIR}/scripts/convert_rxterms.py RxTermsYYYYMM.txt ios/GeethaHealth/Resources/medications.json
python3 ${CLAUDE_SKILL_DIR}/scripts/convert_cvx.py cvx.txt ios/GeethaHealth/Resources/vaccines.json
```

Both scripts refuse to write on suspiciously small output or failed sanity
checks (schema anchors, numeric codes). If one bails, diagnose the format
drift, fix the script in this skill (that fix is part of the deliverable —
commit it), and rerun. Do not hand-edit the JSON output.

## 3. Verify

- `git diff --stat` — changes should be roughly incremental (tens to a few
  hundred entries), not a wholesale rewrite. A huge diff with stable counts
  usually just means upstream reordering — check entry counts before assuming
  breakage.
- Compare old vs new with python: entries added/removed by code, total
  counts vs the previous release (medications ~9.3k, vaccines ~260 as of
  release 202606).
- Spot-check via JSON that a common drug (e.g. lisinopril: strengths sorted
  numerically, per-strength RXCUIs present) and a common vaccine (e.g. CVX
  208, COVID-19) look right.
- If the Xcode toolchain is available, build the app
  (`cd ios && xcodegen && xcodebuild -project GeethaHealth.xcodeproj -scheme GeethaHealth -destination 'generic/platform=iOS Simulator' build`)
  to confirm the bundle still decodes. Skip if unavailable — the schema
  checks in the scripts cover decoding.

## 4. Finish

- Update the release version and sizes in the table in
  `docs/autocomplete.md`.
- Summarize for the user: release versions used, entry counts before/after,
  notable additions/removals (e.g. new vaccines, status changes).
- Commit on the feature branch and offer to open a PR; do not merge locally.

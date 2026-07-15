# Medication & Vaccine Autocomplete

Typing in the medication or immunization name field shows a dropdown of standard clinical terms to pick from. Selecting one stores the standard **code** alongside the display name, which makes future FHIR export (M5) and Apple Health Records dedupe (M4) far more useful than free text.

## Vocabularies (bundled, fully offline)

| Domain | Source | Bundled file | Size |
|---|---|---|---|
| Medications | NLM **RxTerms** (consumer-friendly RxNorm subset), release 202606 | `ios/GeethaHealth/Resources/medications.json` | ~9.3k drugs, ~1 MB |
| Immunizations | CDC **CVX** codes | `ios/GeethaHealth/Resources/vaccines.json` | 259 vaccines, ~36 KB |

Both datasets are public/free. They are bundled into the app so search never leaves the device — consistent with the privacy story. Queries against a network terminology API (e.g. NLM Clinical Tables) were deliberately rejected because every keystroke would leave the device.

## User flow

- **Medications:** type ≥2 characters → up to 8 suggestions ("Amoxicillin (Oral Pill)"). Picking one fills the name and swaps the free-text dosage field for a **strength picker** (e.g. 2.5/5/10/20/30/40 mg for lisinopril); picking a strength refines the stored code to the strength-specific RXCUI.
- **Immunizations:** same, with CVX short + full names shown; picking stores the CVX code.
- Free text still works — suggestions are optional, nothing blocks saving an unrecognized name (codes stay nil).

## Implementation

- `ios/GeethaHealth/Services/VocabularyStore.swift` — actor that lazily decodes the bundled JSON on first search; every whitespace-separated query token must match a word prefix, name-prefix matches rank first.
- `Medication`/`Immunization` models gained optional `code` + `codeSystem` fields (additive SwiftData change; codeSystem URIs are the FHIR-standard ones for RxNorm and CVX).
- Form views (`MedicationViews.swift`, `ImmunizationViews.swift`) drive search via `.task(id: name)` and track an `acceptedName` so loading/selecting doesn't retrigger search or clear codes.

## Refreshing the data

RxTerms is released monthly (`https://data.lhncbc.nlm.nih.gov/public/rxterms/release/RxTermsYYYYMM.zip`), CVX occasionally (`https://www2a.cdc.gov/vaccines/iis/iisstandards/downloads/cvx.txt`). The converter script lives in the git history of this feature (python; dedupes by DISPLAY_NAME, drops retired/suppressed rows, sorts strengths numerically) — worth extracting to `tools/` if refreshes become routine.

## Known limitations

- Conditions/allergies have no autocomplete yet (ICD-10-CM is the planned source for conditions).
- Brand-name synonyms outside RxTerms display names won't match (e.g. searching "shingles" won't find "zoster recombinant" — no synonym index yet).
- "amox 500" doesn't match — strengths aren't searched, by design; pick the drug first, then the strength.

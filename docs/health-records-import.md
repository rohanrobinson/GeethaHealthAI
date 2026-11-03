# Apple Health Records Import (M4)

Pull real clinical records — conditions, medications, allergies, immunizations — from healthcare providers connected to the Health app, instead of typing them in.

## User flow

1. Records tab → **Import from Apple Health**.
2. iOS shows Apple's clinical-records permission sheet (per record category; the privacy policy is linked there).
3. The app fetches all shared clinical records and shows a **preview grouped by type**, with name, detail (e.g. dosage), status, and date. New records are pre-selected; records already imported are shown dimmed as "Imported" and can't be selected again.
4. Tap **Import n** — selected records are saved into the same lists as manually entered ones.

Re-running the import later only offers what's new (dedupe below).

## How it works

- **Entitlement:** `com.apple.developer.healthkit.access` = `health-records` (self-added; evaluated by Apple at App Review — no pre-approval form). Configured in `project.yml` → generated `GeethaHealth.entitlements`.
- **Fetch:** `HealthRecordsImporter` requests read authorization for the four `HKClinicalType`s, then queries each; authorization-denied errors are treated as "no records" so one denied category doesn't block others (HealthKit never reveals denial explicitly).
- **Parsing:** `FHIRRecordFields` does tolerant, hand-rolled extraction from the raw FHIR JSON (`HKClinicalRecord.fhirResource.data`), handling both DSTU2 and R4 shapes for status, dates (YYYY / YYYY-MM / YYYY-MM-DD / full ISO), coding (`code` / `vaccineCode` / `medicationCodeableConcept` / `substance`), and dosage text. Display names come from HealthKit's own `displayName`. Anything unparsed is fine — the **raw FHIR JSON is stored verbatim** in `sourceFHIRJSON` (feeds M5's FHIR export).
- **Dedupe:** `healthKitIdentifier` = `resourceType/fhirIdentifier` (fallback: HealthKit UUID), matched against all existing records for the profile.
- **Coding:** imported records carry `code`/`codeSystem` from the provider (SNOMED/ICD/RxNorm/CVX), now on all four record models.

## Testing

- **Simulator:** Health app → Profile → Health Records → Get Started lists Apple's sample providers (Sample Institution A–C); connect one, then import in Geetha Health. Sample Institution A has allergies, conditions, and medications but no immunizations.
- **Real data:** physical iPhone with a provider account connected in Health (Profile → Health Records → Add Account; most major US health systems supported).
- **Denied access:** HealthKit never reports a denial, so tapping "Don't Share" lands on the same "No health records found" state as having no provider. Its copy points to Profile → Health Records, where both cases are fixed — iOS 26's Health app has no Browse tab.

## Known limitations / later

- Lab results (`labResultRecord`) and vitals aren't imported yet — only the four types with matching models.
- No automatic background sync; import is manual and on-demand (a deliberate choice — the user stays in control).
- Parsing is best-effort; unusual provider payloads fall back to display name + raw JSON.

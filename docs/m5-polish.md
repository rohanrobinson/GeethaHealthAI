# M5 — FHIR Export, Face ID Lock, Storage Row, Dynamic Type

## FHIR bundle export

Records → Share menu now offers two formats: the existing PDF summary, and a new **FHIR bundle** — a machine-readable JSON export a health system can actually ingest, not just a human-readable summary.

- **`Services/FHIRExporter.swift`** builds a FHIR `Bundle` (`type: "collection"`) containing a synthesized `Patient` resource plus one entry per record.
- **HealthKit-imported records** (`sourceFHIRJSON` set) are re-emitted **verbatim** — exactly the DSTU2 or R4 JSON the provider sent, byte-for-byte, inside the bundle entry. No re-normalization, no fidelity loss.
- **Manually-entered records** are synthesized into minimal valid FHIR resources from the model fields: `Condition`, `MedicationStatement`, `AllergyIntolerance`, `Immunization`. Where the record has a `code`/`codeSystem` (from autocomplete — RxNorm, CVX), that becomes a proper `coding` entry; otherwise `code.text` carries the free-text name (still valid FHIR).
- **Appointments** have no natural clinical coding, but are included as a proper FHIR `Appointment` resource (`status: "booked"`, `start`, `participant`, `description`, `comment` for location/notes) — always synthesized, since HealthKit doesn't import appointments today. Per the [FHIR Appointment spec](https://build.fhir.org/appointment.html).
- Same file-then-share pattern as `PDFExporter`: writes to the temp directory, returned as a `URL`, presented through the existing `ShareSheet`.

## Face ID app lock

Profile → **Require Face ID** toggle. When on, the app locks itself whenever it leaves the foreground and requires Face ID (or device passcode, as an automatic fallback) to resume.

- **`Services/AppLock.swift`** wraps `LAContext` with `.deviceOwnerAuthentication` (not the biometrics-only policy), so a device passcode is always a valid unlock method.
- **Deliberate fallback**: if a device has neither biometrics enrolled nor a passcode set at all, the app **passes through unlocked** rather than blocking. A device with no passcode offers no real protection anyway — the priority is never locking someone out of their own medical records over a device configuration gap.
- Turning the toggle on immediately runs a real authentication check before committing the setting, so a user can't enable a lock that doesn't actually work.
- **`Views/RootView.swift`** gates the whole app behind `LockScreenView` when locked, keyed off `scenePhase` — background triggers the lock, matching how banking/health apps behave.

## Storage-used row

Profile now shows an approximate on-device storage figure (`Services/StorageInfo.swift`, summing the SwiftData store and imported-documents directories, `ByteCountFormatter`-formatted) alongside the existing "On this device only" line — answers a question Rohan asked earlier about how much data the app can hold (short answer: effectively unbounded for structured records; documents are the only thing that grows meaningfully).

## Dynamic Type pass

Verification, not a rewrite — the app already used semantic font styles (`.headline`, `.body`, etc.) almost everywhere. Two intentional exceptions, both documented in-code so they aren't "fixed" later:
- `SummaryPDFView` — print output; should look like a fixed document regardless of the user's live text-size setting.
- The compact "Share" toolbar button in `RecordsHomeView` — fixed size so the icon+caption fits the round toolbar button at every setting, same as system toolbar chrome.

Verified at accessibility XXL in the Simulator: Records renders cleanly, nothing clips or overlaps.

## Release prep

`project.yml` `CURRENT_PROJECT_VERSION` bumped to 3 (TestFlight's latest build was 2, auto-assigned by Xcode during the M4 upload).

# Geetha Health — iOS Personal Medical Record

**Supersedes [SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md).** The project pivoted (July 2026) from a family web app to a native iOS personal medical record app, delivered via the App Store.

## Product

A personal medical record anyone can use to view and share their medical records with healthcare providers.

- **Stack:** Swift/SwiftUI, SwiftData, min iOS 17.
- **Data:** on-device only. No backend, no iCloud/CloudKit (App Review Guideline 5.1.3 forbids HealthKit-derived data in iCloud, and "your records never leave your device" is the privacy story).
- **Ingestion:** manual entry; Apple Health Records import (HealthKit clinical records, FHIR); document scan/photo/PDF.
- **Sharing:** PDF medical-summary export via share sheet; FHIR bundle export.

## Project layout

```
ios/project.yml            # XcodeGen spec — .xcodeproj is generated, not committed by hand
ios/GeethaHealth/
  GeethaHealthApp.swift    # app entry, ModelContainer
  Models/                  # SwiftData models (FHIR-aligned)
  Views/                   # Onboarding/, Records/, Documents/, Profile/
  Services/                # DocumentFileStore, PDFExporter, HealthRecordsImporter (M3–M4)
```

Architecture: plain SwiftUI + SwiftData, relationship arrays / `@Query` in views. No MVVM ceremony. Only planned third-party dependency: Apple's `FHIRModels` package (M4).

## Data model

`Profile` (primary person; multiple profiles supported for caregiver use) with cascade-delete relations to `Condition`, `Medication` (FHIR MedicationStatement), `Allergy` (AllergyIntolerance), `Immunization`, `Appointment`, `MedicalDocument` (metadata in SwiftData, file bytes on disk in Application Support).

Imported records carry `sourceFHIRJSON: Data?` (raw FHIR retained verbatim) and `healthKitIdentifier: String?` as the dedupe/upsert key — same pattern as the legacy Prisma schema's `fhir Json?` columns.

## Milestones

| # | Deliverable | Status |
|---|-------------|--------|
| M1 | Running app: onboarding, manual CRUD for all record types | Scaffolded; verify in Simulator once Xcode installed |
| M2 | PDF medical-summary export via share sheet | — |
| M3 | Documents: VisionKit scan, photo/PDF import, QuickLook | — |
| M4 | Apple Health Records import (gated on Apple entitlement approval) | — |
| M5 | Polish + FHIR bundle export, Face ID lock | — |
| M6 | TestFlight → App Store submission | — |

## Phase 0 checklist (long lead times — do these now)

- [ ] Enroll in Apple Developer Program ($99/yr, days to verify)
- [ ] Install full Xcode; `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
- [ ] Publish privacy policy page (required for health apps and for the entitlement request)
- [ ] Request HealthKit **Clinical Records entitlement** from Apple (weeks of lead time — this gates M4, not launch)
- [ ] Reserve bundle ID (`com.geethahealth.GeethaHealth`) + app name in App Store Connect

## App Review notes

- No medical advice/diagnosis language anywhere; include a "not a medical device" disclaimer.
- PDF export carries a "patient-entered data" disclaimer.
- Privacy nutrition label: fully on-device should qualify as "Data Not Collected".
- HealthKit clinical records: Simulator's Health app has sample clinical data for development; real provider data requires a physical device.

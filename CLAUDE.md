# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A native iOS personal medical record app (Swift/SwiftUI, SwiftData, min iOS 17). **All app work is in [`ios/`](ios/).**

[`site/`](site/) is the marketing website at [geethahealth.com](https://geethahealth.com) — a static page whose only job is to sell the app. It is **not** a web client and must not become one. See [docs/marketing-site.md](docs/marketing-site.md).

`docs/` does double duty: it holds the engineering design notes **and** is served by GitHub Pages, so anything added there is publicly visible unless excluded (see below).

`frontend/` (React+Vite) and `backend/` (FastAPI+Postgres) are the **frozen** legacy family-health web app — kept only for reference. Do not develop them; `SYSTEM_DESIGN.md`, `GeethaFamilyMVP.md`, and `docs/DATA_MODEL.md` describe that superseded design. [docs/ios-pivot.md](docs/ios-pivot.md) is the current architecture/roadmap doc and supersedes them.

## Commands

```bash
cd ios
xcodegen generate                # regenerate GeethaHealth.xcodeproj from project.yml
open GeethaHealth.xcodeproj      # run the GeethaHealth scheme in the iOS 17+ Simulator
```

**Adding, removing, or moving any Swift/resource file requires re-running `xcodegen generate`** — the `.xcodeproj` is generated from `project.yml`, and all build settings, entitlements, and Info.plist keys live in that YAML, never in the Xcode UI.

```bash
# Build
xcodebuild -project GeethaHealth.xcodeproj -scheme GeethaHealth \
  -destination 'generic/platform=iOS Simulator' build

# UI tests (the only test target)
xcodebuild -project GeethaHealth.xcodeproj -scheme GeethaHealth \
  -destination 'platform=iOS Simulator,name=iPhone 17' test

# A single test
... test -only-testing:GeethaHealthUITests/VoiceSymptomUITests/testVoiceEntryCreatesSymptom
```

```bash
# Marketing site — needs a real HTTP server, not file://, because assets are
# referenced by absolute path. Note /privacy and /thanks won't resolve here:
# Vercel's cleanUrls maps them to the .html files in production.
cd site && python3 -m http.server 8000
```

## Architecture

Plain SwiftUI + SwiftData. No MVVM, no view models, no DI container: views hold `@Query`/`@Environment(\.modelContext)` and mutate models directly. Keep it that way.

- `GeethaHealthApp.swift` declares the `ModelContainer` — **every new `@Model` type must be added to that array**.
- `RootView` is the only routing logic: app-lock gate → onboarding if no `Profile` exists → 4-tab `TabView` (Records / Ask / Documents / Profile).
- `Models/` — SwiftData models, one per FHIR resource. `Profile` is the aggregate root; every record type is a cascade-delete relationship off it, and views navigate via `profile.conditions` etc. rather than separate queries.
- `Services/` — all non-UI logic as enums/actors/`@Observable` classes with no SwiftUI imports.
- `Views/` — grouped by feature (`Records/`, `Documents/`, `Export/`, `Onboarding/`, `Lock/`).

### Invariants

**On-device only.** No backend, no CloudKit, no network calls of any kind — vocabularies are bundled, speech recognition is forced on-device, the assistant is Apple's on-device model. "Your records never leave your device" is both the product's privacy story and an App Review commitment (Guideline 5.1.3). Never introduce a network dependency, even for autocomplete or an LLM.

This invariant is about **the app**. `ios/` contains no networking code at all, and that is the thing to preserve. `site/` is a separate public website that does have one serverless function (an email signup) — that is not precedent for adding network code to the app, and no health data touches it.

**FHIR alignment.** Each model maps to a FHIR resource (`Condition`, `MedicationStatement`, `AllergyIntolerance`, `Immunization`, `Appointment`, and `SymptomObservation` → `Observation`). Two fields carry the contract:
- `sourceFHIRJSON: Data?` — raw provider FHIR retained verbatim on import; `FHIRExporter` re-emits it byte-for-byte instead of round-tripping through model fields.
- `healthKitIdentifier: String?` — the dedupe/upsert key for Apple Health imports (`resourceType/fhirIdentifier`).

Records also carry optional `code`/`codeSystem` from autocomplete or import. New record types should follow the same shape.

**iOS 26 features degrade, never gate.** `SymptomAssistant` and `FoundationModelsSymptomParser` use `FoundationModels` under `@available(iOS 26.0, *)` plus a `SystemLanguageModel.availability` check. Every such path has a deterministic fallback that must stay fully functional: `SymptomInsights` (templated summaries + heuristic Q&A) and `HeuristicSymptomParser`. Red-flag symptom screening is deliberately deterministic and must never depend on the LLM.

**Bundled vocabularies.** `Resources/{medications,vaccines,symptoms}.json` (RxTerms / CDC CVX / curated SNOMED CT) are decoded lazily by the `VocabularyStore` actor. Never hand-edit them — regenerate via the `/update-vocab` skill (`.claude/skills/update-vocab/`); symptoms come from that skill's curated TSV, not the JSON.

**Documents.** File bytes live on disk in `Application Support/MedicalDocuments/` with `.completeFileProtection` (`DocumentFileStore`); SwiftData holds only metadata. Deleting a `MedicalDocument` must delete the file too.

### Testing the voice flow

Live speech and Foundation Models are unreliable in the Simulator, so the whole voice pipeline runs against mocks when launched with `-uiMockVoice` (`VoiceEntryConfig` in `SpeechTranscriber.swift`): `MockSymptomParser` plus a scripted transcript. UI tests drive the flow by accessibility label, so keep button labels stable or update `VoiceSymptomUITests`.

## App Review constraints

- No medical-advice or diagnosis language anywhere in UI copy; keep the "not a medical device" and "patient-entered data" disclaimers (the latter is on PDF export).
- HealthKit clinical records use the self-added `com.apple.developer.healthkit.access = health-records` entitlement, declared in `project.yml`. The usage-description strings there are what Apple evaluates — edit them there, deliberately.
- Privacy label is "Data Not Collected"; anything that would change that is a product decision, not an implementation detail. The label covers data collected **through the app** — the website's mailing list does not change it, but the published privacy policy now covers both and says so explicitly.

## Workflow

Work on a feature branch and open a GitHub PR — never merge to `main` locally.

## Marketing site

`site/` is hand-authored static HTML deployed to Vercel with **no build step** (Root Directory `site`). Two rules make the rest work:

- **No external requests and no JavaScript.** That is what lets `site/vercel.json` ship `default-src 'none'` with no `script-src`. One inline `style=` or one `<script>` breaks it silently, because the browser blocks rather than errors. The email signup is a plain form POST for exactly this reason.
- **The privacy policy exists twice** — `site/privacy.html` (canonical) and `docs/privacy.md` (mirror, keeps the App Store Connect URL alive). Edit both or neither.

Screenshots come from `GeethaHealthUITests/MarketingScreenshotTests`, not hand-capture. Details and the regeneration commands are in [docs/marketing-site.md](docs/marketing-site.md).

## Feature docs

`docs/` holds a design note per shipped feature: [autocomplete](docs/autocomplete.md), [documents](docs/documents.md), [health-records-import](docs/health-records-import.md), [pdf-export](docs/pdf-export.md), [m5-polish](docs/m5-polish.md) (FHIR export, Face ID lock, storage row), [marketing-site](docs/marketing-site.md). Read the relevant one before changing that area, and update it when the behavior changes.

**GitHub Pages serves `docs/`, so every `.md` there is a public web page unless it is in the `exclude:` list in `docs/_config.yml`.** Add new design notes to that list or they ship publicly on merge.

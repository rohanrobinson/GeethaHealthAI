# PDF Medical-Summary Export (M2)

Share a clean, printable summary of your medical record with a healthcare provider — via AirDrop, email, print, or Save to Files. This is the primary sharing mechanism in v1 (see [ios-pivot.md](ios-pivot.md)): universally accepted by front-desk staff, and it requires no backend and no account.

## How it works (user flow)

1. On the **Records** tab, tap the share icon (top-right).
2. The app generates a PDF of the current profile's record on-device.
3. The standard iOS share sheet opens — AirDrop it to a provider's device, attach it to an email, print it, or save it to Files.

The PDF is written to the app's temporary directory and handed to the share sheet; nothing is uploaded anywhere by the app.

## What's in the PDF

- **Header:** patient name, date of birth, age, sex, blood type, emergency contact.
- **Sections** (in this order, each omitted when empty):
  1. **Allergies** — first, since it's what clinicians scan for; includes risk level and reaction.
  2. **Conditions** — status, onset date, notes.
  3. **Medications** — dosage, frequency, status, notes.
  4. **Immunizations** — newest first, with administered dates.
  5. **Appointments** — newest first, with clinician and location.
- **Footer:** a disclaimer that the content is patient-entered data, not a clinical record from a provider and not medical advice, plus a generation timestamp.

The filename encodes the person and date, e.g. `Medical-Summary-Anushka-Shrestha-2026-07-11.pdf`.

## Implementation

| Piece | File | Role |
|---|---|---|
| Layout | [`ios/GeethaHealth/Views/Export/SummaryPDFView.swift`](../ios/GeethaHealth/Views/Export/SummaryPDFView.swift) | SwiftUI view of the summary, fixed to US Letter width (612 pt), forced light mode. Never shown in the app UI. |
| Rendering | [`ios/GeethaHealth/Services/PDFExporter.swift`](../ios/GeethaHealth/Services/PDFExporter.swift) | `ImageRenderer` draws the view into a `CGContext` PDF at a temp-file URL. |
| Presentation | [`ios/GeethaHealth/Views/Export/ShareSheet.swift`](../ios/GeethaHealth/Views/Export/ShareSheet.swift) + share button in [`RecordsHomeView.swift`](../ios/GeethaHealth/Views/Records/RecordsHomeView.swift) | `UIActivityViewController` wrapper presented as a sheet. |

## Known limitations / later refinements

- **Single continuous page:** the PDF is one page sized to the content height (minimum US Letter). Long records print scaled or awkwardly; proper per-page pagination (`UIGraphicsPDFRenderer`) is the planned refinement.
- **Vector vs raster:** `ImageRenderer` output here is drawn into a PDF context, so text renders sharply, but text is not selectable/searchable in all PDF viewers. A text-based renderer would fix this alongside pagination.
- **No section selection:** always exports the full record. A "choose what to share" step (e.g. hide notes, pick sections) is a good privacy-focused follow-up.
- **Documents not included:** scanned/imported documents (M3) are not embedded in the summary.

# Documents (M3)

Keep visit summaries, lab printouts, referral letters, and any other paper or digital medical records inside the app — scanned with the camera or imported from Photos/Files.

## User flow

The **Documents** tab's **+** menu offers three ways in:

1. **Scan document** (real devices only — hidden in Simulator): Apple's document camera with automatic edge detection; multi-page scans become a single PDF.
2. **Choose photos**: pick up to 10 images from the photo library.
3. **Import file**: pick PDFs or images from the Files app.

Documents appear in a list with thumbnails, name, and date. Tap to view full-screen (pinch-zoom, page through PDFs). Long-press for **Rename**/**Delete**; swipe to delete. Deleting removes both the record and the file.

## Storage & privacy

- File bytes live in the app's private container (`Application Support/MedicalDocuments/`) with **complete file protection** (encrypted whenever the device is locked); metadata (name, file reference, type, date, profile link) lives in SwiftData.
- Nothing is uploaded; documents are device-only like all other data.

## Implementation

| Piece | File |
|---|---|
| File storage + scan→PDF rendering | `ios/GeethaHealth/Services/DocumentFileStore.swift` |
| VisionKit camera wrapper (`VNDocumentCameraViewController`) | `ios/GeethaHealth/Views/Documents/DocumentScannerView.swift` |
| List, thumbnails (`QLThumbnailGenerator`), QuickLook preview, PhotosPicker + fileImporter | `ios/GeethaHealth/Views/Documents/DocumentsView.swift` |
| Metadata model (unchanged from M1) | `ios/GeethaHealth/Models/MedicalDocument.swift` |

`NSCameraUsageDescription` added via `project.yml` for the scanner.

## Known limitations / later

- Documents aren't linked to specific records (e.g. attach a lab PDF to a condition) — flat list per profile for now.
- Not included in the PDF medical-summary export.
- No OCR/AI extraction of scanned content into structured records (the big future differentiator).

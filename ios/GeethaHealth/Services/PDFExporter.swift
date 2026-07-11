import SwiftUI
import UIKit

enum PDFExporter {
    // Renders the summary at US Letter width with proportional height (one
    // continuous page). Per-page pagination is a later refinement.
    @MainActor
    static func makeSummaryPDF(for profile: Profile) -> URL? {
        let renderer = ImageRenderer(content: SummaryPDFView(profile: profile))
        renderer.proposedSize = ProposedViewSize(width: 612, height: nil)

        let fileName = summaryFileName(for: profile)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        var rendered = false
        renderer.render { size, renderInContext in
            var mediaBox = CGRect(origin: .zero, size: CGSize(width: 612, height: max(size.height, 792)))
            guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            // Flip: SwiftUI draws top-down, CGContext PDF space is bottom-up.
            context.translateBy(x: 0, y: mediaBox.height - size.height)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
            rendered = true
        }
        return rendered ? url : nil
    }

    private static func summaryFileName(for profile: Profile) -> String {
        let name = profile.displayName
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        let date = Date().formatted(.iso8601.year().month().day())
        return "Medical-Summary-\(name.isEmpty ? "Profile" : name)-\(date).pdf"
    }
}

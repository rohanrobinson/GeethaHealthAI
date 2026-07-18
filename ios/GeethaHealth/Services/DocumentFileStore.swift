import Foundation
import UIKit

// Document bytes live on disk in Application Support; SwiftData holds only
// metadata (MedicalDocument.fileName points here).
enum DocumentFileStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MedicalDocuments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Writes data with complete file protection; returns the stored file name.
    static func save(_ data: Data, fileExtension: String) throws -> String {
        let fileName = UUID().uuidString + "." + fileExtension
        try data.write(to: url(forFileName: fileName), options: [.atomic, .completeFileProtection])
        return fileName
    }

    static func url(forFileName fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(forFileName: fileName))
    }

    /// Renders scanned page images into a single multi-page PDF.
    static func pdfData(from images: [UIImage]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: .zero)
        return renderer.pdfData { context in
            for image in images {
                let bounds = CGRect(origin: .zero, size: image.size)
                context.beginPage(withBounds: bounds, pageInfo: [:])
                image.draw(in: bounds)
            }
        }
    }
}

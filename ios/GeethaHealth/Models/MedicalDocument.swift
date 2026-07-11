import Foundation
import SwiftData

// Metadata only; file bytes live on disk in Application Support (see DocumentFileStore, M3).
@Model
final class MedicalDocument {
    var name: String
    var fileName: String
    var contentType: String
    var uploadedAt: Date
    var profile: Profile?

    init(name: String, fileName: String, contentType: String) {
        self.name = name
        self.fileName = fileName
        self.contentType = contentType
        self.uploadedAt = Date()
    }
}

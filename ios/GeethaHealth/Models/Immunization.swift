import Foundation
import SwiftData

// FHIR Immunization
@Model
final class Immunization {
    var name: String
    var administeredDate: Date?
    var notes: String?
    // Vocabulary coding (CDC CVX code when picked from autocomplete)
    var code: String?
    var codeSystem: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        administeredDate: Date? = nil,
        notes: String? = nil,
        code: String? = nil,
        codeSystem: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.administeredDate = administeredDate
        self.notes = notes
        self.code = code
        self.codeSystem = codeSystem
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

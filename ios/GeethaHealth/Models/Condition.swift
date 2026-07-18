import Foundation
import SwiftData

// FHIR Condition
@Model
final class Condition {
    var name: String
    // FHIR clinicalStatus: active | recurrence | relapse | inactive | remission | resolved
    var clinicalStatus: String
    var onsetDate: Date?
    var notes: String?
    // Vocabulary coding (e.g. SNOMED/ICD from imported FHIR)
    var code: String?
    var codeSystem: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        clinicalStatus: String = "active",
        onsetDate: Date? = nil,
        notes: String? = nil,
        code: String? = nil,
        codeSystem: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.clinicalStatus = clinicalStatus
        self.onsetDate = onsetDate
        self.notes = notes
        self.code = code
        self.codeSystem = codeSystem
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

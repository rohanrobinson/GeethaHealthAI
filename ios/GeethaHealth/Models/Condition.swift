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
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        clinicalStatus: String = "active",
        onsetDate: Date? = nil,
        notes: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.clinicalStatus = clinicalStatus
        self.onsetDate = onsetDate
        self.notes = notes
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

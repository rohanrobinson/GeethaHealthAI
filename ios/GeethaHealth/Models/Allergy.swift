import Foundation
import SwiftData

// FHIR AllergyIntolerance
@Model
final class Allergy {
    var name: String
    // FHIR criticality: low | high | unable-to-assess
    var criticality: String?
    var reaction: String?
    var notes: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        criticality: String? = nil,
        reaction: String? = nil,
        notes: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.criticality = criticality
        self.reaction = reaction
        self.notes = notes
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

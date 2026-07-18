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
    // Vocabulary coding (e.g. RxNorm/SNOMED from imported FHIR)
    var code: String?
    var codeSystem: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        criticality: String? = nil,
        reaction: String? = nil,
        notes: String? = nil,
        code: String? = nil,
        codeSystem: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.criticality = criticality
        self.reaction = reaction
        self.notes = notes
        self.code = code
        self.codeSystem = codeSystem
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

import Foundation
import SwiftData

// FHIR Immunization
@Model
final class Immunization {
    var name: String
    var administeredDate: Date?
    var notes: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        administeredDate: Date? = nil,
        notes: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.administeredDate = administeredDate
        self.notes = notes
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

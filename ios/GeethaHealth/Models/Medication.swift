import Foundation
import SwiftData

// FHIR MedicationStatement
@Model
final class Medication {
    var name: String
    var dosageText: String?
    var frequencyText: String?
    // FHIR status: active | completed | stopped | on-hold | intended | not-taken
    var status: String
    var startDate: Date?
    var endDate: Date?
    var notes: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        dosageText: String? = nil,
        frequencyText: String? = nil,
        status: String = "active",
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.name = name
        self.dosageText = dosageText
        self.frequencyText = frequencyText
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

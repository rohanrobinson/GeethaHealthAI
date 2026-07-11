import Foundation
import SwiftData

@Model
final class Appointment {
    var title: String
    var startDate: Date
    var location: String?
    var clinician: String?
    var notes: String?
    var sourceFHIRJSON: Data?
    var healthKitIdentifier: String?
    var createdAt: Date
    var profile: Profile?

    init(
        title: String,
        startDate: Date,
        location: String? = nil,
        clinician: String? = nil,
        notes: String? = nil,
        sourceFHIRJSON: Data? = nil,
        healthKitIdentifier: String? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.location = location
        self.clinician = clinician
        self.notes = notes
        self.sourceFHIRJSON = sourceFHIRJSON
        self.healthKitIdentifier = healthKitIdentifier
        self.createdAt = Date()
    }
}

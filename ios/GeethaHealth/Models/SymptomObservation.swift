import Foundation
import SwiftData

// FHIR Observation — a patient-reported symptom (dizziness, nausea, fatigue…).
// Modeled as Observation rather than Condition: symptoms are self-reported,
// episodic findings tracked over time, distinct from clinical diagnoses.
@Model
final class SymptomObservation {
    var name: String
    // "mild" | "moderate" | "severe" — nil if not specified.
    var severity: String?
    var bodySite: String?
    // When the symptom began.
    var onsetDate: Date?
    // When this entry was logged.
    var recordedDate: Date
    // "active" | "resolved" — whether the user is still experiencing it.
    var status: String
    var notes: String?
    // Vocabulary coding (SNOMED CT from the bundled symptom vocabulary).
    var code: String?
    var codeSystem: String?
    // Kept for consistency with sibling records; symptoms are user-entered so
    // this is normally nil (Apple Health does not import patient-reported
    // symptoms this way).
    var sourceFHIRJSON: Data?
    var createdAt: Date
    var profile: Profile?

    init(
        name: String,
        severity: String? = nil,
        bodySite: String? = nil,
        onsetDate: Date? = nil,
        recordedDate: Date = Date(),
        status: String = "active",
        notes: String? = nil,
        code: String? = nil,
        codeSystem: String? = nil,
        sourceFHIRJSON: Data? = nil
    ) {
        self.name = name
        self.severity = severity
        self.bodySite = bodySite
        self.onsetDate = onsetDate
        self.recordedDate = recordedDate
        self.status = status
        self.notes = notes
        self.code = code
        self.codeSystem = codeSystem
        self.sourceFHIRJSON = sourceFHIRJSON
        self.createdAt = Date()
    }
}

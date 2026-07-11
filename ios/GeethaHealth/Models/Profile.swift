import Foundation
import SwiftData

@Model
final class Profile {
    var givenName: String
    var familyName: String
    var dateOfBirth: Date?
    var sex: String?
    var bloodType: String?
    // "Self" for the primary profile; otherwise the relationship to the
    // account owner (e.g. "Child", "Parent") for caregiver-managed profiles.
    var relationship: String
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Condition.profile)
    var conditions: [Condition] = []
    @Relationship(deleteRule: .cascade, inverse: \Medication.profile)
    var medications: [Medication] = []
    @Relationship(deleteRule: .cascade, inverse: \Allergy.profile)
    var allergies: [Allergy] = []
    @Relationship(deleteRule: .cascade, inverse: \Immunization.profile)
    var immunizations: [Immunization] = []
    @Relationship(deleteRule: .cascade, inverse: \Appointment.profile)
    var appointments: [Appointment] = []
    @Relationship(deleteRule: .cascade, inverse: \MedicalDocument.profile)
    var documents: [MedicalDocument] = []

    init(
        givenName: String,
        familyName: String,
        dateOfBirth: Date? = nil,
        sex: String? = nil,
        bloodType: String? = nil,
        relationship: String = "Self",
        emergencyContactName: String? = nil,
        emergencyContactPhone: String? = nil
    ) {
        self.givenName = givenName
        self.familyName = familyName
        self.dateOfBirth = dateOfBirth
        self.sex = sex
        self.bloodType = bloodType
        self.relationship = relationship
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.createdAt = Date()
    }

    var displayName: String {
        "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
    }

    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
}

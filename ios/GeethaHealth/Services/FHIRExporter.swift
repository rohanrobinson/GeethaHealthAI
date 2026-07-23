import Foundation

// Builds a FHIR Bundle of the profile's records. HealthKit-imported records
// (sourceFHIRJSON present) are re-emitted verbatim to preserve DSTU2/R4
// fidelity exactly as received; manually-entered records are synthesized
// into minimal valid FHIR resources from the model fields.
enum FHIRExporter {
    private static let isoDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let isoDay: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()

    static func makeBundle(for profile: Profile) -> URL? {
        var entries: [[String: Any]] = [entry(resource: patientResource(profile))]

        for condition in profile.conditions {
            entries.append(entry(resource: resource(for: condition)))
        }
        for medication in profile.medications {
            entries.append(entry(resource: resource(for: medication)))
        }
        for allergy in profile.allergies {
            entries.append(entry(resource: resource(for: allergy)))
        }
        for immunization in profile.immunizations {
            entries.append(entry(resource: resource(for: immunization)))
        }
        for appointment in profile.appointments {
            entries.append(entry(resource: resource(for: appointment)))
        }

        let bundle: [String: Any] = [
            "resourceType": "Bundle",
            "type": "collection",
            "timestamp": isoDate.string(from: Date()),
            "entry": entries,
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: bundle, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: profile))
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func entry(resource: [String: Any]) -> [String: Any] {
        let id = (resource["id"] as? String) ?? UUID().uuidString
        return ["fullUrl": "urn:uuid:\(id)", "resource": resource]
    }

    // MARK: Patient

    private static func patientResource(_ profile: Profile) -> [String: Any] {
        var resource: [String: Any] = [
            "resourceType": "Patient",
            "id": UUID().uuidString,
            "name": [[
                "use": "official",
                "family": profile.familyName,
                "given": [profile.givenName],
            ]],
        ]
        if let dob = profile.dateOfBirth {
            resource["birthDate"] = isoDay.string(from: dob)
        }
        if let gender = fhirGender(profile.sex) {
            resource["gender"] = gender
        }
        return resource
    }

    private static func fhirGender(_ sex: String?) -> String? {
        switch sex?.lowercased() {
        case "female": return "female"
        case "male": return "male"
        case nil: return nil
        default: return "other"
        }
    }

    // MARK: Coded records — verbatim if imported, else synthesized

    private static func resource(for condition: Condition) -> [String: Any] {
        if let verbatim = decodedVerbatim(condition.sourceFHIRJSON) { return verbatim }
        var resource: [String: Any] = [
            "resourceType": "Condition",
            "id": UUID().uuidString,
            "clinicalStatus": codeableConcept(text: condition.clinicalStatus),
            "code": codeableConcept(text: condition.name, code: condition.code, system: condition.codeSystem),
        ]
        if let onset = condition.onsetDate {
            resource["onsetDateTime"] = isoDay.string(from: onset)
        }
        if let notes = condition.notes {
            resource["note"] = [["text": notes]]
        }
        return resource
    }

    private static func resource(for medication: Medication) -> [String: Any] {
        if let verbatim = decodedVerbatim(medication.sourceFHIRJSON) { return verbatim }
        var resource: [String: Any] = [
            "resourceType": "MedicationStatement",
            "id": UUID().uuidString,
            "status": medication.status,
            "medicationCodeableConcept": codeableConcept(text: medication.name, code: medication.code, system: medication.codeSystem),
        ]
        let dosageText = [medication.dosageText, medication.frequencyText].compactMap { $0 }.joined(separator: ", ")
        if !dosageText.isEmpty {
            resource["dosage"] = [["text": dosageText]]
        }
        if let start = medication.startDate {
            var period: [String: Any] = ["start": isoDay.string(from: start)]
            if let end = medication.endDate {
                period["end"] = isoDay.string(from: end)
            }
            resource["effectivePeriod"] = period
        }
        if let notes = medication.notes {
            resource["note"] = [["text": notes]]
        }
        return resource
    }

    private static func resource(for allergy: Allergy) -> [String: Any] {
        if let verbatim = decodedVerbatim(allergy.sourceFHIRJSON) { return verbatim }
        var resource: [String: Any] = [
            "resourceType": "AllergyIntolerance",
            "id": UUID().uuidString,
            "code": codeableConcept(text: allergy.name, code: allergy.code, system: allergy.codeSystem),
        ]
        if let criticality = allergy.criticality {
            resource["criticality"] = criticality
        }
        if let reaction = allergy.reaction {
            resource["reaction"] = [["description": reaction]]
        }
        if let notes = allergy.notes {
            resource["note"] = [["text": notes]]
        }
        return resource
    }

    private static func resource(for immunization: Immunization) -> [String: Any] {
        if let verbatim = decodedVerbatim(immunization.sourceFHIRJSON) { return verbatim }
        var resource: [String: Any] = [
            "resourceType": "Immunization",
            "id": UUID().uuidString,
            "status": "completed",
            "vaccineCode": codeableConcept(text: immunization.name, code: immunization.code, system: immunization.codeSystem),
        ]
        if let date = immunization.administeredDate {
            resource["occurrenceDateTime"] = isoDay.string(from: date)
        }
        if let notes = immunization.notes {
            resource["note"] = [["text": notes]]
        }
        return resource
    }

    // MARK: Appointment — always synthesized (HealthKit doesn't import appointments)

    private static func resource(for appointment: Appointment) -> [String: Any] {
        var participant: [String: Any] = ["status": "accepted"]
        if let clinician = appointment.clinician {
            participant["actor"] = ["display": clinician]
        } else {
            participant["actor"] = ["display": "Patient"]
        }

        var resource: [String: Any] = [
            "resourceType": "Appointment",
            "id": UUID().uuidString,
            "status": "booked",
            "description": appointment.title,
            "start": isoDate.string(from: appointment.startDate),
            "participant": [participant],
        ]
        let comment = [
            appointment.location.map { "Location: \($0)" },
            appointment.notes,
        ].compactMap { $0 }.joined(separator: "; ")
        if !comment.isEmpty {
            resource["comment"] = comment
        }
        return resource
    }

    // MARK: Helpers

    private static func codeableConcept(text: String, code: String? = nil, system: String? = nil) -> [String: Any] {
        var concept: [String: Any] = ["text": text]
        if let code, let system {
            concept["coding"] = [["system": system, "code": code, "display": text]]
        }
        return concept
    }

    private static func decodedVerbatim(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func fileName(for profile: Profile) -> String {
        let name = profile.displayName
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        let date = Date().formatted(.iso8601.year().month().day())
        return "Medical-Records-\(name.isEmpty ? "Profile" : name)-\(date).json"
    }
}

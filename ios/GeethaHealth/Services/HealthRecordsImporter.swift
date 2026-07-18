import Foundation
import HealthKit

// One clinical record fetched from Apple Health, parsed enough to preview
// and import. Raw FHIR JSON is retained verbatim on the imported record.
struct ImportCandidate: Identifiable {
    enum Kind: String, CaseIterable {
        case allergy = "Allergies"
        case condition = "Conditions"
        case medication = "Medications"
        case immunization = "Immunizations"
    }

    let id: String              // healthKitIdentifier used for dedupe
    let kind: Kind
    let displayName: String
    let detail: String?
    let date: Date?
    let status: String?
    let code: String?
    let codeSystem: String?
    let fhirData: Data?
    let alreadyImported: Bool
}

enum HealthRecordsImporter {
    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private static let clinicalTypes: [(HKClinicalTypeIdentifier, ImportCandidate.Kind)] = [
        (.allergyRecord, .allergy),
        (.conditionRecord, .condition),
        (.medicationRecord, .medication),
        (.immunizationRecord, .immunization),
    ]

    static func requestAuthorization(store: HKHealthStore) async throws {
        let types = Set(clinicalTypes.compactMap { HKObjectType.clinicalType(forIdentifier: $0.0) })
        try await store.requestAuthorization(toShare: [], read: types)
    }

    static func fetchCandidates(store: HKHealthStore, existingIdentifiers: Set<String>) async throws -> [ImportCandidate] {
        var candidates: [ImportCandidate] = []
        for (identifier, kind) in clinicalTypes {
            guard let type = HKObjectType.clinicalType(forIdentifier: identifier) else { continue }
            let records = try await fetchRecords(store: store, type: type)
            for record in records {
                let candidate = makeCandidate(from: record, kind: kind, existingIdentifiers: existingIdentifiers)
                candidates.append(candidate)
            }
        }
        return candidates
    }

    private static func fetchRecords(store: HKHealthStore, type: HKClinicalType) async throws -> [HKClinicalRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error {
                    // Denied/undetermined clinical types surface as errors;
                    // treat as "no records" so other types still import.
                    if (error as? HKError)?.code == .errorAuthorizationDenied
                        || (error as? HKError)?.code == .errorAuthorizationNotDetermined {
                        continuation.resume(returning: [])
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                continuation.resume(returning: (samples as? [HKClinicalRecord]) ?? [])
            }
            store.execute(query)
        }
    }

    private static func makeCandidate(from record: HKClinicalRecord, kind: ImportCandidate.Kind, existingIdentifiers: Set<String>) -> ImportCandidate {
        let fhirData = record.fhirResource?.data
        let identifier = record.fhirResource.map { "\($0.resourceType.rawValue)/\($0.identifier)" } ?? record.uuid.uuidString
        let parsed = FHIRRecordFields(data: fhirData)
        return ImportCandidate(
            id: identifier,
            kind: kind,
            displayName: record.displayName,
            detail: parsed.detail,
            date: parsed.date,
            status: parsed.status,
            code: parsed.code,
            codeSystem: parsed.codeSystem,
            fhirData: fhirData,
            alreadyImported: existingIdentifiers.contains(identifier)
        )
    }
}

// Best-effort field extraction that tolerates both FHIR DSTU2 and R4 shapes.
// Anything unparsed is fine — the raw JSON is stored with the record.
struct FHIRRecordFields {
    var detail: String?
    var date: Date?
    var status: String?
    var code: String?
    var codeSystem: String?

    init(data: Data?) {
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        // Status: R4 clinicalStatus/status may be a CodeableConcept or string.
        for key in ["clinicalStatus", "status"] {
            if let value = json[key] as? String {
                status = value
                break
            }
            if let concept = json[key] as? [String: Any], let text = Self.conceptText(concept) {
                status = text
                break
            }
        }

        // Date: first ISO date-like string among common fields.
        let dateKeys = ["onsetDateTime", "occurrenceDateTime", "date", "effectiveDateTime", "authoredOn", "dateWritten", "recordedDate", "assertedDate"]
        for key in dateKeys {
            if let value = json[key] as? String, let parsed = Self.parseFHIRDate(value) {
                date = parsed
                break
            }
        }

        // Code: whichever coded field this resource type carries.
        let codeKeys = ["code", "vaccineCode", "medicationCodeableConcept", "substance"]
        for key in codeKeys {
            guard let concept = json[key] as? [String: Any] else { continue }
            if detail == nil { detail = concept["text"] as? String }
            if let codings = concept["coding"] as? [[String: Any]], let first = codings.first {
                code = first["code"] as? String
                codeSystem = first["system"] as? String
            }
            break
        }

        // Dosage text is the most useful medication detail when present.
        if let dosages = (json["dosage"] ?? json["dosageInstruction"]) as? [[String: Any]],
           let text = dosages.first?["text"] as? String {
            detail = text
        }
    }

    private static func conceptText(_ concept: [String: Any]) -> String? {
        if let text = concept["text"] as? String { return text }
        if let codings = concept["coding"] as? [[String: Any]] {
            return codings.first?["code"] as? String
        }
        return nil
    }

    private static func parseFHIRDate(_ value: String) -> Date? {
        // FHIR dates can be YYYY, YYYY-MM, YYYY-MM-DD, or full ISO8601.
        let dayPrefix = String(value.prefix(10))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd", "yyyy-MM", "yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: format == "yyyy-MM-dd" ? dayPrefix : value) {
                return date
            }
        }
        return nil
    }
}

import Foundation
import FoundationModels

// On-device symptom assistant built on Apple's Foundation Models. Everything
// runs locally — no health data leaves the device. The model is grounded in
// the user's own records via tools that read a Sendable snapshot taken when
// the session is created (avoids passing SwiftData models across concurrency
// domains). Requires iOS 26+; callers must handle the unavailable case and
// fall back to SymptomInsights.
@available(iOS 26.0, *)
@MainActor
final class SymptomAssistant {

    enum Availability {
        case available
        case unavailable(String)
    }

    static var availability: Availability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable("This device doesn't support on-device intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable("Turn on Apple Intelligence in Settings to use the assistant.")
        case .unavailable(.modelNotReady):
            return .unavailable("The on-device model is still downloading. Try again shortly.")
        case .unavailable:
            return .unavailable("On-device intelligence isn't available right now.")
        }
    }

    private let session: LanguageModelSession

    init(profile: Profile) {
        let snapshot = ProfileSnapshot(profile: profile)
        let tools: [any Tool] = [
            RecentSymptomsTool(snapshot: snapshot),
            SymptomFrequencyTool(snapshot: snapshot),
            HealthContextTool(snapshot: snapshot),
        ]
        session = LanguageModelSession(tools: tools, instructions: Self.instructions)
    }

    /// Answers a question, grounded in the user's records. Red-flag screening
    /// happens in the UI before this is ever called.
    func answer(to question: String) async throws -> String {
        let response = try await session.respond(to: question)
        return response.content
    }

    private static let instructions = """
    You are a calm, plain-spoken health assistant inside a personal medical \
    record app. You help the user understand the symptoms they have logged and \
    answer general health questions.

    Ground every answer about the user's own history in the tools provided — \
    call them to get real counts and dates rather than guessing. If the tools \
    show no relevant data, say so plainly.

    Critical rules:
    - You are not a doctor and must not diagnose, prescribe, or tell the user \
    they definitely have a condition. Offer general, educational information \
    and possibilities only.
    - Always encourage the user to consult a qualified clinician for anything \
    concerning, persistent, or worsening.
    - Never provide dosages or specific treatment instructions.
    - Keep answers short and readable — a few sentences. Use everyday language.
    - If a question describes a possible emergency, tell the user to seek \
    emergency care immediately instead of analyzing it.
    """
}

// MARK: - Sendable snapshot of the profile

@available(iOS 26.0, *)
struct ProfileSnapshot: Sendable {
    struct SymptomFact: Sendable {
        let name: String
        let severity: String?
        let status: String
        let onset: Date?
        let recorded: Date
    }

    let symptoms: [SymptomFact]
    let activeConditions: [String]
    let currentMedications: [String]

    @MainActor
    init(profile: Profile) {
        symptoms = profile.symptoms
            .sorted { $0.recordedDate > $1.recordedDate }
            .map { SymptomFact(name: $0.name, severity: $0.severity,
                               status: $0.status, onset: $0.onsetDate,
                               recorded: $0.recordedDate) }
        activeConditions = profile.conditions
            .filter { $0.clinicalStatus == "active" }
            .map(\.name)
        currentMedications = profile.medications
            .filter { $0.status == "active" }
            .map(\.name)
    }

    func matches(_ query: String, withinDays days: Int?) -> [SymptomFact] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cutoff = days.flatMap { $0 > 0 ? Calendar.current.date(byAdding: .day, value: -$0, to: Date()) : nil }
        return symptoms.filter { s in
            let hay = s.name.lowercased()
            let nameHit = needle.isEmpty || hay.contains(needle) || needle.contains(hay)
            let dateHit = cutoff.map { s.recorded >= $0 } ?? true
            return nameHit && dateHit
        }
    }
}

// MARK: - Tools (read the snapshot, return plain text for the model)

@available(iOS 26.0, *)
struct RecentSymptomsTool: Tool {
    let name = "recentSymptoms"
    let description = "Lists the symptoms the user has logged most recently, with their status and dates."
    let snapshot: ProfileSnapshot

    @Generable
    struct Arguments {
        @Guide(description: "How many recent symptoms to return, at most.")
        var limit: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let limit = max(1, min(arguments.limit, 20))
        let items = snapshot.symptoms.prefix(limit)
        guard !items.isEmpty else { return "The user has not logged any symptoms." }
        return items.map { s in
            let when = (s.onset ?? s.recorded).formatted(date: .abbreviated, time: .omitted)
            let sev = s.severity.map { ", \($0)" } ?? ""
            return "- \(s.name)\(sev), \(s.status), since \(when)"
        }.joined(separator: "\n")
    }
}

@available(iOS 26.0, *)
struct SymptomFrequencyTool: Tool {
    let name = "symptomFrequency"
    let description = "Counts how many times the user logged a specific symptom, optionally within a recent number of days."
    let snapshot: ProfileSnapshot

    @Generable
    struct Arguments {
        @Guide(description: "The symptom to count, e.g. \"headache\".")
        var symptom: String
        @Guide(description: "Only count logs within this many days. Use 0 for all time.")
        var withinDays: Int
    }

    func call(arguments: Arguments) async throws -> String {
        let days = arguments.withinDays > 0 ? arguments.withinDays : nil
        let hits = snapshot.matches(arguments.symptom, withinDays: days)
        let window = days.map { "in the last \($0) days" } ?? "in total"
        guard let mostRecent = hits.first else {
            return "The user has not logged \"\(arguments.symptom)\" \(window)."
        }
        let when = (mostRecent.onset ?? mostRecent.recorded).formatted(date: .abbreviated, time: .omitted)
        return "The user logged \"\(arguments.symptom)\" \(hits.count) time(s) \(window). Most recent: \(when)."
    }
}

@available(iOS 26.0, *)
struct HealthContextTool: Tool {
    let name = "healthContext"
    let description = "Returns the user's active conditions and current medications for context. Use when relevant to a general question."
    let snapshot: ProfileSnapshot

    @Generable
    struct Arguments {}

    func call(arguments: Arguments) async throws -> String {
        let conditions = snapshot.activeConditions.isEmpty ? "none recorded" : snapshot.activeConditions.joined(separator: ", ")
        let meds = snapshot.currentMedications.isEmpty ? "none recorded" : snapshot.currentMedications.joined(separator: ", ")
        return "Active conditions: \(conditions). Current medications: \(meds)."
    }
}

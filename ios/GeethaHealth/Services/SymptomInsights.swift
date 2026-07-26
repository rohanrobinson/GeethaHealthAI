import Foundation

// Deterministic, fully on-device analysis over a profile's symptom log.
// Two jobs:
//   1. Feed exact numbers to the on-device assistant's tools (so LLM answers
//      about the user's own data are grounded in real rows, not guesses).
//   2. Serve as the complete fallback experience when Apple's Foundation
//      Models are unavailable — templated summaries + a heuristic Q&A path.
// Also owns red-flag detection, which must never depend on the LLM.
struct SymptomInsights {
    let profile: Profile

    private var symptoms: [SymptomObservation] {
        profile.symptoms.sorted { $0.recordedDate > $1.recordedDate }
    }

    // MARK: Own-data queries (also exposed to the assistant as tools)

    /// Distinct symptom names the user has logged, most-recent first.
    func loggedSymptomNames() -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for s in symptoms where seen.insert(s.name.lowercased()).inserted {
            names.append(s.name)
        }
        return names
    }

    /// How many times a symptom was logged, optionally within the last `days`.
    func occurrenceCount(matching query: String, withinDays days: Int? = nil) -> Int {
        matches(query, within: days).count
    }

    /// The most recent log of a symptom, if any.
    func mostRecent(matching query: String) -> SymptomObservation? {
        matches(query, within: nil).first
    }

    func activeSymptoms() -> [SymptomObservation] {
        symptoms.filter { $0.status != "resolved" }
    }

    private func matches(_ query: String, within days: Int?) -> [SymptomObservation] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cutoff = days.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date())! }
        return symptoms.filter { s in
            let hay = s.name.lowercased()
            let nameHit = needle.isEmpty || hay.contains(needle) || needle.contains(hay)
            let dateHit = cutoff.map { s.recordedDate >= $0 } ?? true
            return nameHit && dateHit
        }
    }

    // MARK: Templated summary (deterministic fallback UI)

    func overview() -> String {
        let all = symptoms
        guard !all.isEmpty else {
            return "You haven't logged any symptoms yet. Add one from the Symptoms section of your records to start tracking."
        }
        let active = activeSymptoms()
        let last30 = all.filter {
            $0.recordedDate >= Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        }
        var lines: [String] = []
        lines.append("You've logged \(all.count) symptom entr\(all.count == 1 ? "y" : "ies") in total, \(last30.count) in the last 30 days.")
        if !active.isEmpty {
            let names = active.prefix(5).map(\.name).joined(separator: ", ")
            lines.append("Currently active: \(names).")
        }
        // Most frequent symptom names in the last 30 days.
        let counts = Dictionary(grouping: last30, by: { $0.name })
            .mapValues(\.count)
            .sorted { $0.value > $1.value }
        if let top = counts.first, top.value > 1 {
            lines.append("Most frequent recently: \(top.key) (\(top.value) times).")
        }
        return lines.joined(separator: " ")
    }

    /// A best-effort deterministic answer to a free-text question, used when
    /// the on-device model is unavailable. Never diagnoses.
    func answer(to question: String) -> String {
        let q = question.lowercased()
        // Try to anchor on a symptom the user has actually logged.
        let anchor = loggedSymptomNames().first { name in
            q.contains(name.lowercased())
        }

        if let anchor {
            let total = occurrenceCount(matching: anchor)
            let last30 = occurrenceCount(matching: anchor, withinDays: 30)
            if q.contains("when") || q.contains("last") {
                if let recent = mostRecent(matching: anchor) {
                    let when = (recent.onsetDate ?? recent.recordedDate)
                        .formatted(date: .abbreviated, time: .omitted)
                    return "You most recently logged \(anchor) on \(when). It's recorded \(total) time\(total == 1 ? "" : "s") in total."
                }
            }
            return "You've logged \(anchor) \(total) time\(total == 1 ? "" : "s") in total, \(last30) in the last 30 days. For what it might mean or whether to act on it, please check with a clinician."
        }

        // No specific symptom recognized — return the general overview.
        return overview() + " I can answer questions about the symptoms you've logged; for medical advice, please consult a clinician."
    }

    // MARK: Red-flag detection (safety — shared, LLM-independent)

    struct RedFlag {
        let message: String
    }

    /// Scans free text for emergency descriptions. Returns an escalation
    /// message when matched, otherwise nil. Intentionally high-recall.
    static func redFlag(in text: String) -> RedFlag? {
        let t = text.lowercased()
        let emergencyPhrases = [
            "chest pain", "chest pressure", "crushing chest",
            "can't breathe", "cant breathe", "trouble breathing", "difficulty breathing", "struggling to breathe",
            "face droop", "slurred speech", "sudden weakness", "one side", "can't move", "cant move",
            "worst headache", "sudden severe headache",
            "suicidal", "kill myself", "end my life", "want to die",
            "unconscious", "passed out", "unresponsive",
            "severe bleeding", "coughing up blood", "vomiting blood",
            "anaphylaxis", "throat closing", "lips swelling",
            "seizure", "stroke", "heart attack",
        ]
        guard emergencyPhrases.contains(where: { t.contains($0) }) else { return nil }
        return RedFlag(message: """
        What you're describing may be a medical emergency. This app can't help with urgent symptoms — please call your local emergency number (911 in the US) or go to the nearest emergency department now.
        """)
    }
}

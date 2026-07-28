import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// Structured symptom pulled from a free-text voice transcript. Maps 1:1 onto the
// fields SymptomFormView / SymptomObservation use, so a draft can prefill the
// form or be saved directly from the confirm card. The raw transcript is always
// carried in `notes` so nothing the user said is lost, even on a partial parse.
struct SymptomDraft: Equatable {
    var name: String = ""
    var severity: String?          // "mild" | "moderate" | "severe"
    var bodySite: String?
    var onsetDate: Date?
    var status: String = "active"  // "active" | "resolved"
    var notes: String?
    var code: String?
    var codeSystem: String?

    /// True when we couldn't identify a symptom name — the flow should route the
    /// user to the full form to finish manually rather than offer a quick save.
    var isResolved: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
}

// Turns a transcript into a SymptomDraft. Implementations are swappable so the
// flow can use Foundation Models (iOS 26+), a deterministic heuristic fallback,
// or a mock — chosen by `makeSymptomParser()`.
protocol SymptomParsing {
    func parse(_ transcript: String) async -> SymptomDraft
}

/// Picks the best available parser: mock when running against mocks, Foundation
/// Models on iOS 26+ when Apple Intelligence is ready, otherwise the heuristic.
@MainActor
func makeSymptomParser() -> SymptomParsing {
    if VoiceEntryConfig.useMocks {
        return MockSymptomParser()
    }
    if #available(iOS 26.0, *), case .available = SymptomAssistant.availability {
        return FoundationModelsSymptomParser()
    }
    return HeuristicSymptomParser()
}

// MARK: - Shared coding resolution

enum SymptomCoding {
    static let system = "http://snomed.info/sct"

    /// Attaches a SNOMED code to a draft using the offline vocabulary. Tries the
    /// parsed name first, then falls back to scanning the raw transcript. Also
    /// normalizes the name to the vocabulary's display form. Runs for every
    /// parser so coding lives in exactly one place.
    static func resolve(_ draft: inout SymptomDraft) async {
        guard draft.code == nil else { return }
        let store = VocabularyStore.shared

        if draft.isResolved, let hit = await store.searchSymptoms(draft.name, limit: 1).first {
            draft.name = hit.displayName
            draft.code = hit.snomedCode
            draft.codeSystem = system
            return
        }
        if let hit = await store.bestSymptomMatch(in: draft.notes ?? draft.name) {
            if !draft.isResolved { draft.name = hit.displayName }
            draft.code = hit.snomedCode
            draft.codeSystem = system
        }
    }
}

// MARK: - Foundation Models parser (iOS 26+)

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct FoundationModelsSymptomParser: SymptomParsing {

    @Generable
    struct Extracted {
        @Guide(description: "The main symptom as a short noun phrase, e.g. \"headache\", \"dizziness\", \"sore throat\". Empty string if no symptom is described.")
        var name: String
        @Guide(description: "Severity if the person states it: exactly one of \"mild\", \"moderate\", \"severe\". Empty string if not stated.")
        var severity: String
        @Guide(description: "Body location if mentioned, e.g. \"left knee\", \"lower back\". Empty string if none.")
        var bodySite: String
        @Guide(description: "\"resolved\" if the symptom has gone away, otherwise \"active\".")
        var status: String
        @Guide(description: "How many days ago the symptom started. 0 if it started today or is unstated.")
        var daysAgo: Int
    }

    func parse(_ transcript: String) async -> SymptomDraft {
        var draft = SymptomDraft()
        draft.notes = transcript
        do {
            let session = LanguageModelSession(instructions: Self.instructions)
            let result = try await session.respond(to: transcript, generating: Extracted.self).content
            draft.name = result.name.trimmingCharacters(in: .whitespaces)
            draft.severity = Self.normalizeSeverity(result.severity)
            let site = result.bodySite.trimmingCharacters(in: .whitespaces)
            draft.bodySite = site.isEmpty ? nil : site
            draft.status = result.status.lowercased() == "resolved" ? "resolved" : "active"
            if result.daysAgo > 0 {
                draft.onsetDate = Calendar.current.date(byAdding: .day, value: -result.daysAgo, to: Date())
            }
        } catch {
            // On any model error, degrade to the heuristic so the user still
            // gets a usable draft rather than nothing.
            return await HeuristicSymptomParser().parse(transcript)
        }
        return draft
    }

    private static func normalizeSeverity(_ raw: String) -> String? {
        switch raw.lowercased() {
        case "mild": return "mild"
        case "moderate": return "moderate"
        case "severe": return "severe"
        default: return nil
        }
    }

    private static let instructions = """
    You extract a single patient-reported symptom from a short spoken sentence \
    and return it as structured fields. Capture only what the person actually \
    says — never invent a severity, body site, or date that wasn't stated. If \
    several symptoms are mentioned, extract the first/primary one only.
    """
}
#endif

// MARK: - Heuristic parser (deterministic fallback)

// Used pre-iOS 26 or when Apple Intelligence is unavailable. Keeps the full
// transcript, best-effort extracts severity and a rough onset, and lets
// vocabulary matching (in SymptomCoding.resolve) recover the symptom name.
struct HeuristicSymptomParser: SymptomParsing {
    func parse(_ transcript: String) async -> SymptomDraft {
        var draft = SymptomDraft()
        draft.notes = transcript
        let lower = transcript.lowercased()

        if lower.contains("severe") || lower.contains("really bad") || lower.contains("terrible") {
            draft.severity = "severe"
        } else if lower.contains("moderate") {
            draft.severity = "moderate"
        } else if lower.contains("mild") || lower.contains("slight") {
            draft.severity = "mild"
        }

        if lower.contains("went away") || lower.contains("gone now") || lower.contains("resolved") || lower.contains("better now") {
            draft.status = "resolved"
        }

        draft.onsetDate = Self.onsetDate(from: lower)
        // Name is left empty; SymptomCoding.resolve recovers it from the
        // transcript via the vocabulary. If that fails too, the flow routes to
        // the full form for manual completion.
        return draft
    }

    // Handles the common relative-time phrases; anything richer is left to the
    // user to adjust in the form.
    private static func onsetDate(from text: String) -> Date? {
        let cal = Calendar.current
        let now = Date()
        if text.contains("yesterday") { return cal.date(byAdding: .day, value: -1, to: now) }
        if text.contains("today") || text.contains("this morning") { return now }
        if let days = firstNumber(before: "day", in: text) {
            return cal.date(byAdding: .day, value: -days, to: now)
        }
        if let weeks = firstNumber(before: "week", in: text) {
            return cal.date(byAdding: .day, value: -weeks * 7, to: now)
        }
        return nil
    }

    // Pulls "3" out of "3 days ago" / "two weeks".
    private static func firstNumber(before unit: String, in text: String) -> Int? {
        let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let numberWords = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4,
                           "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10]
        for (i, word) in words.enumerated() where word.hasPrefix(unit) && i > 0 {
            let prev = words[i - 1]
            if let n = Int(prev) { return n }
            if let n = numberWords[prev] { return n }
        }
        return nil
    }
}

// MARK: - Mock parser (Simulator / UI tests)

struct MockSymptomParser: SymptomParsing {
    func parse(_ transcript: String) async -> SymptomDraft {
        var draft = SymptomDraft()
        draft.notes = transcript
        // Let the heuristic + vocabulary do the real work so the mock still
        // produces a coherent, resolvable draft from the scripted transcript.
        return await HeuristicSymptomParser().parse(transcript)
    }
}

import Foundation

struct DrugEntry: Decodable, Identifiable, Sendable {
    let n: String              // display name, e.g. "Lisinopril (Oral Pill)"
    let c: String              // RxNorm drug-group RXCUI
    let s: [DrugStrength]

    var id: String { c + n }
    var displayName: String { n }
    var strengths: [DrugStrength] { s }
}

struct DrugStrength: Decodable, Hashable, Sendable {
    let s: String              // e.g. "10 mg"
    let c: String              // strength-specific RXCUI

    var label: String { s }
    var rxcui: String { c }
}

struct VaccineEntry: Decodable, Identifiable, Sendable {
    let n: String              // short name, e.g. "influenza, seasonal, injectable"
    let f: String              // full clinical name
    let c: String              // CVX code
    let st: String             // Active | Inactive | ...

    var id: String { c + n }
    var displayName: String { n }
    var fullName: String { f }
    var cvxCode: String { c }
}

// Bundled, fully offline vocabularies (RxTerms for drugs, CDC CVX for
// vaccines). Search never leaves the device.
actor VocabularyStore {
    static let shared = VocabularyStore()

    private var drugs: [DrugEntry]?
    private var vaccines: [VaccineEntry]?

    func searchDrugs(_ query: String, limit: Int = 20) -> [DrugEntry] {
        if drugs == nil {
            drugs = Self.load("medications", as: [DrugEntry].self)
        }
        return Self.rank(query: query, in: drugs ?? [], limit: limit) { $0.displayName }
    }

    func searchVaccines(_ query: String, limit: Int = 20) -> [VaccineEntry] {
        if vaccines == nil {
            vaccines = Self.load("vaccines", as: [VaccineEntry].self)
        }
        return Self.rank(query: query, in: vaccines ?? [], limit: limit) { $0.displayName + " " + $0.fullName }
    }

    private static func load<T: Decodable>(_ resource: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    // Matches every whitespace-separated query token as a word prefix
    // ("amox 500" matches "Amoxicillin ... 500 mg"); name-starts-with
    // matches rank first.
    private static func rank<T>(query: String, in items: [T], limit: Int, text: (T) -> String) -> [T] {
        let tokens = query.lowercased().split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }

        var prefixMatches: [T] = []
        var wordMatches: [T] = []
        for item in items {
            let haystack = text(item).lowercased()
            let words = haystack.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
            let allTokensMatch = tokens.allSatisfy { token in
                words.contains { $0.hasPrefix(token) }
            }
            guard allTokensMatch else { continue }
            if haystack.hasPrefix(tokens[0]) {
                prefixMatches.append(item)
            } else {
                wordMatches.append(item)
            }
            if prefixMatches.count >= limit { break }
        }
        return Array((prefixMatches + wordMatches).prefix(limit))
    }
}

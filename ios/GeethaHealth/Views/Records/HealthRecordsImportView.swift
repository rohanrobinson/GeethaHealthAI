import SwiftUI
import SwiftData
import HealthKit

struct HealthRecordsImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile

    private enum Phase {
        case loading
        case unavailable
        case loaded
        case failed(String)
    }

    @State private var phase: Phase = .loading
    @State private var candidates: [ImportCandidate] = []
    @State private var selection: Set<String> = []
    @State private var healthStore = HKHealthStore()

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .loading:
                    ProgressView("Reading Apple Health…")
                case .unavailable:
                    ContentUnavailableView(
                        "Apple Health not available",
                        systemImage: "heart.slash",
                        description: Text("Health records aren't available on this device.")
                    )
                case .failed(let message):
                    ContentUnavailableView(
                        "Couldn't read records",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loaded where candidates.isEmpty:
                    ContentUnavailableView(
                        "No health records found",
                        systemImage: "heart.text.square",
                        description: Text("Connect your healthcare provider in the Health app (Browse → Health Records), and make sure Geetha Health has access in Settings → Health → Data Access & Devices.")
                    )
                case .loaded:
                    candidateList
                }
            }
            .navigationTitle("Import from Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(selection.count)") { importSelected() }
                        .disabled(selection.isEmpty)
                }
            }
            .task { await load() }
        }
    }

    private var candidateList: some View {
        List {
            Section {
                Text("Records stay on this device. Already-imported records are skipped automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(ImportCandidate.Kind.allCases, id: \.self) { kind in
                let items = candidates.filter { $0.kind == kind }
                if !items.isEmpty {
                    Section(kind.rawValue) {
                        ForEach(items) { candidate in
                            candidateRow(candidate)
                        }
                    }
                }
            }
        }
    }

    private func candidateRow(_ candidate: ImportCandidate) -> some View {
        Button {
            guard !candidate.alreadyImported else { return }
            if selection.contains(candidate.id) {
                selection.remove(candidate.id)
            } else {
                selection.insert(candidate.id)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(candidate.displayName)
                        .foregroundStyle(candidate.alreadyImported ? .secondary : .primary)
                    if let subtitle = subtitle(for: candidate) {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if candidate.alreadyImported {
                    Text("Imported")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: selection.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    private func subtitle(for candidate: ImportCandidate) -> String? {
        let parts = [
            candidate.detail,
            candidate.status?.capitalized,
            candidate.date.map { $0.formatted(date: .abbreviated, time: .omitted) },
        ].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func load() async {
        guard HealthRecordsImporter.isAvailable else {
            phase = .unavailable
            return
        }
        do {
            try await HealthRecordsImporter.requestAuthorization(store: healthStore)
            let existing = existingIdentifiers()
            let fetched = try await HealthRecordsImporter.fetchCandidates(store: healthStore, existingIdentifiers: existing)
            candidates = fetched
            selection = Set(fetched.filter { !$0.alreadyImported }.map(\.id))
            phase = .loaded
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func existingIdentifiers() -> Set<String> {
        var identifiers: Set<String> = []
        for id in profile.allergies.compactMap(\.healthKitIdentifier) { identifiers.insert(id) }
        for id in profile.conditions.compactMap(\.healthKitIdentifier) { identifiers.insert(id) }
        for id in profile.medications.compactMap(\.healthKitIdentifier) { identifiers.insert(id) }
        for id in profile.immunizations.compactMap(\.healthKitIdentifier) { identifiers.insert(id) }
        return identifiers
    }

    private func importSelected() {
        for candidate in candidates where selection.contains(candidate.id) && !candidate.alreadyImported {
            insert(candidate)
        }
        dismiss()
    }

    private func insert(_ candidate: ImportCandidate) {
        switch candidate.kind {
        case .allergy:
            let allergy = Allergy(
                name: candidate.displayName,
                code: candidate.code,
                codeSystem: candidate.codeSystem,
                sourceFHIRJSON: candidate.fhirData,
                healthKitIdentifier: candidate.id
            )
            allergy.profile = profile
            context.insert(allergy)
        case .condition:
            let condition = Condition(
                name: candidate.displayName,
                clinicalStatus: candidate.status ?? "active",
                onsetDate: candidate.date,
                code: candidate.code,
                codeSystem: candidate.codeSystem,
                sourceFHIRJSON: candidate.fhirData,
                healthKitIdentifier: candidate.id
            )
            condition.profile = profile
            context.insert(condition)
        case .medication:
            let medication = Medication(
                name: candidate.displayName,
                dosageText: candidate.detail,
                status: candidate.status ?? "active",
                startDate: candidate.date,
                code: candidate.code,
                codeSystem: candidate.codeSystem,
                sourceFHIRJSON: candidate.fhirData,
                healthKitIdentifier: candidate.id
            )
            medication.profile = profile
            context.insert(medication)
        case .immunization:
            let immunization = Immunization(
                name: candidate.displayName,
                administeredDate: candidate.date,
                code: candidate.code,
                codeSystem: candidate.codeSystem,
                sourceFHIRJSON: candidate.fhirData,
                healthKitIdentifier: candidate.id
            )
            immunization.profile = profile
            context.insert(immunization)
        }
    }
}

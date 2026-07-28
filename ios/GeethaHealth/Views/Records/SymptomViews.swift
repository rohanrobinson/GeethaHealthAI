import SwiftUI
import SwiftData

struct SymptomListView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile
    @State private var showingAdd = false
    @State private var editing: SymptomObservation?

    private var items: [SymptomObservation] {
        profile.symptoms.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No symptoms",
                    systemImage: "waveform.path.ecg",
                    description: Text("Log symptoms you're experiencing to track them over time.")
                )
            } else {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundStyle(.primary)
                            Text(subtitle(for: item))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets { context.delete(items[offset]) }
                }
            }
        }
        .navigationTitle("Symptoms")
        .toolbar {
            Button("Add", systemImage: "plus") { showingAdd = true }
        }
        .sheet(isPresented: $showingAdd) {
            SymptomFormView(profile: profile)
        }
        .sheet(item: $editing) { item in
            SymptomFormView(profile: profile, existing: item)
        }
    }

    private func subtitle(for item: SymptomObservation) -> String {
        var parts: [String] = []
        if let severity = item.severity { parts.append(severity.capitalized) }
        parts.append(item.status == "resolved" ? "Resolved" : "Active")
        if let onset = item.onsetDate {
            parts.append("since \(onset.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.joined(separator: " · ")
    }
}

struct SymptomFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    var existing: SymptomObservation?
    // Initial values for a brand-new record (existing == nil), e.g. a symptom
    // parsed from voice that the user wants to review in the full form before
    // saving. Ignored when editing an existing record.
    var prefill: SymptomDraft?

    @State private var name = ""
    @State private var severity = ""
    @State private var bodySite = ""
    @State private var hasOnsetDate = false
    @State private var onsetDate = Date()
    @State private var status = "active"
    @State private var notes = ""
    @State private var code: String?
    @State private var codeSystem: String?
    @State private var suggestions: [SymptomEntry] = []
    // Name whose code we already hold (picked suggestion or loaded record);
    // searching resumes only when the user edits away from it.
    @State private var acceptedName: String?

    private let severityOptions = ["", "mild", "moderate", "severe"]
    private let statusOptions = ["active", "resolved"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Symptom (e.g. Dizziness)", text: $name)
                        .autocorrectionDisabled()
                    ForEach(suggestions) { symptom in
                        Button {
                            select(symptom)
                        } label: {
                            Text(symptom.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                Picker("Severity", selection: $severity) {
                    Text("Not set").tag("")
                    ForEach(severityOptions.filter { !$0.isEmpty }, id: \.self) {
                        Text($0.capitalized).tag($0)
                    }
                }
                Picker("Status", selection: $status) {
                    ForEach(statusOptions, id: \.self) { Text($0.capitalized) }
                }
                Toggle("Onset date", isOn: $hasOnsetDate.animation())
                if hasOnsetDate {
                    DatePicker("Since", selection: $onsetDate, in: ...Date(), displayedComponents: .date)
                }
                TextField("Body site (optional)", text: $bodySite)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .task(id: name) {
                let query = name.trimmingCharacters(in: .whitespaces)
                if query.count < 2 || query == acceptedName {
                    suggestions = []
                    return
                }
                code = nil
                codeSystem = nil
                suggestions = await VocabularyStore.shared.searchSymptoms(query, limit: 8)
            }
            .navigationTitle(existing == nil ? "Log symptom" : "Edit symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func select(_ symptom: SymptomEntry) {
        acceptedName = symptom.displayName
        name = symptom.displayName
        code = symptom.snomedCode
        codeSystem = "http://snomed.info/sct"
        suggestions = []
    }

    private func load() {
        if let existing {
            acceptedName = existing.name
            name = existing.name
            severity = existing.severity ?? ""
            bodySite = existing.bodySite ?? ""
            hasOnsetDate = existing.onsetDate != nil
            onsetDate = existing.onsetDate ?? Date()
            status = existing.status
            notes = existing.notes ?? ""
            code = existing.code
            codeSystem = existing.codeSystem
        } else if let prefill {
            // Seed a new record from a voice-parsed draft. Mark the name as
            // accepted so the vocabulary search doesn't immediately clear the
            // code we already resolved.
            if !prefill.name.isEmpty { acceptedName = prefill.name }
            name = prefill.name
            severity = prefill.severity ?? ""
            bodySite = prefill.bodySite ?? ""
            hasOnsetDate = prefill.onsetDate != nil
            onsetDate = prefill.onsetDate ?? Date()
            status = prefill.status
            notes = prefill.notes ?? ""
            code = prefill.code
            codeSystem = prefill.codeSystem
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmedName
            existing.severity = severity.isEmpty ? nil : severity
            existing.bodySite = bodySite.isEmpty ? nil : bodySite
            existing.onsetDate = hasOnsetDate ? onsetDate : nil
            existing.status = status
            existing.notes = notes.isEmpty ? nil : notes
            existing.code = code
            existing.codeSystem = codeSystem
        } else {
            let symptom = SymptomObservation(
                name: trimmedName,
                severity: severity.isEmpty ? nil : severity,
                bodySite: bodySite.isEmpty ? nil : bodySite,
                onsetDate: hasOnsetDate ? onsetDate : nil,
                status: status,
                notes: notes.isEmpty ? nil : notes,
                code: code,
                codeSystem: codeSystem
            )
            symptom.profile = profile
            context.insert(symptom)
        }
        dismiss()
    }
}

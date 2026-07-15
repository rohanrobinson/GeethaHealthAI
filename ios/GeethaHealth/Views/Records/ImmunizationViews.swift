import SwiftUI
import SwiftData

struct ImmunizationListView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile
    @State private var showingAdd = false
    @State private var editing: Immunization?

    private var items: [Immunization] {
        profile.immunizations.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No immunizations",
                    systemImage: "syringe",
                    description: Text("Add vaccines and when you received them.")
                )
            } else {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundStyle(.primary)
                            if let date = item.administeredDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets { context.delete(items[offset]) }
                }
            }
        }
        .navigationTitle("Immunizations")
        .toolbar {
            Button("Add", systemImage: "plus") { showingAdd = true }
        }
        .sheet(isPresented: $showingAdd) {
            ImmunizationFormView(profile: profile)
        }
        .sheet(item: $editing) { item in
            ImmunizationFormView(profile: profile, existing: item)
        }
    }
}

struct ImmunizationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    var existing: Immunization?

    @State private var name = ""
    @State private var hasDate = false
    @State private var administeredDate = Date()
    @State private var notes = ""
    @State private var code: String?
    @State private var codeSystem: String?
    @State private var suggestions: [VaccineEntry] = []
    // Name whose code we already hold (picked suggestion or loaded record);
    // searching resumes only when the user edits away from it.
    @State private var acceptedName: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vaccine (e.g. Influenza)", text: $name)
                        .autocorrectionDisabled()
                    ForEach(suggestions) { vaccine in
                        Button {
                            select(vaccine)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(vaccine.displayName)
                                    .font(.subheadline)
                                    .foregroundStyle(.tint)
                                Text(vaccine.fullName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Toggle("Date received", isOn: $hasDate.animation())
                if hasDate {
                    DatePicker("Received", selection: $administeredDate, in: ...Date(), displayedComponents: .date)
                }
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
                suggestions = await VocabularyStore.shared.searchVaccines(query, limit: 8)
            }
            .navigationTitle(existing == nil ? "Add immunization" : "Edit immunization")
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

    private func select(_ vaccine: VaccineEntry) {
        acceptedName = vaccine.displayName
        name = vaccine.displayName
        code = vaccine.cvxCode
        codeSystem = "http://hl7.org/fhir/sid/cvx"
        suggestions = []
    }

    private func load() {
        guard let existing else { return }
        acceptedName = existing.name
        name = existing.name
        hasDate = existing.administeredDate != nil
        administeredDate = existing.administeredDate ?? Date()
        notes = existing.notes ?? ""
        code = existing.code
        codeSystem = existing.codeSystem
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmedName
            existing.administeredDate = hasDate ? administeredDate : nil
            existing.notes = notes.isEmpty ? nil : notes
            existing.code = code
            existing.codeSystem = codeSystem
        } else {
            let immunization = Immunization(
                name: trimmedName,
                administeredDate: hasDate ? administeredDate : nil,
                notes: notes.isEmpty ? nil : notes,
                code: code,
                codeSystem: codeSystem
            )
            immunization.profile = profile
            context.insert(immunization)
        }
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile
    @State private var showingAdd = false
    @State private var editing: Medication?

    private var items: [Medication] {
        profile.medications.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No medications",
                    systemImage: "pills",
                    description: Text("Add current and past medications.")
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
        .navigationTitle("Medications")
        .toolbar {
            Button("Add", systemImage: "plus") { showingAdd = true }
        }
        .sheet(isPresented: $showingAdd) {
            MedicationFormView(profile: profile)
        }
        .sheet(item: $editing) { item in
            MedicationFormView(profile: profile, existing: item)
        }
    }

    private func subtitle(for item: Medication) -> String {
        [item.dosageText, item.frequencyText, item.status.capitalized]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct MedicationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    var existing: Medication?

    @State private var name = ""
    @State private var dosageText = ""
    @State private var frequencyText = ""
    @State private var status = "active"
    @State private var notes = ""

    private let statusOptions = ["active", "completed", "stopped"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Medication name", text: $name)
                TextField("Dosage (e.g. 10 mg)", text: $dosageText)
                TextField("Frequency (e.g. once daily)", text: $frequencyText)
                Picker("Status", selection: $status) {
                    ForEach(statusOptions, id: \.self) { Text($0.capitalized) }
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle(existing == nil ? "Add medication" : "Edit medication")
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

    private func load() {
        guard let existing else { return }
        name = existing.name
        dosageText = existing.dosageText ?? ""
        frequencyText = existing.frequencyText ?? ""
        status = existing.status
        notes = existing.notes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmedName
            existing.dosageText = dosageText.isEmpty ? nil : dosageText
            existing.frequencyText = frequencyText.isEmpty ? nil : frequencyText
            existing.status = status
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let medication = Medication(
                name: trimmedName,
                dosageText: dosageText.isEmpty ? nil : dosageText,
                frequencyText: frequencyText.isEmpty ? nil : frequencyText,
                status: status,
                notes: notes.isEmpty ? nil : notes
            )
            medication.profile = profile
            context.insert(medication)
        }
        dismiss()
    }
}

import SwiftUI
import SwiftData

struct ConditionListView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile
    @State private var showingAdd = false
    @State private var editing: Condition?

    private var items: [Condition] {
        profile.conditions.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No conditions",
                    systemImage: "stethoscope",
                    description: Text("Add diagnoses and ongoing health conditions.")
                )
            } else {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundStyle(.primary)
                            HStack {
                                Text(item.clinicalStatus.capitalized)
                                if let onset = item.onsetDate {
                                    Text("· since \(onset.formatted(date: .abbreviated, time: .omitted))")
                                }
                            }
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
        .navigationTitle("Conditions")
        .toolbar {
            Button("Add", systemImage: "plus") { showingAdd = true }
        }
        .sheet(isPresented: $showingAdd) {
            ConditionFormView(profile: profile)
        }
        .sheet(item: $editing) { item in
            ConditionFormView(profile: profile, existing: item)
        }
    }
}

struct ConditionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    var existing: Condition?

    @State private var name = ""
    @State private var clinicalStatus = "active"
    @State private var hasOnsetDate = false
    @State private var onsetDate = Date()
    @State private var notes = ""

    private let statusOptions = ["active", "inactive", "resolved"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Condition name", text: $name)
                Picker("Status", selection: $clinicalStatus) {
                    ForEach(statusOptions, id: \.self) { Text($0.capitalized) }
                }
                Toggle("Onset date", isOn: $hasOnsetDate.animation())
                if hasOnsetDate {
                    DatePicker("Since", selection: $onsetDate, in: ...Date(), displayedComponents: .date)
                }
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle(existing == nil ? "Add condition" : "Edit condition")
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
        clinicalStatus = existing.clinicalStatus
        hasOnsetDate = existing.onsetDate != nil
        onsetDate = existing.onsetDate ?? Date()
        notes = existing.notes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmedName
            existing.clinicalStatus = clinicalStatus
            existing.onsetDate = hasOnsetDate ? onsetDate : nil
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let condition = Condition(
                name: trimmedName,
                clinicalStatus: clinicalStatus,
                onsetDate: hasOnsetDate ? onsetDate : nil,
                notes: notes.isEmpty ? nil : notes
            )
            condition.profile = profile
            context.insert(condition)
        }
        dismiss()
    }
}

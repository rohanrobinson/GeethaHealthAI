import SwiftUI
import SwiftData

struct AllergyListView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile
    @State private var showingAdd = false
    @State private var editing: Allergy?

    private var items: [Allergy] {
        profile.allergies.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No allergies",
                    systemImage: "allergens",
                    description: Text("Add allergies and intolerances so providers see them at a glance.")
                )
            } else {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .foregroundStyle(.primary)
                            if let subtitle = subtitle(for: item) {
                                Text(subtitle)
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
        .navigationTitle("Allergies")
        .toolbar {
            Button("Add", systemImage: "plus") { showingAdd = true }
        }
        .sheet(isPresented: $showingAdd) {
            AllergyFormView(profile: profile)
        }
        .sheet(item: $editing) { item in
            AllergyFormView(profile: profile, existing: item)
        }
    }

    private func subtitle(for item: Allergy) -> String? {
        let parts = [item.criticality.map { "\($0.capitalized) risk" }, item.reaction]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct AllergyFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    var existing: Allergy?

    @State private var name = ""
    @State private var criticality = ""
    @State private var reaction = ""
    @State private var notes = ""

    private let criticalityOptions = ["", "low", "high"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Allergy (e.g. Penicillin)", text: $name)
                Picker("Risk", selection: $criticality) {
                    ForEach(criticalityOptions, id: \.self) {
                        Text($0.isEmpty ? "Not set" : $0.capitalized)
                    }
                }
                TextField("Reaction (e.g. hives)", text: $reaction)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle(existing == nil ? "Add allergy" : "Edit allergy")
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
        criticality = existing.criticality ?? ""
        reaction = existing.reaction ?? ""
        notes = existing.notes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmedName
            existing.criticality = criticality.isEmpty ? nil : criticality
            existing.reaction = reaction.isEmpty ? nil : reaction
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let allergy = Allergy(
                name: trimmedName,
                criticality: criticality.isEmpty ? nil : criticality,
                reaction: reaction.isEmpty ? nil : reaction,
                notes: notes.isEmpty ? nil : notes
            )
            allergy.profile = profile
            context.insert(allergy)
        }
        dismiss()
    }
}

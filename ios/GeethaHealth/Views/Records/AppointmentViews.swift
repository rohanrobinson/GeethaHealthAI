import SwiftUI
import SwiftData

struct AppointmentListView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile
    @State private var showingAdd = false
    @State private var editing: Appointment?

    private var items: [Appointment] {
        profile.appointments.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No appointments",
                    systemImage: "calendar",
                    description: Text("Track upcoming and past visits.")
                )
            } else {
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .foregroundStyle(.primary)
                            Text(item.startDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
        .navigationTitle("Appointments")
        .toolbar {
            Button("Add", systemImage: "plus") { showingAdd = true }
        }
        .sheet(isPresented: $showingAdd) {
            AppointmentFormView(profile: profile)
        }
        .sheet(item: $editing) { item in
            AppointmentFormView(profile: profile, existing: item)
        }
    }

    private func subtitle(for item: Appointment) -> String? {
        let parts = [item.clinician, item.location].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

struct AppointmentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var profile: Profile
    var existing: Appointment?

    @State private var title = ""
    @State private var startDate = Date()
    @State private var location = ""
    @State private var clinician = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title (e.g. Annual physical)", text: $title)
                DatePicker("When", selection: $startDate)
                TextField("Clinician", text: $clinician)
                TextField("Location", text: $location)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle(existing == nil ? "Add appointment" : "Edit appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let existing else { return }
        title = existing.title
        startDate = existing.startDate
        location = existing.location ?? ""
        clinician = existing.clinician ?? ""
        notes = existing.notes ?? ""
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.title = trimmedTitle
            existing.startDate = startDate
            existing.location = location.isEmpty ? nil : location
            existing.clinician = clinician.isEmpty ? nil : clinician
            existing.notes = notes.isEmpty ? nil : notes
        } else {
            let appointment = Appointment(
                title: trimmedTitle,
                startDate: startDate,
                location: location.isEmpty ? nil : location,
                clinician: clinician.isEmpty ? nil : clinician,
                notes: notes.isEmpty ? nil : notes
            )
            appointment.profile = profile
            context.insert(appointment)
        }
        dismiss()
    }
}

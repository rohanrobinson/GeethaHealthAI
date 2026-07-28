import SwiftUI
import SwiftData

struct RecordsHomeView: View {
    var profile: Profile
    @Environment(\.modelContext) private var context
    @State private var sharedExport: SharedFile?
    @State private var showingHealthImport = false
    @State private var showingVoiceEntry = false
    @State private var undoRecord: SymptomObservation?
    @State private var undoTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(profile.displayName)
                                .font(.headline)
                            if let age = profile.age {
                                Text("\(age) years old")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Health records") {
                    recordLink("Symptoms", icon: "waveform.path.ecg", count: profile.symptoms.count) {
                        SymptomListView(profile: profile)
                    }
                    recordLink("Conditions", icon: "stethoscope", count: profile.conditions.count) {
                        ConditionListView(profile: profile)
                    }
                    recordLink("Medications", icon: "pills", count: profile.medications.count) {
                        MedicationListView(profile: profile)
                    }
                    recordLink("Allergies", icon: "allergens", count: profile.allergies.count) {
                        AllergyListView(profile: profile)
                    }
                    recordLink("Immunizations", icon: "syringe", count: profile.immunizations.count) {
                        ImmunizationListView(profile: profile)
                    }
                    recordLink("Appointments", icon: "calendar", count: profile.appointments.count) {
                        AppointmentListView(profile: profile)
                    }
                }

                Section {
                    Button {
                        showingVoiceEntry = true
                    } label: {
                        Label("Add by voice", systemImage: "mic.fill")
                    }
                } footer: {
                    Text("Speak a symptom and we'll turn it into a record — reviewed by you before it's saved.")
                }

                Section {
                    Button {
                        showingHealthImport = true
                    } label: {
                        Label("Import from Apple Health", systemImage: "heart.text.square")
                    }
                } footer: {
                    Text("Pull your clinical records from providers connected to the Health app. Imported records stay on this device.")
                }
            }
            .navigationTitle("Records")
            .toolbar {
                Menu {
                    Button {
                        if let url = PDFExporter.makeSummaryPDF(for: profile) {
                            sharedExport = SharedFile(url: url)
                        }
                    } label: {
                        Label("Share as PDF summary", systemImage: "doc.richtext")
                    }
                    Button {
                        if let url = FHIRExporter.makeBundle(for: profile) {
                            sharedExport = SharedFile(url: url)
                        }
                    } label: {
                        Label("Share as FHIR bundle", systemImage: "curlybraces")
                    }
                } label: {
                    // Fixed sizes are intentional: this compact icon+caption
                    // must fit the round toolbar button at every text size;
                    // it doesn't scale with Dynamic Type, same as system
                    // toolbar buttons.
                    VStack(spacing: 1) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                        Text("Share")
                            .font(.system(size: 9))
                    }
                }
                .accessibilityLabel("Share summary")
            }
            .sheet(item: $sharedExport) { file in
                ShareSheet(url: file.url)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingHealthImport) {
                HealthRecordsImportView(profile: profile)
            }
            .sheet(isPresented: $showingVoiceEntry) {
                VoiceSymptomView(profile: profile) { saved in
                    presentUndo(for: saved)
                }
            }
            .overlay(alignment: .bottom) {
                if let record = undoRecord {
                    undoSnackbar(for: record)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Undo

    private func presentUndo(for record: SymptomObservation) {
        undoTask?.cancel()
        withAnimation { undoRecord = record }
        undoTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation { undoRecord = nil }
        }
    }

    private func undoSnackbar(for record: SymptomObservation) -> some View {
        HStack {
            Text("Saved \(record.name)")
                .foregroundStyle(.white)
            Spacer()
            Button("Undo") {
                undoTask?.cancel()
                context.delete(record)
                withAnimation { undoRecord = nil }
            }
            .fontWeight(.semibold)
            .tint(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.85), in: Capsule())
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func recordLink<Destination: View>(
        _ title: String,
        icon: String,
        count: Int,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

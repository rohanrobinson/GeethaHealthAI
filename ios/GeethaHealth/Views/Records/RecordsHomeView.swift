import SwiftUI
import SwiftData

struct RecordsHomeView: View {
    var profile: Profile

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
            }
            .navigationTitle("Records")
        }
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

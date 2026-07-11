import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var givenName = ""
    @State private var familyName = ""
    @State private var hasDateOfBirth = false
    @State private var dateOfBirth = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to Geetha Health")
                            .font(.title2.bold())
                        Text("Your personal medical record. Everything you add stays on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }

                Section("About you") {
                    TextField("First name", text: $givenName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $familyName)
                        .textContentType(.familyName)
                    Toggle("Add date of birth", isOn: $hasDateOfBirth.animation())
                    if hasDateOfBirth {
                        DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                    }
                }

                Section {
                    Button("Get started") {
                        createProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(givenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Set up")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func createProfile() {
        let profile = Profile(
            givenName: givenName.trimmingCharacters(in: .whitespaces),
            familyName: familyName.trimmingCharacters(in: .whitespaces),
            dateOfBirth: hasDateOfBirth ? dateOfBirth : nil
        )
        context.insert(profile)
    }
}

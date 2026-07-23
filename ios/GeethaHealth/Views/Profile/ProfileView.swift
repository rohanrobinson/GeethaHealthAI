import SwiftUI
import SwiftData

struct ProfileView: View {
    @Bindable var profile: Profile
    @State private var isEditing = false
    @State private var storageUsedText = "Calculating…"
    @AppStorage(AppLock.enabledKey) private var appLockEnabled = false
    @State private var isConfirmingFaceID = false
    @State private var faceIDError: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Basics") {
                    row("Name", profile.displayName)
                    row("Date of birth", profile.dateOfBirth.map { $0.formatted(date: .long, time: .omitted) })
                    row("Sex", profile.sex)
                    row("Blood type", profile.bloodType)
                }
                Section("Emergency contact") {
                    row("Name", profile.emergencyContactName)
                    row("Phone", profile.emergencyContactPhone)
                }
                Section {
                    Toggle("Require Face ID", isOn: faceIDBinding)
                } footer: {
                    if let faceIDError {
                        Text(faceIDError)
                    } else {
                        Text("When on, Geetha Health locks itself whenever you leave the app.")
                    }
                }
                Section {
                    LabeledContent("Data storage", value: "On this device only")
                    LabeledContent("Storage used", value: storageUsedText)
                } footer: {
                    Text("Geetha Health stores your records only on this device. Nothing is uploaded or shared unless you export it.")
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                Button("Edit") { isEditing = true }
            }
            .sheet(isPresented: $isEditing) {
                ProfileEditView(profile: profile)
            }
            .task {
                storageUsedText = StorageInfo.formatted()
            }
        }
    }

    private var faceIDBinding: Binding<Bool> {
        Binding(
            get: { appLockEnabled },
            set: { newValue in
                guard newValue else {
                    appLockEnabled = false
                    faceIDError = nil
                    return
                }
                Task {
                    let result = await AppLock.authenticate(reason: "Confirm to require Face ID for Geetha Health")
                    if result {
                        appLockEnabled = true
                        faceIDError = nil
                    } else {
                        faceIDError = "Couldn't confirm Face ID or your device passcode. Make sure one is set up in Settings, then try again."
                    }
                }
            }
        )
    }

    private func row(_ label: String, _ value: String?) -> some View {
        LabeledContent(label, value: value?.isEmpty == false ? value! : "Not set")
    }
}

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    var profile: Profile

    @State private var givenName = ""
    @State private var familyName = ""
    @State private var hasDateOfBirth = false
    @State private var dateOfBirth = Date()
    @State private var sex = ""
    @State private var bloodType = ""
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""

    private let sexOptions = ["", "Female", "Male", "Other"]
    private let bloodTypeOptions = ["", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("First name", text: $givenName)
                    TextField("Last name", text: $familyName)
                    Toggle("Date of birth", isOn: $hasDateOfBirth.animation())
                    if hasDateOfBirth {
                        DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                    }
                    Picker("Sex", selection: $sex) {
                        ForEach(sexOptions, id: \.self) { Text($0.isEmpty ? "Not set" : $0) }
                    }
                    Picker("Blood type", selection: $bloodType) {
                        ForEach(bloodTypeOptions, id: \.self) { Text($0.isEmpty ? "Not set" : $0) }
                    }
                }
                Section("Emergency contact") {
                    TextField("Name", text: $emergencyContactName)
                    TextField("Phone", text: $emergencyContactPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(givenName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        givenName = profile.givenName
        familyName = profile.familyName
        hasDateOfBirth = profile.dateOfBirth != nil
        dateOfBirth = profile.dateOfBirth ?? Date()
        sex = profile.sex ?? ""
        bloodType = profile.bloodType ?? ""
        emergencyContactName = profile.emergencyContactName ?? ""
        emergencyContactPhone = profile.emergencyContactPhone ?? ""
    }

    private func save() {
        profile.givenName = givenName.trimmingCharacters(in: .whitespaces)
        profile.familyName = familyName.trimmingCharacters(in: .whitespaces)
        profile.dateOfBirth = hasDateOfBirth ? dateOfBirth : nil
        profile.sex = sex.isEmpty ? nil : sex
        profile.bloodType = bloodType.isEmpty ? nil : bloodType
        profile.emergencyContactName = emergencyContactName.isEmpty ? nil : emergencyContactName
        profile.emergencyContactPhone = emergencyContactPhone.isEmpty ? nil : emergencyContactPhone
        dismiss()
    }
}

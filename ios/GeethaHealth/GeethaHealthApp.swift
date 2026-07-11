import SwiftUI
import SwiftData

@main
struct GeethaHealthApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Profile.self,
            Condition.self,
            Medication.self,
            Allergy.self,
            Immunization.self,
            Appointment.self,
            MedicalDocument.self,
        ])
    }
}

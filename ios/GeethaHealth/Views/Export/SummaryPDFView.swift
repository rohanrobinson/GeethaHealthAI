import SwiftUI

// Printable medical summary. Rendered off-screen by PDFExporter at US Letter
// width; not shown in the app UI.
struct SummaryPDFView: View {
    var profile: Profile
    var generatedAt = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            if !profile.allergies.isEmpty { allergiesSection }
            if !profile.conditions.isEmpty { conditionsSection }
            if !profile.medications.isEmpty { medicationsSection }
            if !profile.immunizations.isEmpty { immunizationsSection }
            if !profile.appointments.isEmpty { appointmentsSection }
            footer
        }
        .padding(36)
        .frame(width: 612, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Medical Summary")
                .font(.system(size: 22, weight: .bold))
            Text(profile.displayName)
                .font(.system(size: 17, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 2) {
                if let dob = profile.dateOfBirth {
                    GridRow {
                        detail("Date of birth", dob.formatted(date: .long, time: .omitted))
                        detail("Age", profile.age.map { "\($0)" } ?? "")
                    }
                }
                GridRow {
                    if let sex = profile.sex { detail("Sex", sex) }
                    if let bloodType = profile.bloodType { detail("Blood type", bloodType) }
                }
                if let contactName = profile.emergencyContactName {
                    GridRow {
                        detail("Emergency contact", contactName)
                        if let phone = profile.emergencyContactPhone { detail("Phone", phone) }
                    }
                }
            }
            .padding(.top, 2)
            Divider()
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):").font(.system(size: 11, weight: .semibold))
            Text(value).font(.system(size: 11))
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color(red: 0.2, green: 0.35, blue: 0.55))
    }

    private func itemName(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold))
    }

    private func itemDetail(_ text: String) -> some View {
        Text(text).font(.system(size: 11)).foregroundStyle(.secondary)
    }

    private var allergiesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Allergies")
            ForEach(profile.allergies.sorted { $0.name < $1.name }) { allergy in
                VStack(alignment: .leading, spacing: 1) {
                    itemName(allergy.name)
                    let parts = [
                        allergy.criticality.map { "\($0.capitalized) risk" },
                        allergy.reaction.map { "Reaction: \($0)" },
                        allergy.notes,
                    ].compactMap { $0 }
                    if !parts.isEmpty { itemDetail(parts.joined(separator: " · ")) }
                }
            }
        }
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Conditions")
            ForEach(profile.conditions.sorted { $0.name < $1.name }) { condition in
                VStack(alignment: .leading, spacing: 1) {
                    itemName(condition.name)
                    let parts = [
                        condition.clinicalStatus.capitalized,
                        condition.onsetDate.map { "since \($0.formatted(date: .abbreviated, time: .omitted))" },
                        condition.notes,
                    ].compactMap { $0 }
                    if !parts.isEmpty { itemDetail(parts.joined(separator: " · ")) }
                }
            }
        }
    }

    private var medicationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Medications")
            ForEach(profile.medications.sorted { $0.name < $1.name }) { medication in
                VStack(alignment: .leading, spacing: 1) {
                    itemName(medication.name)
                    let parts = [
                        medication.dosageText,
                        medication.frequencyText,
                        medication.status.capitalized,
                        medication.notes,
                    ].compactMap { $0 }
                    if !parts.isEmpty { itemDetail(parts.joined(separator: " · ")) }
                }
            }
        }
    }

    private var immunizationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Immunizations")
            ForEach(profile.immunizations.sorted { ($0.administeredDate ?? .distantPast) > ($1.administeredDate ?? .distantPast) }) { immunization in
                VStack(alignment: .leading, spacing: 1) {
                    itemName(immunization.name)
                    let parts = [
                        immunization.administeredDate.map { $0.formatted(date: .abbreviated, time: .omitted) },
                        immunization.notes,
                    ].compactMap { $0 }
                    if !parts.isEmpty { itemDetail(parts.joined(separator: " · ")) }
                }
            }
        }
    }

    private var appointmentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Appointments")
            ForEach(profile.appointments.sorted { $0.startDate > $1.startDate }) { appointment in
                VStack(alignment: .leading, spacing: 1) {
                    itemName(appointment.title)
                    let parts = [
                        appointment.startDate.formatted(date: .abbreviated, time: .shortened),
                        appointment.clinician,
                        appointment.location,
                        appointment.notes,
                    ].compactMap { $0 }
                    if !parts.isEmpty { itemDetail(parts.joined(separator: " · ")) }
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("Patient-entered data. This summary was created by the patient or their caregiver in Geetha Health and is not a clinical record from a healthcare provider. Not medical advice.")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text("Generated \(generatedAt.formatted(date: .long, time: .shortened))")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

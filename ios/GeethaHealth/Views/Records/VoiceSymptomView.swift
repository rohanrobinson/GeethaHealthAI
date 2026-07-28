import SwiftUI
import SwiftData

// Voice entry for a symptom. One global front door: speak a sentence, we
// transcribe on-device, parse it into a SymptomDraft, and let the user confirm
// on a card (or open the full form to edit) before it's saved the exact same
// way a typed symptom is. Saving hands the inserted record back so the caller
// can offer Undo.
struct VoiceSymptomView: View {
    var profile: Profile
    var onSaved: (SymptomObservation) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("voiceConsentAccepted") private var consentAccepted = false

    @State private var transcriber = SpeechTranscriber()
    @State private var phase: Phase = .listening
    @State private var draft = SymptomDraft()
    @State private var showingConsent = false
    @State private var showingEditForm = false
    @State private var authDenied = false

    private enum Phase { case listening, understanding, confirm }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Add by voice")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { transcriber.stop(); dismiss() }
                    }
                }
        }
        .onAppear {
            if consentAccepted { beginListening() } else { showingConsent = true }
        }
        .sheet(isPresented: $showingConsent) {
            VoiceConsentSheet {
                consentAccepted = true
                showingConsent = false
                beginListening()
            } onCancel: {
                dismiss()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showingEditForm, onDismiss: { dismiss() }) {
            // Full form seeded with the parsed draft; it inserts on Save via its
            // own path. Dismissing it closes the whole voice flow.
            SymptomFormView(profile: profile, prefill: draft)
        }
    }

    // MARK: - Phase content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .listening:      listeningView
        case .understanding:  understandingView
        case .confirm:        confirmView
        }
    }

    private var listeningView: some View {
        VStack(spacing: 24) {
            Spacer()
            if authDenied {
                unavailableView("Microphone or speech access is off. Turn it on in Settings to add records by voice.")
            } else if case .unavailable(let message) = transcriber.state {
                unavailableView(message)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: transcriber.isRecording)

                Text(transcriber.transcript.isEmpty
                     ? "Describe a symptom — e.g. “I've had a mild headache since Tuesday.”"
                     : transcriber.transcript)
                    .font(transcriber.transcript.isEmpty ? .body : .title3)
                    .foregroundStyle(transcriber.transcript.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .animation(.default, value: transcriber.transcript)
            }
            Spacer()

            if !authDenied, transcriber.isRecording || !transcriber.transcript.isEmpty {
                Button {
                    finishListening()
                } label: {
                    Label(transcriber.isRecording ? "Done" : "Continue", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .disabled(transcriber.transcript.isEmpty && !transcriber.isRecording)
            }
        }
        .padding(.bottom)
        .safeAreaInset(edge: .bottom) {
            Text("On-device only — your voice and records never leave this phone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var understandingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Understanding…")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var confirmView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let flag = SymptomInsights.redFlag(in: draft.notes ?? "") {
                    redFlagBanner(flag.message)
                }

                Text("Symptom")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.tint.opacity(0.12), in: Capsule())

                if draft.isResolved {
                    VStack(alignment: .leading, spacing: 12) {
                        confirmRow("Name", value: draft.name, code: draft.code)
                        if let severity = draft.severity { confirmRow("Severity", value: severity.capitalized) }
                        confirmRow("Status", value: draft.status.capitalized)
                        if let onset = draft.onsetDate {
                            confirmRow("Onset", value: onset.formatted(date: .abbreviated, time: .omitted))
                        }
                        if let site = draft.bodySite { confirmRow("Body site", value: site) }
                        if let notes = draft.notes, !notes.isEmpty { confirmRow("Notes", value: notes) }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 10) {
                        Button { saveDirect() } label: {
                            Text("Save").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button("Edit details") { showingEditForm = true }
                        Button("Re-record", role: .destructive) { beginListening() }
                    }
                } else {
                    // Couldn't identify a symptom — hand off to the full form
                    // with the transcript preserved in notes.
                    VStack(alignment: .leading, spacing: 12) {
                        Text("I couldn't identify a specific symptom.")
                            .font(.headline)
                        Text("Your recording is kept below — open the form to finish it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let notes = draft.notes, !notes.isEmpty {
                            Text("“\(notes)”").italic().foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(spacing: 10) {
                        Button { showingEditForm = true } label: {
                            Text("Fill in the form").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        Button("Re-record", role: .destructive) { beginListening() }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Rows / banners

    private func confirmRow(_ label: String, value: String, code: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(value)
                if let code {
                    Text("SNOMED \(code)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.tertiarySystemBackground), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func redFlagBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message).font(.subheadline)
        }
        .padding()
        .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func unavailableView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Voice unavailable", systemImage: "mic.slash")
        } description: {
            Text(message)
        }
    }

    // MARK: - Flow

    private func beginListening() {
        draft = SymptomDraft()
        phase = .listening
        Task {
            let granted = await transcriber.requestAuthorization()
            authDenied = !granted
            if granted { transcriber.start() }
        }
    }

    private func finishListening() {
        transcriber.stop()
        let transcript = transcriber.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return }
        phase = .understanding
        Task {
            let parser = makeSymptomParser()
            var parsed = await parser.parse(transcript)
            await SymptomCoding.resolve(&parsed)
            draft = parsed
            phase = .confirm
        }
    }

    private func saveDirect() {
        let symptom = SymptomObservation(
            name: draft.name,
            severity: draft.severity,
            bodySite: draft.bodySite,
            onsetDate: draft.onsetDate,
            status: draft.status,
            notes: draft.notes,
            code: draft.code,
            codeSystem: draft.codeSystem
        )
        symptom.profile = profile
        context.insert(symptom)
        onSaved(symptom)
        dismiss()
    }
}

// MARK: - Consent

private struct VoiceConsentSheet: View {
    let onAccept: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "mic.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Add records by voice")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 14) {
                point("lock.fill", "Private by design", "Your speech is transcribed and understood entirely on this device. Audio and records never leave your phone.")
                point("checkmark.circle", "You confirm everything", "Nothing is saved until you review the details. You can edit or discard before saving.")
                point("stethoscope", "Not medical advice", "Voice entry only records what you say — it doesn't diagnose. Consult a clinician for anything concerning.")
            }
            Spacer()
            Button(action: onAccept) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Button("Not now", action: onCancel)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .presentationDetents([.medium, .large])
    }

    private func point(_ icon: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(body).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

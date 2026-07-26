import SwiftUI
import SwiftData

struct ChatMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let text: String
}

// Holds the iOS 26-only assistant without forcing the whole view to be
// @available. Stored as AnyObject and cast back where iOS 26 is guaranteed.
@MainActor final class AssistantHolder {
    var value: AnyObject?
}

struct AskView: View {
    var profile: Profile

    @AppStorage("askConsentAccepted") private var consentAccepted = false
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isResponding = false
    @State private var showingConsent = false
    @State private var holder = AssistantHolder()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let notice = fallbackNotice {
                    Text(notice)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                }

                messageList

                inputBar
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Text("Informational only — not a diagnosis. For medical advice, consult a clinician. Everything here stays on your device.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 4)
            }
            .onAppear {
                if !consentAccepted { showingConsent = true }
            }
            .sheet(isPresented: $showingConsent) {
                ConsentSheet {
                    consentAccepted = true
                    showingConsent = false
                }
                .interactiveDismissDisabled()
            }
        }
    }

    // MARK: Subviews

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    }
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if isResponding {
                        ThinkingBubble()
                    }
                }
                .padding()
            }
            .onChange(of: messages) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("Ask about your symptoms")
                .font(.headline)
            Text("Try “How often have I logged headaches this month?” or “What could cause the dizziness I've been having?”")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 40)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Ask a question…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onSubmit(send)
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .disabled(trimmedInput.isEmpty || isResponding)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: Logic

    private var trimmedInput: String {
        input.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Non-nil when we're answering deterministically rather than with the model.
    private var fallbackNotice: String? {
        if #available(iOS 26.0, *) {
            if case .unavailable(let reason) = SymptomAssistant.availability {
                return "\(reason) Showing summaries from your logged symptoms instead."
            }
            return nil
        } else {
            return "On-device intelligence needs iOS 26 or later. Showing summaries from your logged symptoms instead."
        }
    }

    private func send() {
        let question = trimmedInput
        guard !question.isEmpty, !isResponding else { return }
        input = ""
        inputFocused = false
        messages.append(ChatMessage(role: .user, text: question))

        // Safety first: red-flag screening never depends on the model.
        if let flag = SymptomInsights.redFlag(in: question) {
            messages.append(ChatMessage(role: .assistant, text: flag.message))
            return
        }

        isResponding = true
        Task {
            let reply = await respond(to: question)
            isResponding = false
            messages.append(ChatMessage(role: .assistant, text: reply))
        }
    }

    private func respond(to question: String) async -> String {
        if #available(iOS 26.0, *), case .available = SymptomAssistant.availability {
            let assistant: SymptomAssistant
            if let existing = holder.value as? SymptomAssistant {
                assistant = existing
            } else {
                assistant = SymptomAssistant(profile: profile)
                holder.value = assistant
            }
            do {
                return try await assistant.answer(to: question)
            } catch {
                // Graceful degradation — fall back to deterministic answer.
                return SymptomInsights(profile: profile).answer(to: question)
            }
        }
        return SymptomInsights(profile: profile).answer(to: question)
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.role == .user ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }
}

private struct ThinkingBubble: View {
    var body: some View {
        HStack {
            ProgressView()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Consent

private struct ConsentSheet: View {
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.tint)
            Text("About the assistant")
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 14) {
                point("lock.fill", "Private by design", "Answers are generated on your device using Apple Intelligence. Your records never leave your phone.")
                point("stethoscope", "Not medical advice", "This assistant gives general information, not a diagnosis or treatment. Always consult a clinician for anything concerning.")
                point("phone.fill", "Emergencies", "If you think you're having an emergency, call your local emergency number right away — don't rely on this app.")
            }
            Spacer()
            Button(action: onAccept) {
                Text("I understand")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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

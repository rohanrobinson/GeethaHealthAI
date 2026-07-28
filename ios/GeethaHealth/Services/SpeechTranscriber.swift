import Foundation
import Speech
import AVFoundation

// On-device speech capture for voice record entry. Uses SFSpeechRecognizer with
// on-device recognition forced on — a medical app must never stream audio to a
// server — plus AVAudioEngine for the mic tap. Everything stays on the phone.
//
// Runs in one of two modes so the whole voice flow is testable in the Simulator
// (where live on-device recognition is unreliable): `.live` does real capture;
// `.mock` replays a scripted transcript on a timer with no audio engine. The
// mode is chosen once at the entry point via `VoiceEntryConfig`.
@MainActor
@Observable
final class SpeechTranscriber {

    enum Mode {
        case live
        case mock(script: String)
    }

    enum State: Equatable {
        case idle
        case recording
        case finished
        case unavailable(String)
    }

    private(set) var transcript = ""
    private(set) var state: State = .idle

    var isRecording: Bool { state == .recording }

    private let mode: Mode

    // Live-mode machinery (nil in mock mode).
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Mock-mode machinery.
    private var mockTimer: Timer?

    init(mode: Mode = VoiceEntryConfig.useMocks ? .mock(script: VoiceEntryConfig.mockTranscript) : .live) {
        self.mode = mode
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    /// True when this device can actually transcribe on-device. In mock mode
    /// always true; in live mode requires an available recognizer that supports
    /// on-device recognition (we never fall back to server recognition).
    var isSupported: Bool {
        if case .mock = mode { return true }
        guard let recognizer, recognizer.isAvailable else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    /// Requests mic + speech authorization. Returns true only if both granted.
    func requestAuthorization() async -> Bool {
        if case .mock = mode { return true }

        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Begins capturing. Safe to call only after `requestAuthorization()` succeeds.
    func start() {
        transcript = ""
        guard isSupported else {
            state = .unavailable("On-device speech recognition isn't available on this device.")
            return
        }

        switch mode {
        case .mock(let script):
            startMock(script: script)
        case .live:
            startLive()
        }
    }

    /// Stops capturing and settles on the final transcript.
    func stop() {
        switch mode {
        case .mock:
            mockTimer?.invalidate()
            mockTimer = nil
        case .live:
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            request?.endAudio()
            task?.finish()
            request = nil
            task = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        if state == .recording { state = .finished }
    }

    // MARK: - Live capture

    private func startLive() {
        guard let recognizer else {
            state = .unavailable("Speech recognition isn't available.")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.requiresOnDeviceRecognition = true  // never leave the device
            self.request = request

            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
                request?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            state = .recording

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        if result.isFinal { self.state = .finished }
                    }
                    if error != nil, self.state == .recording {
                        // Surface nothing loud — the user can retry; keep any
                        // partial transcript already captured.
                        self.stop()
                    }
                }
            }
        } catch {
            state = .unavailable("Couldn't start recording. Check microphone access in Settings.")
        }
    }

    // MARK: - Mock capture

    // Reveals the scripted transcript word by word so the confirm/parse flow can
    // be exercised end-to-end in the Simulator without live speech.
    private func startMock(script: String) {
        state = .recording
        let words = script.split(separator: " ").map(String.init)
        var index = 0
        mockTimer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                guard index < words.count else {
                    timer.invalidate()
                    return
                }
                self.transcript = words[0...index].joined(separator: " ")
                index += 1
            }
        }
    }
}

// Central switch for running the voice flow against mocks (Simulator / UI tests)
// instead of live speech + Foundation Models. Enabled with the `-uiMockVoice`
// launch argument.
enum VoiceEntryConfig {
    static var useMocks: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiMockVoice")
    }

    static var mockTranscript: String {
        "I've had a mild headache since Tuesday"
    }
}

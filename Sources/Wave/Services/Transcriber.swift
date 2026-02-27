import Foundation
import WhisperKit

// Notifications posted by the Transcriber for UI updates.
extension Notification.Name {
    static let transcriberStateChanged = Notification.Name("transcriberStateChanged")
}

// Wraps WhisperKit for local speech-to-text transcription.
// Handles model download, initialization, and transcription.
class Transcriber {

    private var whisperKit: WhisperKit?
    private(set) var currentModelName: String?

    enum State: Equatable {
        case idle
        case downloading(model: String)
        case ready(model: String)
        case failed(message: String)
    }

    private(set) var state: State = .idle {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .transcriberStateChanged, object: self)
            }
        }
    }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    /// The model name from settings (e.g. "base", "small", "medium").
    var modelName: String {
        UserDefaults.standard.string(forKey: "whisperModel") ?? "small"
    }

    /// The language code for transcription, or nil for auto-detection.
    var language: String? {
        let stored = UserDefaults.standard.string(forKey: "whisperLanguage") ?? "en"
        return stored == "auto" ? nil : stored
    }

    /// Initialize WhisperKit with the selected model.
    /// Downloads the model on first use — this can take a while.
    func prepare() async throws {
        let model = modelName
        state = .downloading(model: model)

        do {
            let config = WhisperKitConfig(
                model: "openai_whisper-\(model)",
                computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine),
                load: true
            )
            whisperKit = try await WhisperKit(config)
            currentModelName = model
            state = .ready(model: model)
            print("[Wave] model '\(model)' ready, tokenizer=\(whisperKit?.tokenizer != nil ? "set" : "nil")", to: &standardError)
        } catch {
            state = .failed(message: error.localizedDescription)
            print("[Wave] failed to prepare model '\(model)': \(error.localizedDescription)", to: &standardError)
            throw error
        }
    }

    /// Transcribe an array of 16kHz mono Float32 audio samples.
    func transcribe(audioSamples: [Float]) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriberError.notReady
        }

        let decodeOptions = DecodingOptions(
            language: language,
            detectLanguage: language == nil,
            wordTimestamps: false
        )

        let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: decodeOptions)

        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return stripTokensAndArtifacts(text)
    }

    // MARK: - Streaming transcription

    /// Update sent from the streaming transcription loop.
    struct StreamingUpdate {
        let confirmedText: String
        let unconfirmedText: String
        let bufferEnergy: [Float]
    }

    private var streamTranscriber: AudioStreamTranscriber?
    private var streamingTask: Task<Void, Never>?
    private var latestConfirmedText: String = ""
    private var latestUnconfirmedText: String = ""

    /// Start streaming transcription from the microphone.
    /// The callback fires on every state change with confirmed and unconfirmed text.
    func startStreaming(callback: @escaping (StreamingUpdate) -> Void) throws {
        guard let wk = whisperKit else {
            throw TranscriberError.notReady
        }
        guard let tokenizer = wk.tokenizer else {
            throw TranscriberError.notReady
        }

        let decodeOptions = DecodingOptions(
            language: language,
            detectLanguage: language == nil,
            wordTimestamps: false
        )

        latestConfirmedText = ""
        latestUnconfirmedText = ""

        let transcriber = AudioStreamTranscriber(
            audioEncoder: wk.audioEncoder,
            featureExtractor: wk.featureExtractor,
            segmentSeeker: wk.segmentSeeker,
            textDecoder: wk.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: wk.audioProcessor,
            decodingOptions: decodeOptions,
            stateChangeCallback: { [weak self] oldState, newState in
                guard let self = self else { return }
                let confirmed = newState.confirmedSegments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                let unconfirmed = newState.unconfirmedSegments.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                self.latestConfirmedText = confirmed
                self.latestUnconfirmedText = unconfirmed
                let update = StreamingUpdate(
                    confirmedText: confirmed,
                    unconfirmedText: unconfirmed,
                    bufferEnergy: newState.bufferEnergy
                )
                DispatchQueue.main.async {
                    callback(update)
                }
            }
        )
        streamTranscriber = transcriber

        // Launch in a detached task — startStreamTranscription() blocks until stopped
        streamingTask = Task.detached { [weak self] in
            do {
                try await transcriber.startStreamTranscription()
            } catch {
                print("[Wave] streaming error: \(error.localizedDescription)", to: &standardError)
            }
            // Clean up references when loop ends
            let weakSelf = self
            await MainActor.run {
                weakSelf?.streamTranscriber = nil
                weakSelf?.streamingTask = nil
            }
        }
    }

    /// Stop streaming transcription and return the final combined text.
    func stopStreaming() async -> String {
        guard let transcriber = streamTranscriber else { return "" }
        await transcriber.stopStreamTranscription()

        // Wait for the streaming task to finish
        await streamingTask?.value
        streamingTask = nil
        streamTranscriber = nil

        // Combine confirmed + unconfirmed as final text
        let finalText = [latestConfirmedText, latestUnconfirmedText]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        latestConfirmedText = ""
        latestUnconfirmedText = ""

        return stripTokensAndArtifacts(finalText)
    }

    /// Strip WhisperKit special tokens and common artifacts from transcription text.
    private func stripTokensAndArtifacts(_ text: String) -> String {
        var cleaned = text
        // Strip <|...|> special tokens
        cleaned = cleaned.replacingOccurrences(of: "<\\|[^|]+\\|>", with: "", options: .regularExpression)
        // Strip common artifacts
        let artifacts = ["[BLANK_AUDIO]", "[NO_SPEECH]", "(blank audio)", "(no speech)"]
        for artifact in artifacts {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "", options: .caseInsensitive)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum TranscriberError: Error, LocalizedError {
        case notReady

        var errorDescription: String? {
            switch self {
            case .notReady: return "Transcriber is not ready. Call prepare() first."
            }
        }
    }
}

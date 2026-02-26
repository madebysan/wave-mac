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

    /// The language code for transcription (e.g. "en", "es", "fr").
    var language: String {
        UserDefaults.standard.string(forKey: "whisperLanguage") ?? "en"
    }

    /// Initialize WhisperKit with the selected model.
    /// Downloads the model on first use — this can take a while.
    func prepare() async throws {
        let model = modelName
        state = .downloading(model: model)

        do {
            let config = WhisperKitConfig(
                model: "openai_whisper-\(model)",
                computeOptions: ModelComputeOptions(audioEncoderCompute: .cpuAndNeuralEngine, textDecoderCompute: .cpuAndNeuralEngine)
            )
            whisperKit = try await WhisperKit(config)
            currentModelName = model
            state = .ready(model: model)
            NSLog("Wave: Whisper model '\(model)' ready")
        } catch {
            state = .failed(message: error.localizedDescription)
            NSLog("Wave: Failed to prepare model '\(model)': \(error.localizedDescription)")
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
            wordTimestamps: false
        )

        let results = try await whisperKit.transcribe(audioArray: audioSamples, decodeOptions: decodeOptions)

        // Combine segment texts, filtering out WhisperKit artifacts
        let artifactPatterns = ["[BLANK_AUDIO]", "[NO_SPEECH]", "(blank audio)", "(no speech)"]
        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip artifacts
        var cleaned = text
        for artifact in artifactPatterns {
            cleaned = cleaned.replacingOccurrences(of: artifact, with: "", options: .caseInsensitive)
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
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

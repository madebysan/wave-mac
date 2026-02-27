import AVFoundation

// Records audio from the microphone using AVAudioEngine.
// Captures raw PCM samples and converts to 16kHz mono Float32 for WhisperKit.
// Auto-stops after 5 minutes of continuous silence to prevent runaway recordings.
class AudioRecorder {

    private let engine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private var isRecording = false

    // Silence detection: auto-stop after a configurable period of silence
    private var silenceTimer: Timer?
    private let silenceThreshold: Float = 0.01  // RMS below this = silence
    private var lastSpeechTime: Date = Date()

    /// Silence timeout in seconds. 0 means never auto-stop.
    /// Read from UserDefaults ("silenceTimeout"), defaults to 300 (5 minutes).
    private var silenceTimeout: TimeInterval {
        let stored = UserDefaults.standard.object(forKey: "silenceTimeout")
        return (stored as? TimeInterval) ?? 300
    }

    /// Called when silence auto-stop triggers. Set by AppDelegate.
    var onSilenceAutoStop: (() -> Void)?

    /// Start recording from the microphone.
    func startRecording() throws {
        guard !isRecording else { return }
        audioBuffer.removeAll()
        lastSpeechTime = Date()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target format: 16kHz mono Float32 (what WhisperKit expects)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.formatError
        }

        // Create a converter from device format to 16kHz mono
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw RecorderError.converterError
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Calculate output frame count based on sample rate ratio
            let ratio = targetFormat.sampleRate / inputFormat.sampleRate
            let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

            guard let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: outputFrameCount
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if status == .haveData, let channelData = outputBuffer.floatChannelData {
                let frameCount = Int(outputBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
                self.audioBuffer.append(contentsOf: samples)

                // Check if this chunk has speech (above silence threshold)
                let rms = self.computeRMS(samples)
                if rms > self.silenceThreshold {
                    self.lastSpeechTime = Date()
                }
            }
        }

        try engine.start()
        isRecording = true

        // Start silence monitoring timer (disabled when timeout is 0 / "Never")
        let timeout = silenceTimeout
        if timeout > 0 {
            silenceTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                guard let self = self, self.isRecording else { return }
                let silenceDuration = Date().timeIntervalSince(self.lastSpeechTime)
                if silenceDuration >= timeout {
                    let minutes = Int(timeout) / 60
                    NSLog("Wave: Auto-stopping after \(minutes) minute\(minutes == 1 ? "" : "s") of silence")
                    DispatchQueue.main.async {
                        self.onSilenceAutoStop?()
                    }
                }
            }
        }
    }

    /// Stop recording and return the captured audio samples.
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }
        silenceTimer?.invalidate()
        silenceTimer = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        return audioBuffer
    }

    /// Compute the RMS (root mean square) energy of audio samples.
    private func computeRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return sqrt(sumOfSquares / Float(samples.count))
    }

    enum RecorderError: Error, LocalizedError {
        case formatError
        case converterError

        var errorDescription: String? {
            switch self {
            case .formatError: return "Could not create target audio format"
            case .converterError: return "Could not create audio converter"
            }
        }
    }
}

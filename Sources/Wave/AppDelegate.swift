import Cocoa
import UniformTypeIdentifiers
import WhisperKit

var standardError = FileHandle.standardError

extension FileHandle: @retroactive TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}

// App lifecycle manager.
// Coordinates the Wave pipeline: hotkey → record → transcribe → filter → paste.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var onboardingController: OnboardingWindowController?
    private var hotkeyManager: HotkeyManager!
    let transcriber = Transcriber()
    private var isRecording = false

    // Audio file transcription result window
    private var resultController: TranscriptionResultWindowController?

    // Silence detection for streaming mode
    private var silenceTimer: Timer?
    private var lastSpeechTime: Date = Date()
    private let silenceEnergyThreshold: Float = 0.03

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the data directory if it doesn't exist
        FileLocations.ensureDirectoriesExist()

        // Set up the menu bar icon and dropdown
        statusBarController = StatusBarController()
        statusBarController.onStopRecording = { [weak self] in
            self?.stopAndTranscribe()
        }
        statusBarController.onStartDictation = { [weak self] in
            self?.toggleDictation()
        }

        // Set up the global hotkey (Option+Space by default)
        hotkeyManager = HotkeyManager()
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleDictation()
        }
        hotkeyManager.onPushStart = { [weak self] in
            self?.startRecording()
        }
        hotkeyManager.onPushStop = { [weak self] in
            guard let self = self, self.isRecording else { return }
            self.stopAndTranscribe()
        }

        // Wire up "Transcribe File..." menu item
        statusBarController.onTranscribeFile = { [weak self] in
            self?.transcribeFile()
        }

        // Update menu bar status when transcriber state changes
        NotificationCenter.default.addObserver(
            forName: .transcriberStateChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.statusBarController.rebuildMenu()
        }

        // Show onboarding on first launch
        if !OnboardingWindowController.isComplete {
            onboardingController = OnboardingWindowController()
            onboardingController?.show()
            // Model download is triggered from the onboarding window
        } else {
            // Returning user — download model in the background
            prepareTranscriber()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if isRecording {
            stopSilenceMonitor()
        }
    }

    // MARK: - Transcriber setup

    func prepareTranscriber() {
        Task {
            do {
                try await transcriber.prepare()
            } catch {
                // State is already set to .failed by the transcriber
            }
        }
    }

    // MARK: - Wave pipeline

    private func toggleDictation() {
        if isRecording {
            stopAndTranscribe()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Check microphone permission
        guard Permissions.hasMicrophoneAccess else {
            Permissions.requestMicrophone { [weak self] granted in
                if granted { self?.startRecording() }
            }
            return
        }

        guard transcriber.isReady else {
            showError("Model not ready", detail: "The Whisper model is still loading. Please wait a moment and try again.")
            prepareTranscriber()
            return
        }

        do {
            isRecording = true
            statusBarController.setState(.recording)
            if UserDefaults.standard.object(forKey: "playSoundFeedback") == nil || UserDefaults.standard.bool(forKey: "playSoundFeedback") {
                SoundFeedback.playStart()
            }

            // Start silence monitoring
            startSilenceMonitor()

            // Start streaming transcription
            print("[Wave] starting streaming...", to: &standardError)
            try transcriber.startStreaming { [weak self] update in
                guard let self = self else { return }
                if !update.confirmedText.isEmpty || !update.unconfirmedText.isEmpty {
                    print("[Wave] live: confirmed='\(update.confirmedText)' unconfirmed='\(update.unconfirmedText)'", to: &standardError)
                }
                // Check for speech activity via buffer energy
                let maxEnergy = update.bufferEnergy.max() ?? 0
                if maxEnergy > self.silenceEnergyThreshold {
                    self.lastSpeechTime = Date()
                }
            }
        } catch {
            isRecording = false
            statusBarController.setState(.idle)
            stopSilenceMonitor()
            print("[Wave] failed to start recording: \(error.localizedDescription)", to: &standardError)
            showError("Could not start recording", detail: error.localizedDescription)
        }
    }

    private func stopAndTranscribe() {
        guard isRecording else { return }
        if UserDefaults.standard.object(forKey: "playSoundFeedback") == nil || UserDefaults.standard.bool(forKey: "playSoundFeedback") {
            SoundFeedback.playStop()
        }
        isRecording = false
        stopSilenceMonitor()
        statusBarController.setState(.transcribing)

        Task {
            var text = await transcriber.stopStreaming()
            print("[Wave] stopStreaming returned: '\(text)'", to: &standardError)

            // Apply filler word removal if enabled
            text = FillerFilter.filter(text)

            let finalText = text

            await MainActor.run {
                guard !finalText.isEmpty else {
                    print("[Wave] final text empty, skipping paste", to: &standardError)
                    statusBarController.setState(.idle)
                    return
                }
                print("[Wave] pasting: '\(finalText)'", to: &standardError)

                // Save to history before injecting
                TranscriptionHistory.shared.add(finalText)

                // Inject text into the active app
                TextInjector.inject(finalText)
                statusBarController.setState(.idle)
            }
        }
    }

    // MARK: - Audio file transcription

    private func transcribeFile() {
        guard transcriber.isReady else {
            showError("Model not ready", detail: "The Whisper model is still downloading. Please wait and try again.")
            return
        }

        // Show open panel filtered to audio types
        let panel = NSOpenPanel()
        panel.title = "Select an audio file to transcribe"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        var allowedTypes: [UTType] = [.audio, .mp3, .wav, .aiff]
        if let ogg = UTType("org.xiph.ogg") { allowedTypes.append(ogg) }
        if let flac = UTType("org.xiph.flac") { allowedTypes.append(flac) }
        panel.allowedContentTypes = allowedTypes

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let fileName = url.lastPathComponent
        statusBarController.setState(.transcribing)

        Task {
            do {
                // Load audio file using WhisperKit's AudioProcessor
                let audioSamples = try AudioProcessor.loadAudioAsFloatArray(fromPath: url.path)

                guard !audioSamples.isEmpty else {
                    await MainActor.run {
                        statusBarController.setState(.idle)
                        showError("Empty audio", detail: "The selected file contains no audio data.")
                    }
                    return
                }

                // Transcribe using existing batch method
                var text = try await transcriber.transcribe(audioSamples: audioSamples)

                // Apply filler word removal
                text = FillerFilter.filter(text)

                let finalText = text

                await MainActor.run {
                    statusBarController.setState(.idle)

                    guard !finalText.isEmpty else {
                        showError("No speech detected", detail: "Could not detect any speech in the audio file.")
                        return
                    }

                    // Save to history
                    TranscriptionHistory.shared.add(finalText)

                    // Show result window
                    if resultController == nil {
                        resultController = TranscriptionResultWindowController()
                        resultController?.onPaste = { text in
                            TextInjector.inject(text)
                        }
                    }
                    resultController?.show(text: finalText, fileName: fileName)
                }
            } catch {
                print("[Wave] file transcription failed: \(error.localizedDescription)", to: &standardError)
                await MainActor.run {
                    statusBarController.setState(.idle)
                    showError("Transcription failed", detail: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Silence detection

    private func startSilenceMonitor() {
        lastSpeechTime = Date()
        let timeout = silenceTimeout
        guard timeout > 0 else { return }

        silenceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else { return }
            let silenceDuration = Date().timeIntervalSince(self.lastSpeechTime)
            if silenceDuration >= timeout {
                let minutes = Int(timeout) / 60
                print("[Wave] auto-stopping after \(minutes) minute\(minutes == 1 ? "" : "s") of silence", to: &standardError)
                self.stopAndTranscribe()
            }
        }
    }

    private func stopSilenceMonitor() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    /// Silence timeout in seconds. 0 means never auto-stop.
    private var silenceTimeout: TimeInterval {
        let stored = UserDefaults.standard.object(forKey: "silenceTimeout")
        return (stored as? TimeInterval) ?? 300
    }

    // MARK: - Error display

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

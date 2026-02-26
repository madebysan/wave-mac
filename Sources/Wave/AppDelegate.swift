import Cocoa

// App lifecycle manager.
// Coordinates the Wave pipeline: hotkey → record → transcribe → filter → paste.
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController!
    private var onboardingController: OnboardingWindowController?
    private var hotkeyManager: HotkeyManager!
    private let audioRecorder = AudioRecorder()
    let transcriber = Transcriber()
    private var isRecording = false

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

        // Auto-stop recording after 5 minutes of silence
        audioRecorder.onSilenceAutoStop = { [weak self] in
            self?.stopAndTranscribe()
        }

        // Set up the global hotkey (Option+Space by default)
        hotkeyManager = HotkeyManager()
        hotkeyManager.onToggle = { [weak self] in
            self?.toggleDictation()
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
            _ = audioRecorder.stopRecording()
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

        do {
            try audioRecorder.startRecording()
            isRecording = true
            statusBarController.setState(.recording)
            SoundFeedback.playStart()
        } catch {
            NSLog("Wave: Failed to start recording: \(error.localizedDescription)")
            showError("Could not start recording", detail: error.localizedDescription)
        }
    }

    private func stopAndTranscribe() {
        SoundFeedback.playStop()
        let samples = audioRecorder.stopRecording()
        isRecording = false
        statusBarController.setState(.transcribing)

        guard !samples.isEmpty else {
            statusBarController.setState(.idle)
            return
        }

        guard transcriber.isReady else {
            statusBarController.setState(.idle)
            showError("Model not ready", detail: "The Whisper model is still downloading. Please wait and try again.")
            return
        }

        Task {
            do {
                var text = try await transcriber.transcribe(audioSamples: samples)

                // Apply filler word removal if enabled
                text = FillerFilter.filter(text)

                let finalText = text
                guard !finalText.isEmpty else {
                    await MainActor.run { statusBarController.setState(.idle) }
                    return
                }

                // Save to history before injecting
                TranscriptionHistory.shared.add(finalText)

                // Inject text into the active app
                await MainActor.run {
                    TextInjector.inject(finalText)
                    statusBarController.setState(.idle)
                }
            } catch {
                NSLog("Wave: Transcription failed: \(error.localizedDescription)")
                await MainActor.run {
                    statusBarController.setState(.idle)
                    showError("Transcription failed", detail: error.localizedDescription)
                }
            }
        }
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

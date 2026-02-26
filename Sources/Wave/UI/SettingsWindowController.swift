import Cocoa
import KeyboardShortcuts
import ServiceManagement

// Settings window with hotkey config, language picker, model picker, and toggles.
class SettingsWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var modelStatusLabel: NSTextField?
    private var modelSpinner: NSProgressIndicator?
    private var stateObserver: Any?

    // Whisper-supported languages (most common ones)
    private let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("uk", "Ukrainian"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ko", "Korean"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("tr", "Turkish"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("no", "Norwegian"),
        ("fi", "Finnish"),
        ("ca", "Catalan"),
        ("he", "Hebrew"),
        ("id", "Indonesian"),
        ("ms", "Malay"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
    ]

    func show() {
        NSApp.setActivationPolicy(.accessory)

        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 420, height: 560)),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "Wave Settings"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        // Use a scroll view so the window doesn't need to be huge
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        w.contentView = scrollView

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = outer

        let pad: CGFloat = 24
        var y: CGFloat = pad

        // ── Keyboard Shortcut ──

        let shortcutLabel = Styles.label("Keyboard Shortcut", font: Styles.headlineFont)
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(shortcutLabel)
        NSLayoutConstraint.activate([
            shortcutLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            shortcutLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 24

        let shortcutDetail = Styles.label(
            "Press the shortcut to start dictation, press again to stop and transcribe.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        shortcutDetail.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(shortcutDetail)
        NSLayoutConstraint.activate([
            shortcutDetail.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            shortcutDetail.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            shortcutDetail.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 24

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleDictation)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(recorder)
        NSLayoutConstraint.activate([
            recorder.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            recorder.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 44

        // ── Post-processing ──

        let fillerLabel = Styles.label("Post-processing", font: Styles.headlineFont)
        fillerLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(fillerLabel)
        NSLayoutConstraint.activate([
            fillerLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            fillerLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 28

        let fillerToggle = NSButton(checkboxWithTitle: "Remove filler words (um, uh, er, hmm)", target: self, action: #selector(toggleFiller(_:)))
        fillerToggle.state = UserDefaults.standard.object(forKey: "removeFillers") == nil ? .on : (UserDefaults.standard.bool(forKey: "removeFillers") ? .on : .off)
        fillerToggle.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(fillerToggle)
        NSLayoutConstraint.activate([
            fillerToggle.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            fillerToggle.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 24

        let clipboardToggle = NSButton(checkboxWithTitle: "Keep transcribed text on clipboard", target: self, action: #selector(toggleClipboard(_:)))
        clipboardToggle.state = UserDefaults.standard.bool(forKey: "keepOnClipboard") ? .on : .off
        clipboardToggle.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(clipboardToggle)
        NSLayoutConstraint.activate([
            clipboardToggle.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            clipboardToggle.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 36

        // ── Language ──

        let langLabel = Styles.label("Language", font: Styles.headlineFont)
        langLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(langLabel)
        NSLayoutConstraint.activate([
            langLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            langLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 28

        let langPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        for lang in languages {
            langPicker.addItem(withTitle: lang.name)
            langPicker.lastItem?.representedObject = lang.code
        }
        let savedLang = UserDefaults.standard.string(forKey: "whisperLanguage") ?? "en"
        if let match = languages.firstIndex(where: { $0.code == savedLang }) {
            langPicker.selectItem(at: match)
        }
        langPicker.target = self
        langPicker.action = #selector(languageChanged(_:))
        langPicker.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(langPicker)
        NSLayoutConstraint.activate([
            langPicker.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            langPicker.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            langPicker.widthAnchor.constraint(equalToConstant: 180),
        ])
        y += 28

        let langNote = Styles.label(
            "Setting a language explicitly improves accuracy. Whisper supports 90+ languages.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        langNote.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(langNote)
        NSLayoutConstraint.activate([
            langNote.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            langNote.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            langNote.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 36

        // ── Whisper Model ──

        let modelLabel = Styles.label("Whisper Model", font: Styles.headlineFont)
        modelLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(modelLabel)
        NSLayoutConstraint.activate([
            modelLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            modelLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 28

        let modelPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        modelPicker.addItems(withTitles: ["base", "small", "medium"])
        let savedModel = UserDefaults.standard.string(forKey: "whisperModel") ?? "small"
        modelPicker.selectItem(withTitle: savedModel)
        modelPicker.target = self
        modelPicker.action = #selector(modelChanged(_:))
        modelPicker.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(modelPicker)

        // Spinner for download progress
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        outer.addSubview(spinner)
        modelSpinner = spinner

        NSLayoutConstraint.activate([
            modelPicker.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            modelPicker.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            modelPicker.widthAnchor.constraint(equalToConstant: 140),

            spinner.centerYAnchor.constraint(equalTo: modelPicker.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: modelPicker.trailingAnchor, constant: 8),
        ])
        y += 28

        // Model status label (shows "Downloaded", "Downloading...", etc.)
        let statusLabel = Styles.label("", font: Styles.captionFont, color: .systemGreen)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(statusLabel)
        modelStatusLabel = statusLabel
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            statusLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            statusLabel.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 20

        let modelNote = Styles.label(
            "Larger models are more accurate but use more memory and are slower. The \"small\" model is recommended.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        modelNote.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(modelNote)
        NSLayoutConstraint.activate([
            modelNote.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            modelNote.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            modelNote.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 36

        // Observe transcriber state changes to update the status label
        stateObserver = NotificationCenter.default.addObserver(
            forName: .transcriberStateChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateModelStatus()
        }
        updateModelStatus()

        // ── General ──

        let generalLabel = Styles.label("General", font: Styles.headlineFont)
        generalLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(generalLabel)
        NSLayoutConstraint.activate([
            generalLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            generalLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 28

        let historyToggle = NSButton(checkboxWithTitle: "Save transcription history", target: self, action: #selector(toggleHistory(_:)))
        historyToggle.state = TranscriptionHistory.isEnabled ? .on : .off
        historyToggle.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(historyToggle)
        NSLayoutConstraint.activate([
            historyToggle.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            historyToggle.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 20

        let historyNote = Styles.label(
            "Only transcribed text is saved. Audio recordings are never stored.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        historyNote.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(historyNote)
        NSLayoutConstraint.activate([
            historyNote.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            historyNote.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            historyNote.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 24

        let loginToggle = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        loginToggle.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        loginToggle.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(loginToggle)
        NSLayoutConstraint.activate([
            loginToggle.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            loginToggle.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += pad

        // Set the document view size so scrolling works
        outer.frame = NSRect(x: 0, y: 0, width: 420, height: y)

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc private func toggleFiller(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "removeFillers")
    }

    @objc private func toggleClipboard(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "keepOnClipboard")
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        if let code = sender.selectedItem?.representedObject as? String {
            UserDefaults.standard.set(code, forKey: "whisperLanguage")
        }
    }

    @objc private func modelChanged(_ sender: NSPopUpButton) {
        if let title = sender.selectedItem?.title {
            UserDefaults.standard.set(title, forKey: "whisperModel")
            // Trigger model re-download
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.prepareTranscriber()
            }
        }
    }

    private func updateModelStatus() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        switch appDelegate.transcriber.state {
        case .idle:
            modelStatusLabel?.stringValue = ""
            modelSpinner?.isHidden = true
            modelSpinner?.stopAnimation(nil)
        case .downloading(let model):
            modelStatusLabel?.stringValue = "Downloading \(model) model..."
            modelStatusLabel?.textColor = .systemOrange
            modelSpinner?.isHidden = false
            modelSpinner?.startAnimation(nil)
        case .ready(let model):
            modelStatusLabel?.stringValue = "\(model) model ready"
            modelStatusLabel?.textColor = .systemGreen
            modelSpinner?.isHidden = true
            modelSpinner?.stopAnimation(nil)
        case .failed(let message):
            modelStatusLabel?.stringValue = "Failed: \(message)"
            modelStatusLabel?.textColor = .systemRed
            modelSpinner?.isHidden = true
            modelSpinner?.stopAnimation(nil)
        }
    }

    @objc private func toggleHistory(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "saveHistory")
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enable = sender.state == .on
        UserDefaults.standard.set(enable, forKey: "launchAtLogin")
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Wave: Failed to update login item: \(error.localizedDescription)")
        }
    }

    func windowWillClose(_ notification: Notification) {
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
            stateObserver = nil
        }
        NSApp.setActivationPolicy(.accessory)
    }
}

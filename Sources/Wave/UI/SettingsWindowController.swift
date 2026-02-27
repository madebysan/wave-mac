import Cocoa
import KeyboardShortcuts
import ServiceManagement

// Settings window with hotkey config, language picker, model picker, and toggles.
class SettingsWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var modelStatusLabel: NSTextField?
    private var modelSpinner: NSProgressIndicator?
    private var stateObserver: Any?

    // Popular languages shown at top of the picker
    private let popularLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("ru", "Russian"),
    ]

    // All Whisper-supported languages (99 total)
    private let allLanguages: [(code: String, name: String)] = [
        ("af", "Afrikaans"),
        ("am", "Amharic"),
        ("ar", "Arabic"),
        ("as", "Assamese"),
        ("az", "Azerbaijani"),
        ("ba", "Bashkir"),
        ("be", "Belarusian"),
        ("bg", "Bulgarian"),
        ("bn", "Bengali"),
        ("bo", "Tibetan"),
        ("br", "Breton"),
        ("bs", "Bosnian"),
        ("ca", "Catalan"),
        ("cs", "Czech"),
        ("cy", "Welsh"),
        ("da", "Danish"),
        ("de", "German"),
        ("el", "Greek"),
        ("en", "English"),
        ("es", "Spanish"),
        ("et", "Estonian"),
        ("eu", "Basque"),
        ("fa", "Persian"),
        ("fi", "Finnish"),
        ("fo", "Faroese"),
        ("fr", "French"),
        ("gl", "Galician"),
        ("gu", "Gujarati"),
        ("ha", "Hausa"),
        ("haw", "Hawaiian"),
        ("he", "Hebrew"),
        ("hi", "Hindi"),
        ("hr", "Croatian"),
        ("ht", "Haitian Creole"),
        ("hu", "Hungarian"),
        ("hy", "Armenian"),
        ("id", "Indonesian"),
        ("is", "Icelandic"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("jw", "Javanese"),
        ("ka", "Georgian"),
        ("kk", "Kazakh"),
        ("km", "Khmer"),
        ("kn", "Kannada"),
        ("ko", "Korean"),
        ("la", "Latin"),
        ("lb", "Luxembourgish"),
        ("ln", "Lingala"),
        ("lo", "Lao"),
        ("lt", "Lithuanian"),
        ("lv", "Latvian"),
        ("mg", "Malagasy"),
        ("mi", "Maori"),
        ("mk", "Macedonian"),
        ("ml", "Malayalam"),
        ("mn", "Mongolian"),
        ("mr", "Marathi"),
        ("ms", "Malay"),
        ("mt", "Maltese"),
        ("my", "Myanmar"),
        ("ne", "Nepali"),
        ("nl", "Dutch"),
        ("nn", "Nynorsk"),
        ("no", "Norwegian"),
        ("oc", "Occitan"),
        ("pa", "Punjabi"),
        ("pl", "Polish"),
        ("ps", "Pashto"),
        ("pt", "Portuguese"),
        ("ro", "Romanian"),
        ("ru", "Russian"),
        ("sa", "Sanskrit"),
        ("sd", "Sindhi"),
        ("si", "Sinhala"),
        ("sk", "Slovak"),
        ("sl", "Slovenian"),
        ("sn", "Shona"),
        ("so", "Somali"),
        ("sq", "Albanian"),
        ("sr", "Serbian"),
        ("su", "Sundanese"),
        ("sv", "Swedish"),
        ("sw", "Swahili"),
        ("ta", "Tamil"),
        ("te", "Telugu"),
        ("tg", "Tajik"),
        ("th", "Thai"),
        ("tk", "Turkmen"),
        ("tl", "Tagalog"),
        ("tr", "Turkish"),
        ("tt", "Tatar"),
        ("uk", "Ukrainian"),
        ("ur", "Urdu"),
        ("uz", "Uzbek"),
        ("vi", "Vietnamese"),
        ("yi", "Yiddish"),
        ("yo", "Yoruba"),
        ("yue", "Cantonese"),
        ("zh", "Chinese"),
    ]

    func show() {
        NSApp.setActivationPolicy(.accessory)

        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 420, height: 650)),
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

        // ── Recording ──

        let recordingLabel = Styles.label("Recording", font: Styles.headlineFont)
        recordingLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(recordingLabel)
        NSLayoutConstraint.activate([
            recordingLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            recordingLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
        ])
        y += 28

        let silenceLabel = Styles.label("Auto-stop after silence:", font: Styles.bodyFont)
        silenceLabel.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(silenceLabel)

        let silenceOptions: [(title: String, seconds: TimeInterval)] = [
            ("30 seconds", 30),
            ("1 minute", 60),
            ("2 minutes", 120),
            ("5 minutes", 300),
            ("10 minutes", 600),
            ("Never", 0),
        ]

        let silencePicker = NSPopUpButton(frame: .zero, pullsDown: false)
        for opt in silenceOptions {
            silencePicker.addItem(withTitle: opt.title)
            silencePicker.lastItem?.representedObject = opt.seconds as NSNumber
        }
        let savedTimeout = UserDefaults.standard.object(forKey: "silenceTimeout") as? TimeInterval ?? 300
        if let match = silenceOptions.firstIndex(where: { $0.seconds == savedTimeout }) {
            silencePicker.selectItem(at: match)
        }
        silencePicker.target = self
        silencePicker.action = #selector(silenceTimeoutChanged(_:))
        silencePicker.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(silencePicker)

        NSLayoutConstraint.activate([
            silenceLabel.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            silenceLabel.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),

            silencePicker.centerYAnchor.constraint(equalTo: silenceLabel.centerYAnchor),
            silencePicker.leadingAnchor.constraint(equalTo: silenceLabel.trailingAnchor, constant: 8),
        ])
        y += 28

        let silenceNote = Styles.label(
            "Recording auto-stops after this duration of silence. \"Never\" disables auto-stop.",
            font: Styles.captionFont, color: Styles.tertiaryLabel
        )
        silenceNote.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(silenceNote)
        NSLayoutConstraint.activate([
            silenceNote.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            silenceNote.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            silenceNote.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
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

        // Popular languages first
        for lang in popularLanguages {
            langPicker.addItem(withTitle: lang.name)
            langPicker.lastItem?.representedObject = lang.code
        }

        // Separator then all languages
        langPicker.menu?.addItem(.separator())
        for lang in allLanguages {
            // Skip if already in popular list to avoid duplicates
            if popularLanguages.contains(where: { $0.code == lang.code }) { continue }
            langPicker.addItem(withTitle: lang.name)
            langPicker.lastItem?.representedObject = lang.code
        }

        let savedLang = UserDefaults.standard.string(forKey: "whisperLanguage") ?? "en"
        // Find and select the saved language
        for i in 0..<langPicker.numberOfItems {
            if let code = langPicker.item(at: i)?.representedObject as? String, code == savedLang {
                langPicker.selectItem(at: i)
                break
            }
        }
        langPicker.target = self
        langPicker.action = #selector(languageChanged(_:))
        langPicker.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(langPicker)
        NSLayoutConstraint.activate([
            langPicker.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            langPicker.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            langPicker.widthAnchor.constraint(equalToConstant: 200),
        ])
        y += 28

        let langNote = Styles.label(
            "Popular languages are listed first. All 99 Whisper-supported languages are available below the separator.",
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
        modelPicker.addItems(withTitles: ["base", "small", "medium", "large"])
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
            "Larger models are more accurate but use more memory and are slower. The \"small\" model is recommended for most users.",
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

    @objc private func silenceTimeoutChanged(_ sender: NSPopUpButton) {
        if let seconds = sender.selectedItem?.representedObject as? NSNumber {
            UserDefaults.standard.set(seconds.doubleValue, forKey: "silenceTimeout")
        }
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

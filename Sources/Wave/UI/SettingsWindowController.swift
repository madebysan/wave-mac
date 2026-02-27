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

        let winWidth: CGFloat = 440
        let winHeight: CGFloat = 700
        let pad: CGFloat = 24
        let cardWidth = winWidth - pad * 2
        let rowH = Styles.cardRowHeight
        let hPad = Styles.cardHPadding

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: winWidth, height: winHeight)),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "Wave Settings"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        w.contentView = scrollView

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = outer

        var y: CGFloat = pad

        // ── Helper: place a view at the current y, advance y ──

        func place(_ view: NSView, height: CGFloat, leading: CGFloat = pad) {
            view.translatesAutoresizingMaskIntoConstraints = false
            outer.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
                view.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: leading),
            ])
            y += height
        }

        func placeFullWidth(_ view: NSView, height: CGFloat, leading: CGFloat = pad) {
            view.translatesAutoresizingMaskIntoConstraints = false
            outer.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
                view.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: leading),
                view.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
            ])
            y += height
        }

        /// Build a card from an array of row views, inserting dividers between them.
        func buildCard(rows: [NSView]) -> NSView {
            let card = Styles.makeCard(width: cardWidth)
            var cardY: CGFloat = 0
            for (i, row) in rows.enumerated() {
                row.frame.origin = NSPoint(x: 0, y: cardY)
                card.addSubview(row)
                cardY += row.frame.height
                if i < rows.count - 1 {
                    let div = Styles.makeDivider(width: cardWidth)
                    div.frame.origin = NSPoint(x: 0, y: cardY)
                    card.addSubview(div)
                    cardY += 1
                }
            }
            card.frame.size.height = cardY
            return card
        }

        // ── Keyboard Shortcut ──

        let shortcutTitle = Styles.sectionTitle("Keyboard Shortcut")
        place(shortcutTitle, height: 16 + Styles.titleToCardGap)

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleDictation)
        let shortcutRow = Styles.makeRow(label: "Shortcut", control: recorder, width: cardWidth)
        let shortcutCard = buildCard(rows: [shortcutRow])
        place(shortcutCard, height: shortcutCard.frame.height)
        y += Styles.sectionGap

        // ── Recording ──

        let recordingTitle = Styles.sectionTitle("Recording")
        place(recordingTitle, height: 16 + Styles.titleToCardGap)

        // Mode row
        let modeControl = NSSegmentedControl(labels: ["Toggle", "Push-to-talk"], trackingMode: .selectOne, target: self, action: #selector(recordingModeChanged(_:)))
        modeControl.selectedSegment = RecordingMode.current == .pushToTalk ? 1 : 0
        let modeRow = Styles.makeRow(label: "Mode", control: modeControl, width: cardWidth)

        // Auto-stop row
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
        let silenceRow = Styles.makeRow(label: "Auto-stop", control: silencePicker, width: cardWidth)

        let recordingCard = buildCard(rows: [modeRow, silenceRow])
        place(recordingCard, height: recordingCard.frame.height)
        y += Styles.descBelowCardGap

        let recordingDesc = Styles.makeDescription(
            "Toggle: press shortcut to start, press again to stop. Push-to-talk: hold to record, release to transcribe. Auto-stop triggers after the chosen duration of silence.",
            width: cardWidth
        )
        placeFullWidth(recordingDesc, height: 44, leading: pad)
        y += Styles.sectionGap

        // ── Post-processing ──

        let postTitle = Styles.sectionTitle("Post-processing")
        place(postTitle, height: 16 + Styles.titleToCardGap)

        // Checkbox rows — checkboxes span the full row, no separate label/control split
        let fillerToggle = NSButton(checkboxWithTitle: "Remove filler words and stutters", target: self, action: #selector(toggleFiller(_:)))
        fillerToggle.state = UserDefaults.standard.object(forKey: "removeFillers") == nil ? .on : (UserDefaults.standard.bool(forKey: "removeFillers") ? .on : .off)
        let fillerRow = FlippedView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: rowH))
        fillerToggle.translatesAutoresizingMaskIntoConstraints = false
        fillerRow.addSubview(fillerToggle)
        NSLayoutConstraint.activate([
            fillerToggle.leadingAnchor.constraint(equalTo: fillerRow.leadingAnchor, constant: hPad),
            fillerToggle.centerYAnchor.constraint(equalTo: fillerRow.centerYAnchor),
        ])

        let clipboardToggle = NSButton(checkboxWithTitle: "Keep transcribed text on clipboard", target: self, action: #selector(toggleClipboard(_:)))
        clipboardToggle.state = UserDefaults.standard.bool(forKey: "keepOnClipboard") ? .on : .off
        let clipboardRow = FlippedView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: rowH))
        clipboardToggle.translatesAutoresizingMaskIntoConstraints = false
        clipboardRow.addSubview(clipboardToggle)
        NSLayoutConstraint.activate([
            clipboardToggle.leadingAnchor.constraint(equalTo: clipboardRow.leadingAnchor, constant: hPad),
            clipboardToggle.centerYAnchor.constraint(equalTo: clipboardRow.centerYAnchor),
        ])

        let postCard = buildCard(rows: [fillerRow, clipboardRow])
        place(postCard, height: postCard.frame.height)
        y += Styles.sectionGap

        // ── Language ──

        let langTitle = Styles.sectionTitle("Language")
        place(langTitle, height: 16 + Styles.titleToCardGap)

        let langPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        langPicker.addItem(withTitle: "Auto-detect")
        langPicker.lastItem?.representedObject = "auto"
        langPicker.menu?.addItem(.separator())
        for lang in popularLanguages {
            langPicker.addItem(withTitle: lang.name)
            langPicker.lastItem?.representedObject = lang.code
        }
        langPicker.menu?.addItem(.separator())
        for lang in allLanguages {
            if popularLanguages.contains(where: { $0.code == lang.code }) { continue }
            langPicker.addItem(withTitle: lang.name)
            langPicker.lastItem?.representedObject = lang.code
        }
        let savedLang = UserDefaults.standard.string(forKey: "whisperLanguage") ?? "en"
        for i in 0..<langPicker.numberOfItems {
            if let code = langPicker.item(at: i)?.representedObject as? String, code == savedLang {
                langPicker.selectItem(at: i)
                break
            }
        }
        langPicker.target = self
        langPicker.action = #selector(languageChanged(_:))
        let langRow = Styles.makeRow(label: "Language", control: langPicker, width: cardWidth)

        let langCard = buildCard(rows: [langRow])
        place(langCard, height: langCard.frame.height)
        y += Styles.descBelowCardGap

        let langDesc = Styles.makeDescription(
            "\"Auto-detect\" lets Whisper identify the spoken language. Popular languages are listed first.",
            width: cardWidth
        )
        placeFullWidth(langDesc, height: 32, leading: pad)
        y += Styles.sectionGap

        // ── Whisper Model ──

        let whisperTitle = Styles.sectionTitle("Whisper Model")
        place(whisperTitle, height: 16 + Styles.titleToCardGap)

        let modelPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        modelPicker.addItems(withTitles: ["base", "small", "medium", "large"])
        let savedModel = UserDefaults.standard.string(forKey: "whisperModel") ?? "small"
        modelPicker.selectItem(withTitle: savedModel)
        modelPicker.target = self
        modelPicker.action = #selector(modelChanged(_:))

        // Model control area: picker + spinner + status in a horizontal stack
        let modelControlStack = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isHidden = true
        modelSpinner = spinner

        let statusLabel = Styles.label("", font: Styles.captionFont, color: .systemGreen)
        modelStatusLabel = statusLabel

        modelPicker.translatesAutoresizingMaskIntoConstraints = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        modelControlStack.addSubview(modelPicker)
        modelControlStack.addSubview(spinner)
        modelControlStack.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            modelPicker.leadingAnchor.constraint(equalTo: modelControlStack.leadingAnchor),
            modelPicker.centerYAnchor.constraint(equalTo: modelControlStack.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: modelPicker.trailingAnchor, constant: 6),
            spinner.centerYAnchor.constraint(equalTo: modelControlStack.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 6),
            statusLabel.centerYAnchor.constraint(equalTo: modelControlStack.centerYAnchor),
            modelControlStack.trailingAnchor.constraint(greaterThanOrEqualTo: statusLabel.trailingAnchor),
        ])

        let modelRow = Styles.makeRow(label: "Model", control: modelControlStack, width: cardWidth)
        let modelCard = buildCard(rows: [modelRow])
        place(modelCard, height: modelCard.frame.height)
        y += Styles.descBelowCardGap

        let modelDesc = Styles.makeDescription(
            "Larger models are more accurate but use more memory and are slower. \"small\" is recommended.",
            width: cardWidth
        )
        placeFullWidth(modelDesc, height: 32, leading: pad)

        // Observe transcriber state changes to update the status label
        stateObserver = NotificationCenter.default.addObserver(
            forName: .transcriberStateChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateModelStatus()
        }
        updateModelStatus()

        y += Styles.sectionGap

        // ── General ──

        let generalTitle = Styles.sectionTitle("General")
        place(generalTitle, height: 16 + Styles.titleToCardGap)

        let soundToggle = NSButton(checkboxWithTitle: "Play sound feedback", target: self, action: #selector(toggleSoundFeedback(_:)))
        soundToggle.state = UserDefaults.standard.object(forKey: "playSoundFeedback") == nil ? .on : (UserDefaults.standard.bool(forKey: "playSoundFeedback") ? .on : .off)
        let soundRow = FlippedView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: rowH))
        soundToggle.translatesAutoresizingMaskIntoConstraints = false
        soundRow.addSubview(soundToggle)
        NSLayoutConstraint.activate([
            soundToggle.leadingAnchor.constraint(equalTo: soundRow.leadingAnchor, constant: hPad),
            soundToggle.centerYAnchor.constraint(equalTo: soundRow.centerYAnchor),
        ])

        let historyToggle = NSButton(checkboxWithTitle: "Save transcription history", target: self, action: #selector(toggleHistory(_:)))
        historyToggle.state = TranscriptionHistory.isEnabled ? .on : .off
        let historyRow = FlippedView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: rowH))
        historyToggle.translatesAutoresizingMaskIntoConstraints = false
        historyRow.addSubview(historyToggle)
        NSLayoutConstraint.activate([
            historyToggle.leadingAnchor.constraint(equalTo: historyRow.leadingAnchor, constant: hPad),
            historyToggle.centerYAnchor.constraint(equalTo: historyRow.centerYAnchor),
        ])

        let loginToggle = NSButton(checkboxWithTitle: "Launch at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        loginToggle.state = UserDefaults.standard.bool(forKey: "launchAtLogin") ? .on : .off
        let loginRow = FlippedView(frame: NSRect(x: 0, y: 0, width: cardWidth, height: rowH))
        loginToggle.translatesAutoresizingMaskIntoConstraints = false
        loginRow.addSubview(loginToggle)
        NSLayoutConstraint.activate([
            loginToggle.leadingAnchor.constraint(equalTo: loginRow.leadingAnchor, constant: hPad),
            loginToggle.centerYAnchor.constraint(equalTo: loginRow.centerYAnchor),
        ])

        let generalCard = buildCard(rows: [soundRow, historyRow, loginRow])
        place(generalCard, height: generalCard.frame.height)
        y += Styles.descBelowCardGap

        let generalDesc = Styles.makeDescription(
            "Audio cues play when recording starts and stops. Only transcribed text is saved — audio is never stored.",
            width: cardWidth
        )
        placeFullWidth(generalDesc, height: 32, leading: pad)
        y += pad

        // Set the document view size so scrolling works
        outer.frame = NSRect(x: 0, y: 0, width: winWidth, height: y)

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc private func recordingModeChanged(_ sender: NSSegmentedControl) {
        let mode: RecordingMode = sender.selectedSegment == 1 ? .pushToTalk : .toggle
        UserDefaults.standard.set(mode.rawValue, forKey: "recordingMode")
    }

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

    @objc private func toggleSoundFeedback(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "playSoundFeedback")
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

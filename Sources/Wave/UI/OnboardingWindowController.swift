import Cocoa
import KeyboardShortcuts

// First-run welcome screen.
// Three steps: (1) Microphone permission, (2) Accessibility permission, (3) Model download.
// The user cannot proceed until the model finishes downloading.
//
// Layout uses NSStackView so each section sizes itself — no manual Y-offsets.
class OnboardingWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var micStatusLabel: NSTextField?
    private var axStatusLabel: NSTextField?
    private var modelStatusLabel: NSTextField?
    private var modelSpinner: NSProgressIndicator?
    private var downloadButton: NSButton?
    private var modelPicker: NSPopUpButton?
    private var startButton: NSButton?
    private var btnNote: NSTextField?
    private var stateObserver: Any?

    private static let onboardingCompleteKey = "onboardingComplete"

    static var isComplete: Bool {
        UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }

    func show() {
        NSApp.setActivationPolicy(.accessory)

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 460, height: 600)),
            styleMask: [.titled],
            backing: .buffered, defer: false
        )
        w.title = "Welcome to Wave"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        // Root vertical stack drives all layout
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = stack
        w.contentView = scrollView

        // Pin stack width to scroll view (height is determined by content)
        let clip = scrollView.contentView
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: clip.topAnchor),
            stack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
        ])

        // ── Hero ──
        let hero = buildHero()
        addSection(hero, to: stack)
        stack.setCustomSpacing(20, after: hero)

        // ── Separator ──
        let sep1 = buildSeparator()
        addSection(sep1, to: stack)
        stack.setCustomSpacing(16, after: sep1)

        // ── Step 1: Microphone ──
        let (micRow, micLabel) = buildPermissionRow(
            title: "Microphone Access",
            detail: "Required to record your voice for transcription.",
            buttonTitle: "Grant Access",
            action: #selector(grantMicrophone)
        )
        micStatusLabel = micLabel
        addSection(micRow, to: stack)
        stack.setCustomSpacing(14, after: micRow)

        // ── Step 2: Accessibility ──
        let (axRow, axLabel) = buildPermissionRow(
            title: "Accessibility",
            detail: "Required to paste text into the active app.",
            buttonTitle: "Open Settings",
            action: #selector(grantAccessibility)
        )
        axStatusLabel = axLabel
        addSection(axRow, to: stack)
        stack.setCustomSpacing(16, after: axRow)

        // ── Separator ──
        let sep2 = buildSeparator()
        addSection(sep2, to: stack)
        stack.setCustomSpacing(16, after: sep2)

        // ── Keyboard Shortcut ──
        let shortcutSection = buildShortcutSection()
        addSection(shortcutSection, to: stack)
        stack.setCustomSpacing(16, after: shortcutSection)

        // ── Separator ──
        let sep3 = buildSeparator()
        addSection(sep3, to: stack)
        stack.setCustomSpacing(16, after: sep3)

        // ── Step 3: Model Download ──
        let modelSection = buildModelSection()
        addSection(modelSection, to: stack)
        stack.setCustomSpacing(20, after: modelSection)

        // ── Separator ──
        let sep4 = buildSeparator()
        addSection(sep4, to: stack)
        stack.setCustomSpacing(16, after: sep4)

        // ── Footer ──
        let footer = buildFooter()
        addSection(footer, to: stack)

        // Bottom padding
        let bottomSpacer = NSView()
        bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
        bottomSpacer.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(bottomSpacer)

        // Observe model state changes
        stateObserver = NotificationCenter.default.addObserver(
            forName: .transcriberStateChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updateModelStatus()
        }
        updateModelStatus()

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Layout helpers

    private let contentPadding: CGFloat = 32

    /// Add a section view to the stack, pinning its width to fill.
    private func addSection(_ view: NSView, to stack: NSStackView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    // MARK: - Section builders

    private func buildHero() -> NSView {
        let box = NSView()

        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Wave") {
            let config = NSImage.SymbolConfiguration(pointSize: 32, weight: .medium)
            icon.image = img.withSymbolConfiguration(config)
            icon.contentTintColor = .controlAccentColor
        }
        icon.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(icon)

        let title = Styles.label("Welcome to Wave", font: NSFont.systemFont(ofSize: 22, weight: .bold))
        title.alignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(title)

        let subtitle = Styles.label(
            "Press a shortcut, speak, and text appears wherever your cursor is. Everything runs locally on your Mac.",
            font: Styles.bodyFont, color: Styles.secondaryLabel
        )
        subtitle.alignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(subtitle)

        let hPad: CGFloat = 40
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: box.topAnchor, constant: 28),
            icon.centerXAnchor.constraint(equalTo: box.centerXAnchor),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            title.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: hPad),
            title.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -hPad),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: hPad),
            subtitle.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -hPad),
            subtitle.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        return box
    }

    private func buildSeparator() -> NSView {
        let box = NSView()
        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: contentPadding),
            sep.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -contentPadding),
            sep.topAnchor.constraint(equalTo: box.topAnchor),
            sep.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        return box
    }

    private func buildPermissionRow(
        title: String, detail: String,
        buttonTitle: String, action: Selector
    ) -> (NSView, NSTextField) {
        let box = NSView()
        let pad = contentPadding

        // Title label
        let titleLabel = Styles.label(title, font: Styles.headlineFont)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        box.addSubview(titleLabel)

        // Action button
        let btn = NSButton(title: buttonTitle, target: self, action: action)
        btn.bezelStyle = .rounded
        btn.controlSize = .regular
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        box.addSubview(btn)

        // Detail label
        let detailLabel = Styles.label(detail, font: Styles.captionFont, color: Styles.secondaryLabel)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(detailLabel)

        // Status label (shown after action)
        let statusLabel = Styles.label("", font: Styles.captionFont, color: .systemGreen)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            // Row 1: title ... button
            titleLabel.topAnchor.constraint(equalTo: box.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),

            btn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            btn.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -pad),
            btn.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),

            // Row 2: detail + status
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            detailLabel.bottomAnchor.constraint(equalTo: box.bottomAnchor),

            statusLabel.centerYAnchor.constraint(equalTo: detailLabel.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: detailLabel.trailingAnchor, constant: 6),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: box.trailingAnchor, constant: -pad),
        ])

        return (box, statusLabel)
    }

    private func buildShortcutSection() -> NSView {
        let box = NSView()
        let pad = contentPadding

        // Title
        let title = Styles.label("Keyboard Shortcut", font: Styles.headlineFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(title)

        // Detail
        let detail = Styles.label(
            "Press this shortcut to start dictation, press again to stop and transcribe.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        detail.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(detail)

        // Shortcut recorder
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleDictation)
        recorder.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(recorder)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: box.topAnchor),
            title.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            title.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -pad),

            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            detail.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            detail.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -pad),

            recorder.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 10),
            recorder.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            recorder.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        return box
    }

    private func buildModelSection() -> NSView {
        let box = NSView()
        let pad = contentPadding

        // Title
        let title = Styles.label("Download Speech Model", font: Styles.headlineFont)
        title.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(title)

        // Description
        let desc = Styles.label(
            "Wave uses OpenAI's Whisper to transcribe speech on-device. Pick a model size and download it before continuing.",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        desc.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(desc)

        // Model picker
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        picker.addItems(withTitles: [
            "small  (~460 MB, recommended)",
            "base  (~140 MB, faster)",
            "medium  (~1.5 GB, more accurate)",
            "large  (~3 GB, most accurate)",
        ])
        for (i, name) in ["small", "base", "medium", "large"].enumerated() {
            picker.itemArray[i].representedObject = name
        }
        let savedModel = UserDefaults.standard.string(forKey: "whisperModel") ?? "small"
        if let idx = ["small", "base", "medium", "large"].firstIndex(of: savedModel) {
            picker.selectItem(at: idx)
        }
        picker.target = self
        picker.action = #selector(modelPickerChanged(_:))
        picker.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(picker)
        modelPicker = picker

        // Download button
        let dlBtn = NSButton(title: "Download", target: self, action: #selector(startDownload))
        dlBtn.bezelStyle = .rounded
        dlBtn.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(dlBtn)
        downloadButton = dlBtn

        // Spinner
        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        box.addSubview(spinner)
        modelSpinner = spinner

        // Status label
        let status = Styles.label("", font: Styles.captionFont, color: .systemOrange)
        status.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(status)
        modelStatusLabel = status

        NSLayoutConstraint.activate([
            // Title
            title.topAnchor.constraint(equalTo: box.topAnchor),
            title.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            title.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -pad),

            // Description
            desc.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            desc.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            desc.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -pad),

            // Picker row
            picker.topAnchor.constraint(equalTo: desc.bottomAnchor, constant: 12),
            picker.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),

            dlBtn.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
            dlBtn.leadingAnchor.constraint(equalTo: picker.trailingAnchor, constant: 10),

            spinner.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: dlBtn.trailingAnchor, constant: 8),

            // Status
            status.topAnchor.constraint(equalTo: picker.bottomAnchor, constant: 6),
            status.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: pad),
            status.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -pad),
            status.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        return box
    }

    private func buildFooter() -> NSView {
        let box = NSView()

        let btn = Styles.accentButton("Get Started", target: self, action: #selector(getStarted))
        btn.isEnabled = false
        btn.translatesAutoresizingMaskIntoConstraints = false
        startButton = btn
        box.addSubview(btn)

        let note = Styles.label("Download a model to get started.", font: Styles.captionFont, color: Styles.tertiaryLabel)
        note.alignment = .center
        note.translatesAutoresizingMaskIntoConstraints = false
        btnNote = note
        box.addSubview(note)

        NSLayoutConstraint.activate([
            btn.topAnchor.constraint(equalTo: box.topAnchor),
            btn.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            btn.widthAnchor.constraint(equalToConstant: 200),

            note.topAnchor.constraint(equalTo: btn.bottomAnchor, constant: 6),
            note.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: contentPadding),
            note.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -contentPadding),
            note.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])

        return box
    }

    // MARK: - Window delegate

    func windowWillClose(_ notification: Notification) {
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
            stateObserver = nil
        }
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Permission actions

    @objc private func grantMicrophone() {
        Permissions.requestMicrophone { [weak self] granted in
            if granted {
                self?.micStatusLabel?.stringValue = "\u{2714} Granted"
                self?.micStatusLabel?.textColor = .systemGreen
            } else {
                self?.micStatusLabel?.stringValue = "Denied"
                self?.micStatusLabel?.textColor = .systemOrange
            }
        }
    }

    @objc private func grantAccessibility() {
        Permissions.requestAccessibility()
        axStatusLabel?.stringValue = "Check System Settings"
        axStatusLabel?.textColor = .systemOrange
    }

    // MARK: - Model download

    @objc private func modelPickerChanged(_ sender: NSPopUpButton) {
        if let name = sender.selectedItem?.representedObject as? String {
            UserDefaults.standard.set(name, forKey: "whisperModel")
        }
    }

    @objc private func startDownload() {
        if let name = modelPicker?.selectedItem?.representedObject as? String {
            UserDefaults.standard.set(name, forKey: "whisperModel")
        }
        modelPicker?.isEnabled = false
        downloadButton?.isEnabled = false

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.prepareTranscriber()
        }
    }

    private func updateModelStatus() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        switch appDelegate.transcriber.state {
        case .idle:
            modelStatusLabel?.stringValue = ""
            modelSpinner?.isHidden = true
            modelSpinner?.stopAnimation(nil)
            modelPicker?.isEnabled = true
            downloadButton?.isEnabled = true
            startButton?.isEnabled = false
            btnNote?.isHidden = false
            btnNote?.stringValue = "Download a model to get started."

        case .downloading(let model):
            modelStatusLabel?.stringValue = "Downloading \(model) model\u{2026}"
            modelStatusLabel?.textColor = .systemOrange
            modelSpinner?.isHidden = false
            modelSpinner?.startAnimation(nil)
            modelPicker?.isEnabled = false
            downloadButton?.isEnabled = false
            startButton?.isEnabled = false
            btnNote?.isHidden = false
            btnNote?.stringValue = "Downloading\u{2026}"

        case .ready(let model):
            modelStatusLabel?.stringValue = "\u{2714} \(model) model ready"
            modelStatusLabel?.textColor = .systemGreen
            modelSpinner?.isHidden = true
            modelSpinner?.stopAnimation(nil)
            modelPicker?.isEnabled = false
            downloadButton?.isEnabled = false
            startButton?.isEnabled = true
            btnNote?.isHidden = true

        case .failed(let message):
            modelStatusLabel?.stringValue = "Failed: \(message)"
            modelStatusLabel?.textColor = .systemRed
            modelSpinner?.isHidden = true
            modelSpinner?.stopAnimation(nil)
            modelPicker?.isEnabled = true
            downloadButton?.isEnabled = true
            startButton?.isEnabled = false
            btnNote?.isHidden = false
            btnNote?.stringValue = "Download failed. Try again."
        }
    }

    @objc private func getStarted() {
        UserDefaults.standard.set(true, forKey: OnboardingWindowController.onboardingCompleteKey)
        if let observer = stateObserver {
            NotificationCenter.default.removeObserver(observer)
            stateObserver = nil
        }
        window?.close()
        NSApp.setActivationPolicy(.accessory)
    }
}

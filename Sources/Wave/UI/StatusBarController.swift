import Cocoa

// Manages the menu bar icon and dropdown menu.
// When idle: shows dropdown menu on click.
// When recording: click stops recording (no menu). Icon pulses red.
// When transcribing: shows processing icon, menu disabled.
class StatusBarController {

    private var statusItem: NSStatusItem!
    private var aboutWindowController: AboutWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var historyWindowController: HistoryWindowController?
    private var pulseTimer: Timer?
    private var pulseVisible = true

    // Callbacks
    var onStopRecording: (() -> Void)?
    var onStartDictation: (() -> Void)?

    // Current state for icon display
    enum State {
        case idle
        case recording
        case transcribing
    }

    private(set) var state: State = .idle

    init() {
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()
        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Header
        let header = NSMenuItem(title: "Wave", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        // Status line — shows recording state and model status
        let statusText: String
        switch state {
        case .idle:
            // Show model state when idle
            if let appDelegate = NSApp.delegate as? AppDelegate {
                switch appDelegate.transcriber.state {
                case .idle: statusText = "Starting up..."
                case .downloading(let model): statusText = "Downloading \(model) model..."
                case .ready(let model): statusText = "Ready (\(model) model)"
                case .failed: statusText = "Model failed — check Settings"
                }
            } else {
                statusText = "Ready"
            }
        case .recording: statusText = "Recording..."
        case .transcribing: statusText = "Transcribing..."
        }
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        // Start Wave
        let dictationItem = menu.addItem(
            withTitle: "Start Wave",
            action: #selector(startDictation),
            keyEquivalent: "d"
        )
        dictationItem.target = self
        // Disable if model isn't ready
        if let appDelegate = NSApp.delegate as? AppDelegate, !appDelegate.transcriber.isReady {
            dictationItem.isEnabled = false
        }
        menu.addItem(.separator())

        // History
        let historyItem = menu.addItem(
            withTitle: "Transcription History\u{2026}",
            action: #selector(openHistory),
            keyEquivalent: "h"
        )
        historyItem.target = self

        // Settings
        let settingsItem = menu.addItem(
            withTitle: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self

        // About
        let aboutItem = menu.addItem(
            withTitle: "About Wave",
            action: #selector(openAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Wave", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    // MARK: - State management

    func setState(_ newState: State) {
        state = newState
        updateIcon()

        switch newState {
        case .recording:
            // Remove menu so clicks go to the button action instead
            statusItem.menu = nil
            statusItem.button?.action = #selector(statusBarClicked)
            statusItem.button?.target = self
            startPulsing()

        case .idle, .transcribing:
            // Restore menu for normal dropdown behavior
            stopPulsing()
            rebuildMenu()
            statusItem.button?.action = nil
            statusItem.button?.target = nil
        }
    }

    // MARK: - Click to stop

    @objc private func statusBarClicked() {
        if state == .recording {
            onStopRecording?()
        }
    }

    // MARK: - Pulse animation

    private func startPulsing() {
        pulseVisible = true
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.pulseVisible.toggle()
            self.updateIcon()
        }
    }

    private func stopPulsing() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulseVisible = true
    }

    // MARK: - Icon

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let size = NSSize(width: Styles.statusBarIconSize, height: Styles.statusBarIconSize)

        switch state {
        case .idle:
            if let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Wave") {
                img.size = size
                img.isTemplate = true
                button.image = img
            }

        case .recording:
            // Pulsing red waveform icon
            let alpha: CGFloat = pulseVisible ? 1.0 : 0.3
            if let waveImage = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Recording — click to stop") {
                let composite = NSImage(size: size, flipped: false) { rect in
                    waveImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    NSColor.systemRed.withAlphaComponent(alpha).setFill()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                composite.isTemplate = false
                button.image = composite
            }

        case .transcribing:
            if let img = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Transcribing") {
                img.size = size
                img.isTemplate = true
                button.image = img
            }
        }
    }

    // MARK: - Actions

    @objc private func startDictation() {
        onStartDictation?()
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }

    @objc private func openHistory() {
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController()
        }
        historyWindowController?.show()
    }

    @objc private func openAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }
        aboutWindowController?.show()
    }
}

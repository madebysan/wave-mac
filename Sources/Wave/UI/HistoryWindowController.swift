import Cocoa

// Shows a list of recent transcriptions.
// Each row shows the text (truncated) and timestamp.
// Click a row to copy its text to clipboard.
class HistoryWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {

    private var window: NSWindow?
    private var tableView: NSTableView!
    private var entries: [TranscriptionHistory.Entry] = []

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    func show() {
        NSApp.setActivationPolicy(.accessory)
        entries = TranscriptionHistory.shared.entries

        if let w = window {
            tableView?.reloadData()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 400)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        w.title = "Transcription History"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.minSize = NSSize(width: 400, height: 250)
        window = w

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        // Table view
        tableView = NSTableView()
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 52
        tableView.target = self
        tableView.doubleAction = #selector(copySelected)
        tableView.style = .plain

        let textColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textColumn.title = "Text"
        textColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(textColumn)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(scrollView)

        // Bottom bar with buttons
        let bottomBar = NSView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(bottomBar)

        let copyButton = NSButton(title: "Copy Selected", target: self, action: #selector(copySelected))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(copyButton)

        let showButton = NSButton(title: "Show in Finder", target: self, action: #selector(showInFinder))
        showButton.bezelStyle = .rounded
        showButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(showButton)

        let clearButton = NSButton(title: "Clear All", target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(clearButton)

        let countLabel = Styles.label(
            entries.isEmpty ? "No transcriptions yet" : "\(entries.count) transcription\(entries.count == 1 ? "" : "s")",
            font: Styles.captionFont, color: Styles.secondaryLabel
        )
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(countLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: outer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: outer.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 44),

            countLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            countLabel.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            clearButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            showButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            showButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            copyButton.trailingAnchor.constraint(equalTo: showButton.leadingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = entries[row]

        let cell = NSView()

        // Text (truncated to 2 lines)
        let textLabel = NSTextField(wrappingLabelWithString: entry.text)
        textLabel.font = Styles.bodyFont
        textLabel.textColor = .labelColor
        textLabel.isEditable = false
        textLabel.isSelectable = false
        textLabel.isBordered = false
        textLabel.drawsBackground = false
        textLabel.maximumNumberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(textLabel)

        // Date
        let dateLabel = NSTextField(labelWithString: dateFormatter.string(from: entry.date))
        dateLabel.font = Styles.captionFont
        dateLabel.textColor = Styles.tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6),
            textLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),

            dateLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),
            dateLabel.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
        ])

        return cell
    }

    // MARK: - Actions

    @objc private func copySelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < entries.count else { return }
        let text = entries[row].text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func showInFinder() {
        let historyFile = FileLocations.appSupportDir.appendingPathComponent("history.json")
        if FileManager.default.fileExists(atPath: historyFile.path) {
            NSWorkspace.shared.activateFileViewerSelecting([historyFile])
        } else {
            NSWorkspace.shared.open(FileLocations.appSupportDir)
        }
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear all transcription history?"
        alert.informativeText = "This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            TranscriptionHistory.shared.clearAll()
            entries = []
            tableView.reloadData()
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

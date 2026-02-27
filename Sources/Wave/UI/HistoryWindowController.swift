import Cocoa
import UniformTypeIdentifiers

// Shows a list of recent transcriptions.
// Each row shows the text (truncated) and timestamp.
// Click a row to copy its text to clipboard.
class HistoryWindowController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {

    private var window: NSWindow?
    private var tableView: NSTableView!
    private var entries: [TranscriptionHistory.Entry] = []       // all entries
    private var filteredEntries: [TranscriptionHistory.Entry] = [] // currently displayed
    private var searchField: NSSearchField?
    private var countLabel: NSTextField?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    func show() {
        NSApp.setActivationPolicy(.accessory)
        entries = TranscriptionHistory.shared.entries
        filteredEntries = entries

        if let w = window {
            filteredEntries = entries
            searchField?.stringValue = ""
            updateCountLabel()
            tableView?.reloadData()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 440)),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        w.title = "Transcription History"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.minSize = NSSize(width: 400, height: 280)
        window = w

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        // Search field
        let search = NSSearchField()
        search.placeholderString = "Search transcriptions..."
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(search)
        searchField = search

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

        let exportButton = NSButton(title: "Export...", target: self, action: #selector(exportHistory))
        exportButton.bezelStyle = .rounded
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(exportButton)

        let showButton = NSButton(title: "Show in Finder", target: self, action: #selector(showInFinder))
        showButton.bezelStyle = .rounded
        showButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(showButton)

        let clearButton = NSButton(title: "Clear All", target: self, action: #selector(clearHistory))
        clearButton.bezelStyle = .rounded
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(clearButton)

        let label = Styles.label("", font: Styles.captionFont, color: Styles.secondaryLabel)
        label.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(label)
        countLabel = label
        updateCountLabel()

        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: outer.topAnchor, constant: 8),
            search.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: 12),
            search.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -12),

            scrollView.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: outer.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 44),

            label.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            clearButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            clearButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            showButton.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            showButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            exportButton.trailingAnchor.constraint(equalTo: showButton.leadingAnchor, constant: -8),
            exportButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),

            copyButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -8),
            copyButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
        ])

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Search

    func controlTextDidChange(_ obj: Notification) {
        guard let search = obj.object as? NSSearchField else { return }
        applySearchFilter(search.stringValue)
    }

    private func applySearchFilter(_ query: String) {
        if query.isEmpty {
            filteredEntries = entries
        } else {
            filteredEntries = entries.filter {
                $0.text.localizedCaseInsensitiveContains(query)
            }
        }
        updateCountLabel()
        tableView.reloadData()
    }

    private func updateCountLabel() {
        let total = entries.count
        let showing = filteredEntries.count
        if total == 0 {
            countLabel?.stringValue = "No transcriptions yet"
        } else if showing == total {
            countLabel?.stringValue = "\(total) transcription\(total == 1 ? "" : "s")"
        } else {
            countLabel?.stringValue = "\(showing) of \(total) transcription\(total == 1 ? "" : "s")"
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredEntries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = filteredEntries[row]

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
        guard row >= 0, row < filteredEntries.count else { return }
        let text = filteredEntries[row].text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func exportHistory() {
        guard !entries.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Export Transcription History"
        panel.nameFieldStringValue = "wave-history"
        panel.allowedContentTypes = [
            .plainText,
            .commaSeparatedText,
        ]
        // Add Markdown via file extension
        panel.allowsOtherFileTypes = true
        panel.canSelectHiddenExtension = true

        // Format picker as accessory view
        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.font = Styles.bodyFont
        formatLabel.translatesAutoresizingMaskIntoConstraints = false

        let formatPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        formatPicker.addItems(withTitles: ["Plain Text (.txt)", "Markdown (.md)", "CSV (.csv)"])
        formatPicker.translatesAutoresizingMaskIntoConstraints = false
        formatPicker.target = self
        formatPicker.tag = 99

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 32))
        accessory.addSubview(formatLabel)
        accessory.addSubview(formatPicker)
        NSLayoutConstraint.activate([
            formatLabel.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 8),
            formatLabel.centerYAnchor.constraint(equalTo: accessory.centerYAnchor),
            formatPicker.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 8),
            formatPicker.centerYAnchor.constraint(equalTo: accessory.centerYAnchor),
        ])
        panel.accessoryView = accessory

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let format = formatPicker.indexOfSelectedItem
        var content = ""
        let exportEntries = entries // always export all entries, not filtered

        switch format {
        case 0: // Plain text
            let finalURL = url.pathExtension.isEmpty ? url.appendingPathExtension("txt") : url
            for entry in exportEntries {
                let dateStr = dateFormatter.string(from: entry.date)
                content += "[\(dateStr)]\n\(entry.text)\n\n"
            }
            try? content.write(to: finalURL, atomically: true, encoding: .utf8)

        case 1: // Markdown
            let finalURL = url.pathExtension.isEmpty ? url.appendingPathExtension("md") : url
            content = "# Wave Transcription History\n\n"
            for entry in exportEntries {
                let dateStr = dateFormatter.string(from: entry.date)
                content += "### \(dateStr)\n\n\(entry.text)\n\n---\n\n"
            }
            try? content.write(to: finalURL, atomically: true, encoding: .utf8)

        case 2: // CSV
            let finalURL = url.pathExtension.isEmpty ? url.appendingPathExtension("csv") : url
            content = "Date,Text\n"
            for entry in exportEntries {
                let dateStr = dateFormatter.string(from: entry.date)
                let escaped = entry.text.replacingOccurrences(of: "\"", with: "\"\"")
                content += "\"\(dateStr)\",\"\(escaped)\"\n"
            }
            try? content.write(to: finalURL, atomically: true, encoding: .utf8)

        default:
            break
        }
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
            filteredEntries = []
            searchField?.stringValue = ""
            updateCountLabel()
            tableView.reloadData()
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

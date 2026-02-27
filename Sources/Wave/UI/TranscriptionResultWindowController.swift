import Cocoa

// Displays the result of an audio file transcription.
// Shows the text with Copy and Paste buttons.
class TranscriptionResultWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private var text: String = ""
    private var fileName: String = ""

    // Callback for "Paste into Active App" — AppDelegate handles the delay + injection
    var onPaste: ((String) -> Void)?

    func show(text: String, fileName: String) {
        self.text = text
        self.fileName = fileName

        NSApp.setActivationPolicy(.accessory)

        if let w = window {
            updateContent()
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 500, height: 400)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false
        )
        w.title = "Transcription — \(fileName)"
        w.minSize = NSSize(width: 350, height: 250)
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView?.addSubview(outer)
        NSLayoutConstraint.activate([
            outer.topAnchor.constraint(equalTo: w.contentView!.topAnchor),
            outer.bottomAnchor.constraint(equalTo: w.contentView!.bottomAnchor),
            outer.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor),
            outer.trailingAnchor.constraint(equalTo: w.contentView!.trailingAnchor),
        ])

        // Scrollable read-only text view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(scrollView)

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = Styles.bodyFont
        textView.textColor = .labelColor
        textView.string = text
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        // Button bar at the bottom
        let buttonBar = NSView()
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(buttonBar)

        let copyButton = NSButton(title: "Copy to Clipboard", target: self, action: #selector(copyToClipboard))
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.addSubview(copyButton)

        let pasteButton = Styles.accentButton("Paste into Active App", target: self, action: #selector(pasteIntoApp))
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.addSubview(pasteButton)

        let pad: CGFloat = 16

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: outer.topAnchor, constant: pad),
            scrollView.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            scrollView.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
            scrollView.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: -12),

            buttonBar.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            buttonBar.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
            buttonBar.bottomAnchor.constraint(equalTo: outer.bottomAnchor, constant: -pad),
            buttonBar.heightAnchor.constraint(equalToConstant: 32),

            copyButton.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor),
            copyButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),

            pasteButton.trailingAnchor.constraint(equalTo: buttonBar.trailingAnchor),
            pasteButton.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),
        ])

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateContent() {
        window?.title = "Transcription — \(fileName)"
        if let scrollView = window?.contentView?.subviews.first?.subviews.first as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            textView.string = text
        }
    }

    @objc private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func pasteIntoApp() {
        let textToInject = text
        window?.close()
        // Small delay so the previously active app regains focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onPaste?(textToInject)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

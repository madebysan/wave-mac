import Cocoa

// Floating preview panel that shows real-time transcription text.
// Uses NSPanel with .nonactivatingPanel so it doesn't steal focus from the active app.
// Confirmed text shows in normal weight, unconfirmed text in italic/lighter color.
class PreviewWindowController: NSObject {

    private var panel: NSPanel?
    private var confirmedField: NSTextField?
    private var unconfirmedField: NSTextField?

    func show() {
        if let p = panel {
            p.alphaValue = 0
            p.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                p.animator().alphaValue = 1
            }
            return
        }

        // Position: lower third of main screen, horizontally centered
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let panelWidth: CGFloat = min(600, screenFrame.width - 80)
        let panelHeight: CGFloat = 80
        let panelX = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let panelY = screenFrame.origin.y + screenFrame.height * 0.15

        let p = NSPanel(
            contentRect: NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .hudWindow, .titled, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        p.level = .floating
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isMovableByWindowBackground = true
        p.titlebarAppearsTransparent = true
        p.titleVisibility = .hidden
        p.isReleasedWhenClosed = false
        p.hasShadow = true
        p.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
        panel = p

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        p.contentView?.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: p.contentView!.topAnchor, constant: 12),
            container.bottomAnchor.constraint(equalTo: p.contentView!.bottomAnchor, constant: -12),
            container.leadingAnchor.constraint(equalTo: p.contentView!.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: p.contentView!.trailingAnchor, constant: -16),
        ])

        // Confirmed text — normal weight, full opacity
        let confirmed = NSTextField(wrappingLabelWithString: "")
        confirmed.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        confirmed.textColor = .labelColor
        confirmed.isEditable = false
        confirmed.isSelectable = false
        confirmed.isBordered = false
        confirmed.drawsBackground = false
        confirmed.maximumNumberOfLines = 2
        confirmed.lineBreakMode = .byTruncatingHead
        confirmed.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(confirmed)
        confirmedField = confirmed

        // Unconfirmed text — italic, lighter color
        let unconfirmed = NSTextField(wrappingLabelWithString: "")
        unconfirmed.font = NSFont(descriptor: NSFont.systemFont(ofSize: 14, weight: .regular).fontDescriptor.withSymbolicTraits(.italic), size: 14) ?? NSFont.systemFont(ofSize: 14)
        unconfirmed.textColor = .secondaryLabelColor
        unconfirmed.isEditable = false
        unconfirmed.isSelectable = false
        unconfirmed.isBordered = false
        unconfirmed.drawsBackground = false
        unconfirmed.maximumNumberOfLines = 1
        unconfirmed.lineBreakMode = .byTruncatingTail
        unconfirmed.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(unconfirmed)
        unconfirmedField = unconfirmed

        NSLayoutConstraint.activate([
            confirmed.topAnchor.constraint(equalTo: container.topAnchor),
            confirmed.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            confirmed.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            unconfirmed.topAnchor.constraint(equalTo: confirmed.bottomAnchor, constant: 4),
            unconfirmed.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            unconfirmed.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            unconfirmed.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])

        // Fade in
        p.alphaValue = 0
        p.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            p.animator().alphaValue = 1
        }
    }

    /// Update the displayed text.
    func update(confirmed: String, unconfirmed: String) {
        confirmedField?.stringValue = confirmed
        unconfirmedField?.stringValue = unconfirmed
    }

    /// Fade out and close the panel.
    func hide() {
        guard let p = panel else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            p.animator().alphaValue = 0
        }, completionHandler: {
            p.orderOut(nil)
        })
    }
}

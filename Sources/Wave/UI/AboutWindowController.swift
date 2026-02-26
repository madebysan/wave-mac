import Cocoa

// Simple About window showing app name, version, and description.
class AboutWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?

    func show() {
        NSApp.setActivationPolicy(.accessory)

        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 300, height: 264)),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        w.title = "About Wave"
        w.center()
        w.isReleasedWhenClosed = false
        w.delegate = self
        window = w

        let outer = FlippedView()
        outer.translatesAutoresizingMaskIntoConstraints = false
        w.contentView = outer

        let pad: CGFloat = 28
        var y: CGFloat = 24

        // App icon
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            iconView.centerXAnchor.constraint(equalTo: outer.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),
        ])
        y += 76

        // App name
        let name = Styles.label("Wave", font: NSFont.systemFont(ofSize: 20, weight: .bold))
        name.alignment = .center
        name.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(name)
        NSLayoutConstraint.activate([
            name.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            name.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            name.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 24

        // Version
        let version = Styles.label("Version 0.1.0", font: Styles.captionFont, color: Styles.secondaryLabel)
        version.alignment = .center
        version.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(version)
        NSLayoutConstraint.activate([
            version.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            version.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            version.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 24

        // Description
        let desc = Styles.label(
            "Local voice-to-text for your Mac. No cloud, no API keys, no subscriptions.",
            font: Styles.bodyFont, color: Styles.secondaryLabel
        )
        desc.alignment = .center
        desc.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(desc)
        NSLayoutConstraint.activate([
            desc.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            desc.leadingAnchor.constraint(equalTo: outer.leadingAnchor, constant: pad),
            desc.trailingAnchor.constraint(equalTo: outer.trailingAnchor, constant: -pad),
        ])
        y += 48

        // Credit — clickable link to santiagoalonso.com
        let creditButton = NSButton(title: "Made by santiagoalonso.com", target: self, action: #selector(openWebsite))
        creditButton.bezelStyle = .inline
        creditButton.isBordered = false
        creditButton.font = Styles.captionFont
        creditButton.contentTintColor = .linkColor
        let attrTitle = NSMutableAttributedString(string: "Made by santiagoalonso.com")
        let linkRange = (attrTitle.string as NSString).range(of: "santiagoalonso.com")
        attrTitle.addAttributes([
            .font: Styles.captionFont,
            .foregroundColor: NSColor.tertiaryLabelColor,
        ], range: NSRange(location: 0, length: attrTitle.length))
        attrTitle.addAttributes([
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ], range: linkRange)
        creditButton.attributedTitle = attrTitle
        creditButton.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(creditButton)
        NSLayoutConstraint.activate([
            creditButton.topAnchor.constraint(equalTo: outer.topAnchor, constant: y),
            creditButton.centerXAnchor.constraint(equalTo: outer.centerXAnchor),
        ])

        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openWebsite() {
        if let url = URL(string: "https://santiagoalonso.com") {
            NSWorkspace.shared.open(url)
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

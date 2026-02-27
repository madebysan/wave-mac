import Cocoa

// An NSView with a flipped (top-left) coordinate origin.
// Required so content starts at the top instead of floating at the bottom.
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// Shared visual constants for all windows.
enum Styles {

    // MARK: - Colors

    static let accentColor = NSColor.controlAccentColor
    static let secondaryLabel = NSColor.secondaryLabelColor
    static let tertiaryLabel = NSColor.tertiaryLabelColor
    static let windowBackground = NSColor.windowBackgroundColor
    static let separator = NSColor.separatorColor

    // MARK: - Fonts

    static let titleFont = NSFont.systemFont(ofSize: 22, weight: .bold)
    static let headlineFont = NSFont.systemFont(ofSize: 15, weight: .medium)
    static let bodyFont = NSFont.systemFont(ofSize: 13, weight: .regular)
    static let captionFont = NSFont.systemFont(ofSize: 11, weight: .regular)
    static let smallBoldFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    // MARK: - Spacing

    static let windowPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let itemSpacing: CGFloat = 8
    static let statusBarIconSize: CGFloat = 18

    // MARK: - Card Layout

    static let cardCornerRadius: CGFloat = 10
    static let cardHPadding: CGFloat = 16
    static let cardRowHeight: CGFloat = 36
    static let sectionGap: CGFloat = 20
    static let titleToCardGap: CGFloat = 8
    static let descBelowCardGap: CGFloat = 6
    static let descLeftInset: CGFloat = 24

    /// Small muted section title that sits above a card.
    static func sectionTitle(_ text: String) -> NSTextField {
        label(text, font: NSFont.systemFont(ofSize: 12, weight: .regular), color: secondaryLabel)
    }

    /// A rounded card container with system background color.
    /// Uses FlippedView so y=0 is the top edge (rows stack downward).
    static func makeCard(width: CGFloat) -> FlippedView {
        let card = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.cornerRadius = cardCornerRadius
        return card
    }

    /// A row inside a card: label on the left, control on the right, 36px tall.
    static func makeRow(label labelText: String, control: NSView, width: CGFloat) -> NSView {
        let row = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: cardRowHeight))

        let lbl = label(labelText, font: bodyFont)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(lbl)

        control.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(control)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: cardHPadding),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            control.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -cardHPadding),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    /// A 1px horizontal divider inset from the left edge.
    static func makeDivider(width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        let line = NSView(frame: NSRect(x: cardHPadding, y: 0, width: width - cardHPadding, height: 1))
        line.wantsLayer = true
        line.layer?.backgroundColor = separator.cgColor
        container.addSubview(line)
        return container
    }

    /// Description text that appears below a card.
    static func makeDescription(_ text: String, width: CGFloat) -> NSTextField {
        let field = label(text, font: NSFont.systemFont(ofSize: 11, weight: .regular), color: tertiaryLabel)
        field.preferredMaxLayoutWidth = width - descLeftInset
        return field
    }

    // MARK: - Helpers

    /// Create a standard label with the given text and font.
    static func label(_ text: String, font: NSFont = bodyFont, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = font
        field.textColor = color
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    /// A primary action button — always accent-colored.
    static func accentButton(_ title: String, target: AnyObject?, action: Selector) -> NSButton {
        let button = NSButton(title: "", target: target, action: action)
        button.bezelStyle = .rounded
        button.bezelColor = .controlAccentColor
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 13, weight: .medium)]
        )
        button.keyEquivalent = "\r"
        return button
    }
}

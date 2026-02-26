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

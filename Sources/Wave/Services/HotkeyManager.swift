import Cocoa
import KeyboardShortcuts

// Define the keyboard shortcut name used across the app.
extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.space, modifiers: .option))
}

// Manages global keyboard shortcut registration and callbacks.
class HotkeyManager {

    var onToggle: (() -> Void)?

    init() {
        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            self?.onToggle?()
        }
    }
}

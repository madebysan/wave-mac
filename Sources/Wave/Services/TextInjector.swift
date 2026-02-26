import Cocoa

// Injects text into the active app by simulating a clipboard paste.
// Saves the current clipboard, sets the text, simulates Cmd+V, then restores.
enum TextInjector {

    /// Whether to keep the transcribed text on the clipboard after pasting (defaults to false).
    static var keepOnClipboard: Bool {
        UserDefaults.standard.bool(forKey: "keepOnClipboard")
    }

    /// Paste text into the currently focused text field.
    /// Uses clipboard + Cmd+V simulation — works in 95%+ of apps.
    static func inject(_ text: String) {
        guard Permissions.hasAccessibilityAccess else {
            // Show alert if accessibility not granted
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Wave needs Accessibility access to paste text. Open System Settings > Privacy & Security > Accessibility and enable Wave."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "OK")
                if alert.runModal() == .alertFirstButtonReturn {
                    Permissions.requestAccessibility()
                }
            }
            return
        }

        let pasteboard = NSPasteboard.general

        // Save current clipboard contents
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // Set our text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V keystroke
        simulatePaste()

        // Restore clipboard after a short delay (unless user wants to keep it)
        if !keepOnClipboard {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Only restore if clipboard hasn't been changed by something else
                if pasteboard.changeCount == previousChangeCount + 1 {
                    pasteboard.clearContents()
                    if let previous = previousContents {
                        pasteboard.setString(previous, forType: .string)
                    }
                }
            }
        }
    }

    /// Simulate a Cmd+V paste keystroke using CGEvent.
    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down: V with Cmd modifier
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // 0x09 = V
        keyDown?.flags = .maskCommand

        // Key up
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

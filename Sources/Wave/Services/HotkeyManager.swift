import Cocoa
import KeyboardShortcuts

// Define the keyboard shortcut name used across the app.
extension KeyboardShortcuts.Name {
    static let toggleDictation = Self("toggleDictation", default: .init(.space, modifiers: .option))
}

// Recording mode: toggle (press to start/stop) or push-to-talk (hold to record).
enum RecordingMode: String {
    case toggle = "toggle"
    case pushToTalk = "pushToTalk"

    static var current: RecordingMode {
        let stored = UserDefaults.standard.string(forKey: "recordingMode") ?? "toggle"
        return RecordingMode(rawValue: stored) ?? .toggle
    }
}

// Manages global keyboard shortcut registration and callbacks.
// Supports toggle mode (press to start/stop) and push-to-talk (hold to record).
class HotkeyManager {

    // Toggle mode: called on key-up to start/stop dictation
    var onToggle: (() -> Void)?

    // Push-to-talk mode: called on key-down to start, key-up to stop
    var onPushStart: (() -> Void)?
    var onPushStop: (() -> Void)?

    init() {
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in
            // Read mode dynamically so changes take effect immediately
            if RecordingMode.current == .pushToTalk {
                self?.onPushStart?()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .toggleDictation) { [weak self] in
            // Read mode dynamically so changes take effect immediately
            if RecordingMode.current == .pushToTalk {
                self?.onPushStop?()
            } else {
                self?.onToggle?()
            }
        }
    }
}

import Cocoa
import AVFoundation

// Checks and requests microphone and accessibility permissions.
enum Permissions {

    // MARK: - Microphone

    /// Whether microphone access has been granted.
    static var hasMicrophoneAccess: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Request microphone permission. Calls completion on main thread.
    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // MARK: - Accessibility

    /// Whether accessibility access has been granted (needed for paste simulation).
    static var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility access in System Settings.
    /// Tries the system prompt first, then opens the Accessibility pane directly as fallback.
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        // If not trusted and the system prompt didn't appear, open Accessibility settings directly
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

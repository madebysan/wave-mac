import Foundation

// Silences system audio while recording by setting volume to 0,
// then restoring it when recording ends.
class MediaController {

    private var savedVolume: Int?

    /// Silence system audio. Call after recording has started.
    func muteForRecording() {
        let current = getVolume()
        if current > 0 {
            savedVolume = current
            setVolume(0)
            print("[Wave] muted system audio (was \(current)%)", to: &standardError)
        } else {
            savedVolume = nil
        }
    }

    /// Restore system audio. Call after recording ends.
    func unmuteAfterRecording() {
        if let vol = savedVolume {
            setVolume(vol)
            print("[Wave] restored volume to \(vol)%", to: &standardError)
            savedVolume = nil
        }
    }

    private func getVolume() -> Int {
        var error: NSDictionary?
        let script = NSAppleScript(source: "output volume of (get volume settings)")
        let result = script?.executeAndReturnError(&error)
        if let error = error {
            print("[Wave] getVolume error: \(error)", to: &standardError)
            return 0
        }
        return Int(result?.int32Value ?? 0)
    }

    private func setVolume(_ level: Int) {
        var error: NSDictionary?
        let script = NSAppleScript(source: "set volume output volume \(level)")
        script?.executeAndReturnError(&error)
        if let error = error {
            print("[Wave] setVolume error: \(error)", to: &standardError)
        }
    }
}

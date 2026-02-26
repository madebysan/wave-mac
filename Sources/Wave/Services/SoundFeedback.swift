import Cocoa

// Plays subtle system sounds when recording starts and stops.
enum SoundFeedback {

    /// Play a short "pop" sound when recording starts.
    static func playStart() {
        NSSound(named: "Pop")?.play()
    }

    /// Play a "done" sound when recording stops.
    static func playStop() {
        NSSound(named: "Tink")?.play()
    }
}

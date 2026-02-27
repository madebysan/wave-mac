import AudioToolbox

// Plays subtle system sounds when recording starts and stops.
// Uses AudioServices instead of NSSound so playback isn't interrupted
// by AVAudioEngine starting/stopping for microphone capture.
enum SoundFeedback {

    private static let popID = systemSoundID(for: "Pop")
    private static let tinkID = systemSoundID(for: "Tink")

    /// Play a short "pop" sound when recording starts.
    /// Calls the completion handler after the sound finishes so the caller
    /// can start the audio engine without cutting off the sound.
    static func playStart(completion: (() -> Void)? = nil) {
        if let completion = completion {
            AudioServicesPlaySystemSoundWithCompletion(popID) {
                DispatchQueue.main.async { completion() }
            }
        } else {
            AudioServicesPlaySystemSound(popID)
        }
    }

    /// Play a "done" sound when recording stops.
    static func playStop() {
        AudioServicesPlaySystemSound(tinkID)
    }

    /// Look up a system sound file and register it with AudioServices.
    private static func systemSoundID(for name: String) -> SystemSoundID {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        return soundID
    }
}

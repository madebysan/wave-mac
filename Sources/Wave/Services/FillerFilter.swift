import Foundation

// Removes filler words from transcription output.
// Conservative approach — only removes unambiguous fillers.
enum FillerFilter {

    /// Whether filler removal is enabled (defaults to true).
    static var isEnabled: Bool {
        // Default to true if never set
        UserDefaults.standard.object(forKey: "removeFillers") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "removeFillers")
    }

    // Single-word fillers — always safe to remove
    private static let singleWordFillers = [
        "um", "uh", "er", "hmm", "umm", "uhh", "erm", "hm",
    ]

    // Multi-word fillers — only remove when they appear as standalone phrases
    private static let phraseFillers = [
        "you know", "I mean",
    ]

    /// Remove filler words from the given text.
    /// Returns the original text if filler removal is disabled.
    static func filter(_ text: String) -> String {
        guard isEnabled else { return text }
        var result = text

        // Remove phrase fillers first (before single words break them up)
        for phrase in phraseFillers {
            // Case-insensitive, word-boundary matching
            // Handle with and without surrounding commas
            let patterns = [
                "\\b\(phrase),?\\s*",     // "you know, " or "you know "
                ",?\\s*\\b\(phrase)\\b",  // ", you know"
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: " "
                    )
                }
            }
        }

        // Remove single-word fillers
        for word in singleWordFillers {
            // Match the word at word boundaries, optionally followed by a comma
            let pattern = "\\b\(word)\\b,?\\s*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: " "
                )
            }
        }

        // Clean up: collapse multiple spaces, trim
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fix capitalization if the first word was removed
        if let first = result.first, first.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }

        return result
    }
}

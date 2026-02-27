import Foundation

// Removes filler words, context-dependent fillers, and stutters from transcription output.
// Uses a multi-pass approach: phrase fillers → single-word fillers → context fillers → stutter removal → cleanup.
enum FillerFilter {

    /// Whether filler removal is enabled (defaults to true).
    static var isEnabled: Bool {
        // Default to true if never set
        UserDefaults.standard.object(forKey: "removeFillers") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "removeFillers")
    }

    // Always-remove fillers — unambiguous filler sounds
    private static let singleWordFillers = [
        "um", "uh", "er", "hmm", "umm", "uhh", "erm", "hm",
    ]

    // Phrase fillers — multi-word fillers to remove as standalone phrases
    private static let phraseFillers = [
        "you know", "I mean", "sort of", "kind of", "I guess", "you see",
    ]

    // Context-dependent fillers — only remove at sentence/clause boundaries
    // (start of string or after comma) to avoid false positives like "I like pizza"
    private static let contextFillers = [
        "like", "so", "basically", "literally", "right", "actually", "well", "okay",
    ]

    /// Remove filler words and stutters from the given text.
    /// Returns the original text if filler removal is disabled.
    static func filter(_ text: String) -> String {
        guard isEnabled else { return text }
        var result = text

        // Pass 1: Remove phrase fillers (before single words break them up)
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

        // Pass 2: Remove always-remove single-word fillers
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

        // Pass 3: Remove context-dependent fillers only at clause boundaries
        // Match at start of string or after a comma — avoids removing "like" in "I like pizza"
        for word in contextFillers {
            let patterns = [
                "^\\s*\(word),?\\s+",           // At start of string: "Like, I went..." → "I went..."
                ",\\s*\(word),?\\s+",            // After comma: ", like, I went..." → ", I went..."
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    // Use appropriate replacement based on pattern
                    let template = pattern.hasPrefix("^") ? "" : ", "
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: template
                    )
                }
            }
        }

        // Pass 4: Remove stutters/repeated words — "I I I went" → "I went", "the the" → "the"
        if let stutterRegex = try? NSRegularExpression(pattern: "\\b(\\w+)(\\s+\\1)+\\b", options: .caseInsensitive) {
            result = stutterRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }

        // Cleanup: collapse multiple spaces, trim
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fix capitalization if the first word was removed
        if let first = result.first, first.isLowercase {
            result = result.prefix(1).uppercased() + result.dropFirst()
        }

        return result
    }
}

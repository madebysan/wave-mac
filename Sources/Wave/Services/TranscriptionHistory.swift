import Foundation

// Stores recent transcriptions with timestamps.
// Persisted to a JSON file in the app support directory.
// Can be disabled in Settings.
class TranscriptionHistory {

    static let shared = TranscriptionHistory()

    struct Entry: Codable {
        let text: String
        let date: Date
        let id: UUID
    }

    private(set) var entries: [Entry] = []
    private let maxEntries = 100

    /// Whether history recording is enabled (defaults to true).
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "saveHistory") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "saveHistory")
    }

    private var historyFile: URL {
        FileLocations.appSupportDir.appendingPathComponent("history.json")
    }

    private init() {
        load()
    }

    /// Add a new transcription to history.
    func add(_ text: String) {
        guard TranscriptionHistory.isEnabled else { return }

        let entry = Entry(text: text, date: Date(), id: UUID())
        entries.insert(entry, at: 0)

        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        save()
    }

    /// Remove all history.
    func clearAll() {
        entries.removeAll()
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: historyFile.path) else { return }
        do {
            let data = try Data(contentsOf: historyFile)
            entries = try JSONDecoder().decode([Entry].self, from: data)
        } catch {
            NSLog("Wave: Failed to load history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            try data.write(to: historyFile, options: .atomic)
        } catch {
            NSLog("Wave: Failed to save history: \(error.localizedDescription)")
        }
    }
}

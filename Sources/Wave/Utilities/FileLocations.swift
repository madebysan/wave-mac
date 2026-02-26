import Foundation

// Centralized path constants for all files Wave creates.
// Models are stored in ~/Library/Application Support/Wave/Models/
enum FileLocations {

    // MARK: - Base directories

    /// ~/Library/Application Support/Wave/
    static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Wave")
    }()

    /// ~/Library/Application Support/Wave/Models/
    static let modelsDir: URL = {
        appSupportDir.appendingPathComponent("Models")
    }()

    // MARK: - Setup

    /// Create all required directories if they don't exist yet.
    static func ensureDirectoriesExist() {
        let fm = FileManager.default
        for dir in [appSupportDir, modelsDir] {
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
}

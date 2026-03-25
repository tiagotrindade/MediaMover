import Foundation

// MARK: - Log Entry

struct LogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let action: String       // "copy", "move", "undo-delete", "undo-move", "verify", "skip", "error"
    let sourcePath: String
    let destinationPath: String
    let status: LogStatus
    let details: String?

    init(action: String, sourcePath: String, destinationPath: String = "", status: LogStatus, details: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.action = action
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.status = status
        self.details = details
    }
}

enum LogStatus: String, Codable, Sendable {
    case success
    case warning
    case error
    case info
}

// MARK: - Activity Logger

actor ActivityLogger {

    static let shared = ActivityLogger()

    private var entries: [LogEntry] = []
    private let maxMemoryEntries = 5_000
    private let logFileURL: URL

    // C-05, M-32 FIX: Safe unwrap and log init failures
    private init() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("FolioSort/activity.log")
            print("[ActivityLogger] Warning: Using temp directory for log file")
            return
        }
        let appDir = support.appendingPathComponent("FolioSort")
        do {
            try FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            print("[ActivityLogger] Warning: Failed to create log directory: \(error.localizedDescription)")
        }
        logFileURL = appDir.appendingPathComponent("activity.log")
    }

    func log(_ entry: LogEntry) {
        entries.append(entry)

        // M-31 FIX: Flush trimmed entries to disk before dropping
        if entries.count > maxMemoryEntries {
            // Entries being trimmed are already on disk via appendToFile,
            // so we can safely drop from memory
            entries = Array(entries.suffix(maxMemoryEntries))
        }

        // Append to file
        appendToFile(entry)
    }

    func log(action: String, source: String, destination: String = "", status: LogStatus, details: String? = nil) {
        let entry = LogEntry(action: action, sourcePath: source, destinationPath: destination, status: status, details: details)
        log(entry)
    }

    func getEntries() -> [LogEntry] {
        entries
    }

    func getRecentEntries(count: Int = 200) -> [LogEntry] {
        Array(entries.suffix(count))
    }

    func clearLog() {
        entries.removeAll()
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
    }

    func exportLog() -> URL {
        logFileURL
    }

    // MARK: - Private

    // H-11 FIX: Static formatter to avoid re-creation on every log call
    private let isoFormatter = ISO8601DateFormatter()

    private func appendToFile(_ entry: LogEntry) {
        let formatter = isoFormatter
        let line = "[\(formatter.string(from: entry.timestamp))] [\(entry.status.rawValue.uppercased())] [\(entry.action)] \(entry.sourcePath)"
            + (entry.destinationPath.isEmpty ? "" : " -> \(entry.destinationPath)")
            + (entry.details.map { " | \($0)" } ?? "")
            + "\n"

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let handle = try? FileHandle(forWritingTo: logFileURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
}

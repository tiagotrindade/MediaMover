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

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = support.appendingPathComponent("FolioSort")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        logFileURL = appDir.appendingPathComponent("activity.log")
    }

    func log(_ entry: LogEntry) {
        entries.append(entry)

        // Trim memory
        if entries.count > maxMemoryEntries {
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

    private func appendToFile(_ entry: LogEntry) {
        let formatter = ISO8601DateFormatter()
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

import Foundation

// MARK: - Single File Operation Record (for undo)

struct FileOperationRecord: Codable, Sendable {
    let action: OperationMode      // .copy or .move
    let sourcePath: String          // original source path
    let destinationPath: String     // where the file ended up
    let timestamp: Date
}

// MARK: - Batch Operation (groups all files from one "Organize" run)

struct BatchOperation: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let mode: OperationMode
    let fileCount: Int
    let records: [FileOperationRecord]

    init(mode: OperationMode, records: [FileOperationRecord]) {
        self.id = UUID()
        self.timestamp = Date()
        self.mode = mode
        self.fileCount = records.count
        self.records = records
    }
}

// MARK: - Operation History (persisted)

actor OperationHistory {

    static let shared = OperationHistory()

    private var batches: [BatchOperation] = []
    private let historyURL: URL

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = support.appendingPathComponent("FolioSort")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        let url = appDir.appendingPathComponent("undo_history.json")
        historyURL = url

        // Load from disk inline (nonisolated init context)
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([BatchOperation].self, from: data) {
            batches = decoded
        }
    }

    func addBatch(_ batch: BatchOperation) {
        batches.append(batch)
        // Keep last 50 batches
        if batches.count > 50 {
            batches = Array(batches.suffix(50))
        }
        saveToDisk()
    }

    func getLastBatch() -> BatchOperation? {
        batches.last
    }

    func getAllBatches() -> [BatchOperation] {
        batches
    }

    func removeLastBatch() {
        guard !batches.isEmpty else { return }
        batches.removeLast()
        saveToDisk()
    }

    func canUndo() -> Bool {
        !batches.isEmpty
    }

    // MARK: - Undo Logic

    func undoLastBatch() async -> (undone: Int, errors: Int) {
        guard let batch = batches.last else { return (0, 0) }

        let fm = FileManager.default
        let logger = ActivityLogger.shared
        var undoneCount = 0
        var errorCount = 0

        for record in batch.records.reversed() {
            let destURL = URL(fileURLWithPath: record.destinationPath)
            let sourceURL = URL(fileURLWithPath: record.sourcePath)

            do {
                switch record.action {
                case .copy:
                    // Undo copy = delete the copied file
                    if fm.fileExists(atPath: destURL.path) {
                        try fm.removeItem(at: destURL)
                        await logger.log(action: "undo-delete", source: record.destinationPath, status: .success, details: "Removed copied file")
                    }
                    undoneCount += 1

                case .move:
                    // Undo move = move back to original location
                    if fm.fileExists(atPath: destURL.path) {
                        let parentDir = sourceURL.deletingLastPathComponent()
                        try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                        try fm.moveItem(at: destURL, to: sourceURL)
                        await logger.log(action: "undo-move", source: record.destinationPath, destination: record.sourcePath, status: .success, details: "Moved back to original location")
                    }
                    undoneCount += 1
                }
            } catch {
                errorCount += 1
                await logger.log(action: "undo-error", source: record.destinationPath, status: .error, details: error.localizedDescription)
            }
        }

        // Clean up empty directories created during the original operation
        cleanupEmptyDirectories(from: batch)

        removeLastBatch()
        return (undoneCount, errorCount)
    }

    // MARK: - Private

    private func cleanupEmptyDirectories(from batch: BatchOperation) {
        let fm = FileManager.default
        var directories = Set<String>()

        for record in batch.records {
            let destURL = URL(fileURLWithPath: record.destinationPath)
            directories.insert(destURL.deletingLastPathComponent().path)
        }

        // Sort by depth (deepest first) to clean up leaf directories first
        let sorted = directories.sorted { $0.components(separatedBy: "/").count > $1.components(separatedBy: "/").count }

        for dirPath in sorted {
            let dirURL = URL(fileURLWithPath: dirPath)
            if let contents = try? fm.contentsOfDirectory(atPath: dirPath), contents.isEmpty {
                try? fm.removeItem(at: dirURL)
            }
        }
    }

    private func saveToDisk() {
        guard let data = try? JSONEncoder().encode(batches) else { return }
        try? data.write(to: historyURL)
    }
}

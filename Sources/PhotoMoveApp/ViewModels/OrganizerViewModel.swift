import SwiftUI
import AppKit

@Observable
@MainActor
final class OrganizerViewModel {

    // MARK: - Settings

    var sourceURL: URL?
    var destinationURL: URL?
    var pattern: OrganizationPattern = .yearMonthDay
    var operationMode: OperationMode = .copy
    var includePhotos: Bool = true
    var includeVideos: Bool = true

    // Duplicate handling
    var duplicateStrategy: DuplicateStrategy = .automatic
    var duplicateAction: DuplicateAction = .rename

    // Integrity verification
    var verifyIntegrity: Bool = true
    var hashAlgorithm: HashAlgorithm = .xxhash64

    // MARK: - State

    var isScanning: Bool = false
    var isProcessing: Bool = false
    var isUndoing: Bool = false
    var progress: Double = 0
    var currentFileIndex: Int = 0
    var totalFiles: Int = 0
    var currentFileName: String = ""
    var discoveredFiles: [MediaFile] = []
    var result: OperationResult?
    var scanMessage: String = ""
    var canUndo: Bool = false

    // Duplicate ask dialog
    var showDuplicateDialog: Bool = false
    var duplicateSourceName: String = ""
    var duplicateSourceSize: Int64 = 0
    var duplicateExistingName: String = ""
    var duplicateExistingSize: Int64 = 0
    private var duplicateContinuation: CheckedContinuation<DuplicateAction?, Never>?
    var applyDuplicateToAll: Bool = false
    private var rememberedDuplicateAction: DuplicateAction?

    // Log
    var showLogSheet: Bool = false
    var logEntries: [LogEntry] = []

    // Undo result
    var undoMessage: String?

    // MARK: - Folder Selection

    func selectSource() {
        if let url = pickFolder(title: "Select Source Folder") {
            sourceURL = url
            discoveredFiles = []
            result = nil
        }
    }

    func selectDestination() {
        if let url = pickFolder(title: "Select Destination Folder") {
            destinationURL = url
            result = nil
        }
    }

    // MARK: - Scan

    func scanFiles() async {
        guard let source = sourceURL else { return }
        isScanning = true
        discoveredFiles = []
        result = nil
        scanMessage = "Scanning files..."

        let urls = FileEnumerator.enumerateMedia(
            in: source,
            includePhotos: includePhotos,
            includeVideos: includeVideos
        )

        totalFiles = urls.count
        scanMessage = "Reading metadata for \(urls.count) files..."

        var files: [MediaFile] = []
        let batchSize = 8

        for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, urls.count)
            let batch = Array(urls[batchStart..<batchEnd])

            let batchResults = await withTaskGroup(of: MediaFile?.self) { group in
                for url in batch {
                    group.addTask {
                        await Self.buildMediaFile(from: url)
                    }
                }
                var results: [MediaFile] = []
                for await mediaFile in group {
                    if let mf = mediaFile {
                        results.append(mf)
                    }
                }
                return results
            }
            files.append(contentsOf: batchResults)
            scanMessage = "Read metadata: \(files.count) / \(urls.count)"
        }

        discoveredFiles = files.sorted { $0.effectiveDate > $1.effectiveDate }
        isScanning = false
        scanMessage = ""
    }

    // MARK: - Organize

    func startOrganizing() async {
        guard !discoveredFiles.isEmpty, let destination = destinationURL else { return }
        isProcessing = true
        progress = 0
        currentFileIndex = 0
        result = nil
        rememberedDuplicateAction = nil
        applyDuplicateToAll = false

        let organizer = FileOrganizer()
        let files = discoveredFiles

        let config = OrganizerConfig(
            mode: operationMode,
            pattern: pattern,
            duplicateStrategy: duplicateStrategy,
            duplicateAction: duplicateAction,
            verifyIntegrity: verifyIntegrity,
            hashAlgorithm: hashAlgorithm
        )

        // Duplicate resolver for "Ask" mode
        let resolver: DuplicateResolver = { [weak self] sourceName, sourceSize, existingName, existingSize in
            // Check if user chose "apply to all" — reuse previous choice
            let remembered: DuplicateAction? = await MainActor.run {
                self?.rememberedDuplicateAction
            }
            if let remembered { return remembered }

            // Otherwise ask the user
            guard let self else { return nil }
            return await self.askUserAboutDuplicate(
                sourceName: sourceName,
                sourceSize: sourceSize,
                existingName: existingName,
                existingSize: existingSize
            )
        }

        let (opResult, records) = await organizer.organize(
            files: files,
            destination: destination,
            config: config,
            duplicateResolver: config.duplicateStrategy == .ask ? resolver : nil,
            progressCallback: { [weak self] current, total, fileName in
                await MainActor.run {
                    self?.currentFileIndex = current
                    self?.totalFiles = total
                    self?.currentFileName = fileName
                    self?.progress = total > 0 ? Double(current) / Double(total) : 0
                }
            }
        )

        // Save operation for undo
        if !records.isEmpty {
            let batch = BatchOperation(mode: operationMode, records: records)
            await OperationHistory.shared.addBatch(batch)
        }

        result = opResult
        isProcessing = false
        await refreshUndoState()
    }

    // MARK: - Undo

    func performUndo() async {
        isUndoing = true
        undoMessage = nil

        let (undone, errors) = await OperationHistory.shared.undoLastBatch()

        if errors > 0 {
            undoMessage = "Undo complete: \(undone) files restored, \(errors) errors"
        } else {
            undoMessage = "Undo complete: \(undone) files restored successfully"
        }

        isUndoing = false
        await refreshUndoState()

        // Clear message after 4 seconds
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        undoMessage = nil
    }

    func refreshUndoState() async {
        canUndo = await OperationHistory.shared.canUndo()
    }

    // MARK: - Activity Log

    func loadLog() async {
        logEntries = await ActivityLogger.shared.getRecentEntries(count: 500)
    }

    func clearLog() async {
        await ActivityLogger.shared.clearLog()
        logEntries = []
    }

    func exportLogFile() async -> URL? {
        return await ActivityLogger.shared.exportLog()
    }

    // MARK: - Duplicate Ask Dialog

    private func askUserAboutDuplicate(
        sourceName: String,
        sourceSize: Int64,
        existingName: String,
        existingSize: Int64
    ) async -> DuplicateAction? {
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.duplicateSourceName = sourceName
                self.duplicateSourceSize = sourceSize
                self.duplicateExistingName = existingName
                self.duplicateExistingSize = existingSize
                self.duplicateContinuation = continuation
                self.showDuplicateDialog = true
            }
        }
    }

    func resolveDuplicate(action: DuplicateAction?) {
        if applyDuplicateToAll, let action {
            rememberedDuplicateAction = action
        }
        showDuplicateDialog = false
        duplicateContinuation?.resume(returning: action)
        duplicateContinuation = nil
    }

    // MARK: - Reset

    func reset() {
        result = nil
        discoveredFiles = []
        progress = 0
        currentFileIndex = 0
        currentFileName = ""
    }

    // MARK: - Private

    private func pickFolder(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private static func buildMediaFile(from url: URL) async -> MediaFile? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }

        let modDate = (attrs[.modificationDate] as? Date) ?? Date()
        let fileSize = (attrs[.size] as? Int64) ?? 0

        let ext = url.pathExtension.lowercased()
        let mediaType = SupportedFormats.mediaType(for: ext)

        let dateTaken: Date?
        let cameraModel: String?

        switch mediaType {
        case .photo:
            let meta = MetadataExtractor.extractPhotoMetadata(from: url)
            dateTaken = meta.dateTaken
            cameraModel = meta.cameraModel
        case .video:
            let meta = await MetadataExtractor.extractVideoMetadata(from: url)
            dateTaken = meta.dateTaken
            cameraModel = meta.cameraModel
        case nil:
            return nil
        }

        return MediaFile(
            url: url,
            dateTaken: dateTaken,
            cameraModel: cameraModel,
            fileModificationDate: modDate,
            fileSize: fileSize
        )
    }
}

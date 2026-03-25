import SwiftUI
import AppKit

@Observable
@MainActor
final class OrganizerViewModel {

    // MARK: - Settings

    var sourceURL: URL?
    var destinationURL: URL?
    var pattern: OrganizationPattern = .yearMonthDayFlat
    var operationMode: OperationMode = .copy
    var includePhotos: Bool = true
    var includeVideos: Bool = true
    var includeOtherFiles: Bool = false
    var includeSubfolders: Bool = true

    // Date fallback
    var dateFallback: DateFallback = .creationDate

    // UI preferences
    var showAdvancedFolderOptions: Bool = false
    var showThumbnails: Bool = true

    // Video subfolder
    var separateVideos: Bool = true

    // Rename with date prefix
    var renameWithDate: Bool = false


    // Duplicate handling
    var duplicateStrategy: DuplicateStrategy = .ask
    var duplicateAction: DuplicateAction = .rename

    // Integrity verification
    var verifyIntegrity: Bool = true
    var hashAlgorithm: HashAlgorithm = .xxhash64

    // MARK: - Phase 2: Template & Profiles

    /// Custom folder template string. Overrides the legacy `pattern` enum.
    var folderTemplate: String = "{YYYY}_{MM}_{DD}"

    /// Template validation errors (live feedback in UI).
    var templateValidation: TemplateValidation = .valid

    /// Whether GPS reverse geocoding is enabled.
    var geocodingEnabled: Bool = true

    /// Geocoding progress message.
    var geocodingMessage: String = ""

    // MARK: - State

    var isScanning: Bool = false
    var isProcessing: Bool = false
    var isUndoing: Bool = false
    var progress: Double = 0
    var currentFileIndex: Int = 0
    var totalFiles: Int = 0
    var currentFileName: String = ""
    var discoveredFiles: [MediaFile] = []
    var previewItems: [MoverPreview] = []
    var result: OperationResult?
    var scanMessage: String = ""

    // Progress ETA
    var filesPerSecond: Double = 0
    var estimatedTimeRemaining: TimeInterval = 0
    private var operationStartTime: Date?
    private var currentTask: Task<Void, Never>?

    struct MoverPreview: Identifiable {
        let id = UUID()
        let fileName: String
        let destinationSubpath: String
        let mediaType: MediaType?
    }
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

    // Pro gate alerts
    var showFileLimitAlert: Bool = false
    var fileLimitAlertCount: Int = 0
    var showUpgradeSheet: Bool = false

    // MARK: - Cloud/NAS Import (Pro)

    var sourceVolumeType: VolumeType = .local
    var destVolumeType: VolumeType = .local
    var isDownloadingiCloud: Bool = false
    var iCloudDownloadProgress: Double = 0
    var iCloudFilesToDownload: Int = 0
    var transferSpeedFormatted: String = ""
    var showDisconnectAlert: Bool = false
    var showSpaceWarning: Bool = false
    var availableSpaceFormatted: String = ""
    var totalFileSizeFormatted: String = ""
    private var volumeMonitorTask: Task<Void, Never>?
    private let resilientOperator = ResilientFileOperator()

    // MARK: - Folder Selection

    func selectSource() {
        if let url = pickFolder(title: "Select Source Folder") {
            let volType = VolumeManager.shared.volumeType(for: url)

            // Gate network/iCloud behind Pro
            if volType != .local && !ProManager.shared.isPro {
                showUpgradeSheet = true
                return
            }

            sourceURL = url
            sourceVolumeType = volType
            discoveredFiles = []
            result = nil
        }
    }

    func selectDestination() {
        if let url = pickFolder(title: "Select Destination Folder") {
            let volType = VolumeManager.shared.volumeType(for: url)

            // Gate network/iCloud behind Pro
            if volType != .local && !ProManager.shared.isPro {
                showUpgradeSheet = true
                return
            }

            destinationURL = url
            destVolumeType = volType
            result = nil

            // Check available space
            updateAvailableSpace()
        }
    }

    /// Updates the available space display for the destination volume.
    private func updateAvailableSpace() {
        guard let dest = destinationURL else {
            availableSpaceFormatted = ""
            showSpaceWarning = false
            return
        }
        if let space = VolumeManager.shared.availableSpace(at: dest) {
            availableSpaceFormatted = VolumeManager.formatBytes(space)
            // Warn if less than 1 GB
            showSpaceWarning = space < 1_073_741_824
        } else {
            availableSpaceFormatted = ""
            showSpaceWarning = false
        }
    }

    // MARK: - Scan

    func startScan() {
        currentTask = Task { await scanFiles() }
    }

    func scanFiles() async {
        guard let source = sourceURL else { return }
        isScanning = true
        discoveredFiles = []
        previewItems = []
        result = nil
        scanMessage = "Scanning files..."
        operationStartTime = Date()

        let urls = FileEnumerator.enumerateMedia(
            in: source,
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            includeOtherFiles: includeOtherFiles,
            includeSubfolders: includeSubfolders
        )

        totalFiles = urls.count
        currentFileIndex = 0
        progress = 0
        scanMessage = "Reading metadata for \(urls.count) files..."

        var files: [MediaFile] = []
        let batchSize = 8

        for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
            if Task.isCancelled { break }
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
            currentFileIndex = files.count
            progress = urls.count > 0 ? Double(files.count) / Double(urls.count) : 0
            updateETA(processed: files.count, total: urls.count)
            scanMessage = "Read metadata: \(files.count) / \(urls.count)"
        }

        if !Task.isCancelled {
            // Tag volume type on each file
            let volType = sourceVolumeType
            for i in files.indices {
                files[i].volumeType = volType
                if volType == .iCloud {
                    files[i].iCloudStatus = VolumeManager.shared.iCloudDownloadStatus(for: files[i].url)
                }
            }

            // iCloud pre-download phase: download not-yet-local files
            if volType == .iCloud {
                let notDownloaded = files.filter { $0.iCloudStatus == .notDownloaded }
                if !notDownloaded.isEmpty {
                    isDownloadingiCloud = true
                    iCloudFilesToDownload = notDownloaded.count
                    iCloudDownloadProgress = 0
                    scanMessage = "Downloading \(notDownloaded.count) files from iCloud..."

                    _ = await VolumeManager.shared.downloadICloudFiles(
                        notDownloaded.map(\.url)
                    ) { [weak self] downloaded, total in
                        await MainActor.run {
                            self?.iCloudDownloadProgress = total > 0 ? Double(downloaded) / Double(total) : 0
                            self?.scanMessage = "Downloading from iCloud: \(downloaded)/\(total)"
                        }
                    }

                    // Update statuses after download
                    for i in files.indices where files[i].iCloudStatus == .notDownloaded {
                        files[i].iCloudStatus = VolumeManager.shared.iCloudDownloadStatus(for: files[i].url)
                    }
                    isDownloadingiCloud = false
                }
            }

            // Reverse geocode GPS coordinates if enabled (Pro only)
            let hasGPSFiles = files.contains(where: { $0.hasGPS })
            let canGeocode = geocodingEnabled && ProManager.shared.isPro
            if canGeocode && hasGPSFiles {
                let gpsCount = files.filter(\.hasGPS).count
                scanMessage = "Resolving locations (0/\(gpsCount))..."
                geocodingMessage = "Resolving GPS locations..."
                await GeocodingService.shared.resolveLocations(for: &files) { [weak self] resolved, total in
                    await MainActor.run {
                        self?.scanMessage = "Resolving locations (\(resolved)/\(total))..."
                    }
                }
                geocodingMessage = ""
            }

            discoveredFiles = files.sorted {
                ($0.effectiveDate() ?? .distantPast) > ($1.effectiveDate() ?? .distantPast)
            }
            generatePreview()
        }
        isScanning = false
        scanMessage = ""
        operationStartTime = nil
    }

    // MARK: - Preview Generation

    /// The 3 Free folder templates.
    static let freeFolderTemplates: Set<String> = [
        "{YYYY}/{MM}/{DD}",
        "{YYYY}/{MM}",
        "{YYYY}_{MM}_{DD}",
    ]

    func generatePreview() {
        // Enforce Free folder template if not Pro
        if !ProManager.shared.isPro {
            if !Self.freeFolderTemplates.contains(folderTemplate) {
                folderTemplate = "{YYYY}/{MM}/{DD}"
            }
        }

        // Validate template
        templateValidation = TemplateEngine.validate(folderTemplate)

        var previews: [MoverPreview] = []
        let tokens = TemplateEngine.parse(folderTemplate)

        for (index, file) in discoveredFiles.enumerated() {
            let date = file.effectiveDate(fallback: dateFallback)
            var subpath: String

            if date != nil {
                // Use template engine for folder path
                let context = file.templateContext(fallback: dateFallback, sequenceNumber: index + 1)
                subpath = TemplateEngine.evaluate(tokens: tokens, context: context)

                // Add video subfolder
                if separateVideos && file.mediaType == .video {
                    subpath += "/Videos"
                }
            } else {
                subpath = "No Date"
            }

            var fileName = file.fileName
            if renameWithDate, let date {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC")!
                let y = cal.component(.year, from: date)
                let mo = cal.component(.month, from: date)
                let d = cal.component(.day, from: date)
                let h = cal.component(.hour, from: date)
                let mi = cal.component(.minute, from: date)
                let s = cal.component(.second, from: date)
                let ms = cal.component(.nanosecond, from: date) / 1_000_000
                let prefix = String(format: "%04d%02d%02d_%02d%02d%02d%03d", y, mo, d, h, mi, s, ms)
                fileName = "\(prefix)_\(file.fileName)"
            }

            previews.append(MoverPreview(
                fileName: fileName,
                destinationSubpath: subpath,
                mediaType: file.mediaType
            ))
        }
        previewItems = previews
    }

    // MARK: - Organize

    func beginOrganizing() {
        let isPro = ProManager.shared.isPro

        // Filter out Pro-only files in Free mode
        var filesToProcess = discoveredFiles
        if !isPro {
            filesToProcess = filesToProcess.filter { !$0.requiresPro }
        }

        // Check file limit in Free mode
        if !isPro && filesToProcess.count > FeatureGate.freeFileLimit {
            fileLimitAlertCount = filesToProcess.count
            showFileLimitAlert = true
            return
        }

        currentTask = Task { await startOrganizing() }
    }

    /// Called when user chooses "Continue with first 100" from the file limit alert.
    func beginOrganizingWithLimit() {
        currentTask = Task { await startOrganizing(applyFreeLimit: true) }
    }

    func startOrganizing(applyFreeLimit: Bool = false) async {
        guard !discoveredFiles.isEmpty, let destination = destinationURL else { return }

        let isPro = ProManager.shared.isPro

        // Apply Pro gates to the file list
        var filesToOrganize = discoveredFiles
        if !isPro {
            filesToOrganize = filesToOrganize.filter { !$0.requiresPro }
            if applyFreeLimit && filesToOrganize.count > FeatureGate.freeFileLimit {
                filesToOrganize = Array(filesToOrganize.prefix(FeatureGate.freeFileLimit))
            }
        }

        // Check available space before starting
        updateAvailableSpace()
        if let dest = destinationURL, destVolumeType != .iCloud {
            let totalSize = filesToOrganize.reduce(Int64(0)) { $0 + $1.fileSize }
            totalFileSizeFormatted = VolumeManager.formatBytes(totalSize)
            if let available = VolumeManager.shared.availableSpace(at: dest), totalSize > available {
                showSpaceWarning = true
                return
            }
        }

        isProcessing = true
        progress = 0
        currentFileIndex = 0
        result = nil
        rememberedDuplicateAction = nil
        applyDuplicateToAll = false
        operationStartTime = Date()
        filesPerSecond = 0
        estimatedTimeRemaining = 0
        transferSpeedFormatted = ""

        // Start volume monitoring for network operations
        let isNetworkOp = sourceVolumeType == .network || destVolumeType == .network
        if isNetworkOp, let monitorURL = destinationURL ?? sourceURL {
            volumeMonitorTask = VolumeManager.shared.monitorVolume(
                at: monitorURL,
                onDisconnect: { [weak self] in
                    await MainActor.run {
                        self?.showDisconnectAlert = true
                    }
                    await self?.resilientOperator.pause()
                },
                onReconnect: { [weak self] in
                    await MainActor.run {
                        self?.showDisconnectAlert = false
                    }
                    await self?.resilientOperator.resume()
                }
            )
        }

        // Reset speed tracking
        await resilientOperator.resetTracking()

        let organizer = FileOrganizer()
        let files = filesToOrganize

        let config = OrganizerConfig(
            mode: operationMode,
            pattern: pattern,
            duplicateStrategy: duplicateStrategy,
            duplicateAction: duplicateAction,
            verifyIntegrity: verifyIntegrity,
            hashAlgorithm: hashAlgorithm,
            dateFallback: dateFallback,
            separateVideos: separateVideos,
            renameWithDate: renameWithDate,
            separateByCamera: false,
            folderTemplate: folderTemplate,
            isNetworkVolume: isNetworkOp
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
            resilientOperator: isNetworkOp ? resilientOperator : nil,
            progressCallback: { [weak self] current, total, fileName in
                let speed = await self?.resilientOperator.formattedSpeed ?? ""
                await MainActor.run {
                    self?.currentFileIndex = current
                    self?.totalFiles = total
                    self?.currentFileName = fileName
                    self?.progress = total > 0 ? Double(current) / Double(total) : 0
                    self?.updateETA(processed: current, total: total)
                    if !speed.isEmpty {
                        self?.transferSpeedFormatted = speed
                    }
                }
            }
        )

        // Stop volume monitoring
        volumeMonitorTask?.cancel()
        volumeMonitorTask = nil

        // Save operation for undo
        if !records.isEmpty {
            let batch = BatchOperation(mode: operationMode, records: records)
            await OperationHistory.shared.addBatch(batch)
        }

        if !Task.isCancelled {
            result = opResult
        }
        isProcessing = false
        operationStartTime = nil
        filesPerSecond = 0
        estimatedTimeRemaining = 0
        transferSpeedFormatted = ""
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

    /// Safety net: resume continuation with nil (skip) if sheet dismissed without resolving
    func safeDismissDuplicate() {
        guard duplicateContinuation != nil else { return }
        resolveDuplicate(action: nil)
    }

    // MARK: - Cancel

    func cancelOperation() {
        currentTask?.cancel()
        currentTask = nil
        volumeMonitorTask?.cancel()
        volumeMonitorTask = nil
    }

    /// Dismiss disconnect alert and cancel the operation.
    func dismissDisconnectAndCancel() {
        showDisconnectAlert = false
        cancelOperation()
    }

    /// Dismiss the space warning and proceed anyway.
    func dismissSpaceWarningAndProceed() {
        showSpaceWarning = false
        currentTask = Task { await startOrganizing() }
    }

    // MARK: - ETA

    private func updateETA(processed: Int, total: Int) {
        guard let start = operationStartTime, processed > 0 else { return }
        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0.001 else { return }
        filesPerSecond = Double(processed) / elapsed
        let remaining = total - processed
        estimatedTimeRemaining = remaining > 0 ? Double(remaining) / filesPerSecond : 0
    }

    // MARK: - Reset

    func reset() {
        result = nil
        discoveredFiles = []
        previewItems = []
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

    static func buildMediaFile(from url: URL) async -> MediaFile? {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path) else { return nil }

        let modDate = (attrs[.modificationDate] as? Date) ?? Date()
        let creationDate = attrs[.creationDate] as? Date
        let fileSize = (attrs[.size] as? Int64) ?? 0

        let ext = url.pathExtension.lowercased()
        let mediaType = SupportedFormats.mediaType(for: ext)
        let isProFormat = SupportedFormats.isProFormat(ext)

        var file: MediaFile

        switch mediaType {
        case .photo:
            let meta = MetadataExtractor.extractExtendedPhotoMetadata(from: url)
            file = MediaFile(
                url: url,
                dateTaken: meta.dateTaken,
                cameraModel: meta.cameraModel,
                fileCreationDate: creationDate,
                fileModificationDate: modDate,
                fileSize: fileSize,
                mediaType: mediaType,
                lensModel: meta.lensModel,
                iso: meta.iso,
                aperture: meta.aperture,
                shutterSpeed: meta.shutterSpeed,
                gpsLatitude: meta.gpsLatitude,
                gpsLongitude: meta.gpsLongitude
            )
        case .video:
            let meta = await MetadataExtractor.extractExtendedVideoMetadata(from: url)
            file = MediaFile(
                url: url,
                dateTaken: meta.dateTaken,
                cameraModel: meta.cameraModel,
                fileCreationDate: creationDate,
                fileModificationDate: modDate,
                fileSize: fileSize,
                mediaType: mediaType,
                gpsLatitude: meta.gpsLatitude,
                gpsLongitude: meta.gpsLongitude
            )
        case .other, nil:
            file = MediaFile(
                url: url,
                dateTaken: nil,
                cameraModel: nil,
                fileCreationDate: creationDate,
                fileModificationDate: modDate,
                fileSize: fileSize,
                mediaType: .other
            )
        }

        // Tag RAW/pro formats so the UI can show a Pro badge
        file.requiresPro = isProFormat

        return file
    }
}

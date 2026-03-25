import SwiftUI
import AppKit

enum RenameMode: String, CaseIterable, Sendable {
    case renameInPlace = "Rename in place"
    case copyToFolder = "Copy to folder"
}

@Observable
@MainActor
final class RenameViewModel {

    // MARK: - Settings

    var sourceURL: URL?
    var destinationURL: URL?
    var pattern: RenamePattern = .dateOriginalName
    var includePhotos: Bool = true
    var includeVideos: Bool = true
    var includeOtherFiles: Bool = false
    var includeSubfolders: Bool = true
    var dateFallback: DateFallback = .creationDate
    var renameMode: RenameMode = .renameInPlace

    // MARK: - Phase 2: Regex Rename

    /// Whether regex rename mode is active (replaces pattern-based rename).
    var useRegexMode: Bool = false

    /// Regex find pattern.
    var regexFind: String = ""

    /// Regex replacement string (supports $1, $2, etc.).
    var regexReplace: String = ""

    /// Regex options.
    var regexCaseInsensitive: Bool = false

    /// Whether to match on the whole filename or just the stem (without extension).
    var regexMatchStemOnly: Bool = true

    /// Regex validation error (shown inline).
    var regexError: String?

    /// Number of files that matched the regex.
    var regexMatchCount: Int = 0

    /// Common regex patterns for the dropdown.
    static let commonRegexPatterns: [(name: String, find: String, replace: String)] = [
        ("Remove prefix IMG_",      "^IMG_",                  ""),
        ("Replace spaces with _",   "\\s+",                   "_"),
        ("Extract date digits",     "(\\d{4})(\\d{2})(\\d{2})", "$1-$2-$3"),
        ("Remove trailing numbers", "_\\d+$",                 ""),
    ]

    // MARK: - State

    var isScanning: Bool = false
    var isRenaming: Bool = false
    var progress: Double = 0
    var currentFileIndex: Int = 0
    var totalFiles: Int = 0
    var currentFileName: String = ""
    var discoveredFiles: [MediaFile] = []
    var previewItems: [RenamePreview] = []
    var renameComplete: Bool = false
    var renamedCount: Int = 0
    var errorCount: Int = 0

    // Progress ETA
    var filesPerSecond: Double = 0
    var estimatedTimeRemaining: TimeInterval = 0
    private var operationStartTime: Date?
    private var currentTask: Task<Void, Never>?

    // Pro gate alerts
    var showFileLimitAlert: Bool = false
    var fileLimitAlertCount: Int = 0
    var showUpgradeSheet: Bool = false

    struct RenamePreview: Identifiable {
        let id = UUID()
        let originalName: String
        let newName: String
        let file: MediaFile
        var matchRanges: [Range<String.Index>] = []
    }

    // MARK: - Folder Selection

    // Cloud/NAS state
    var sourceVolumeType: VolumeType = .local

    func selectSource() {
        let panel = NSOpenPanel()
        panel.title = "Select Folder to Rename Files"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let volType = VolumeManager.shared.volumeType(for: url)
        if volType != .local && !ProManager.shared.isPro {
            showUpgradeSheet = true
            return
        }

        sourceURL = url
        sourceVolumeType = volType
        discoveredFiles = []
        previewItems = []
        renameComplete = false
    }

    func selectDestination() {
        let panel = NSOpenPanel()
        panel.title = "Select Destination Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let volType = VolumeManager.shared.volumeType(for: url)
        if volType != .local && !ProManager.shared.isPro {
            showUpgradeSheet = true
            return
        }

        destinationURL = url
    }

    // MARK: - Scan + Preview

    func startScan() {
        currentTask = Task { await scanAndPreview() }
    }

    func scanAndPreview() async {
        guard let source = sourceURL else { return }
        isScanning = true
        discoveredFiles = []
        previewItems = []
        renameComplete = false
        operationStartTime = Date()
        currentFileIndex = 0
        progress = 0

        let urls = FileEnumerator.enumerateMedia(
            in: source,
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            includeOtherFiles: includeOtherFiles,
            includeSubfolders: includeSubfolders
        )

        totalFiles = urls.count

        var files: [MediaFile] = []
        let batchSize = 8

        for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
            if Task.isCancelled { break }
            let batchEnd = min(batchStart + batchSize, urls.count)
            let batch = Array(urls[batchStart..<batchEnd])

            let batchResults = await withTaskGroup(of: MediaFile?.self) { group in
                for url in batch {
                    group.addTask { await Self.buildMediaFile(from: url) }
                }
                var results: [MediaFile] = []
                for await mf in group { if let mf { results.append(mf) } }
                return results
            }
            files.append(contentsOf: batchResults)
            currentFileIndex = files.count
            progress = urls.count > 0 ? Double(files.count) / Double(urls.count) : 0
            updateETA(processed: files.count, total: urls.count)
        }

        if !Task.isCancelled {
            files.sort { ($0.effectiveDate(fallback: dateFallback) ?? .distantPast) < ($1.effectiveDate(fallback: dateFallback) ?? .distantPast) }
            discoveredFiles = files
            regeneratePreviewFromFiles(files)
        }

        isScanning = false
        operationStartTime = nil
    }

    // MARK: - Regenerate Preview (pattern change only, no rescan)

    func regeneratePreview() {
        // Enforce Free rename patterns if not Pro
        if !ProManager.shared.isPro {
            if !Self.freeRenamePatterns.contains(pattern) {
                pattern = .dateOriginalName
            }
            if useRegexMode {
                useRegexMode = false
            }
        }

        if useRegexMode {
            regenerateRegexPreview()
        } else {
            regeneratePreviewFromFiles(discoveredFiles)
        }
    }

    private func regeneratePreviewFromFiles(_ files: [MediaFile]) {
        var previews: [RenamePreview] = []
        // Track media vs other files separately for sequence numbering
        var mediaSeq = 0
        for file in files {
            let isOther = file.mediaType == .other

            if isOther {
                // Other files: limited rename patterns (only date-based if date available)
                let newName = renameOtherFile(file: file)
                previews.append(RenamePreview(originalName: file.fileName, newName: newName, file: file))
            } else {
                guard let date = file.effectiveDate(fallback: dateFallback) else {
                    // No date — keep original name
                    previews.append(RenamePreview(originalName: file.fileName, newName: file.fileName, file: file))
                    continue
                }
                mediaSeq += 1
                let newName = pattern.rename(
                    originalName: file.fileName,
                    date: date,
                    camera: file.cameraModel,
                    sequenceNumber: mediaSeq
                )
                previews.append(RenamePreview(originalName: file.fileName, newName: newName, file: file))
            }
        }
        previewItems = previews
    }

    // MARK: - Regex Rename Preview

    private func regenerateRegexPreview() {
        regexError = nil
        regexMatchCount = 0

        guard !regexFind.isEmpty else {
            previewItems = discoveredFiles.map {
                RenamePreview(originalName: $0.fileName, newName: $0.fileName, file: $0)
            }
            return
        }

        // Validate regex
        var options: NSRegularExpression.Options = []
        if regexCaseInsensitive { options.insert(.caseInsensitive) }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: regexFind, options: options)
        } catch {
            regexError = error.localizedDescription
            previewItems = discoveredFiles.map {
                RenamePreview(originalName: $0.fileName, newName: $0.fileName, file: $0)
            }
            return
        }

        var previews: [RenamePreview] = []
        var matchCount = 0

        for file in discoveredFiles {
            let ext = (file.fileName as NSString).pathExtension
            let stem = (file.fileName as NSString).deletingPathExtension
            let target = regexMatchStemOnly ? stem : file.fileName
            let range = NSRange(target.startIndex..., in: target)

            let matches = regex.matches(in: target, range: range)
            if !matches.isEmpty { matchCount += 1 }

            let ranges: [Range<String.Index>] = matches.compactMap { Range($0.range, in: target) }

            let replaced = regex.stringByReplacingMatches(in: target, range: range, withTemplate: regexReplace)

            let newName: String
            if regexMatchStemOnly {
                newName = ext.isEmpty ? replaced : "\(replaced).\(ext)"
            } else {
                newName = replaced
            }

            previews.append(RenamePreview(
                originalName: file.fileName,
                newName: newName.isEmpty ? file.fileName : newName,
                file: file,
                matchRanges: ranges
            ))
        }

        regexMatchCount = matchCount
        previewItems = previews
    }

    /// Limited rename for non-media files: only date prefix + original name, using file dates
    private func renameOtherFile(file: MediaFile) -> String {
        guard let date = file.effectiveDate(fallback: dateFallback) else {
            return file.fileName // no date available, keep original
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let y = cal.component(.year, from: date)
        let mo = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let h = cal.component(.hour, from: date)
        let mi = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)

        let ext = (file.fileName as NSString).pathExtension.lowercased()
        let stem = (file.fileName as NSString).deletingPathExtension
        let datePrefix = String(format: "%04d%02d%02d_%02d%02d%02d", y, mo, d, h, mi, s)
        let newStem = "\(datePrefix)_\(stem)"
        return ext.isEmpty ? newStem : "\(newStem).\(ext)"
    }

    // MARK: - Execute Rename

    /// Free rename presets (first 3).
    static let freeRenamePatterns: Set<RenamePattern> = [
        .dateOriginal, .dateOriginalName, .dateOnly
    ]

    func beginRename() {
        let isPro = ProManager.shared.isPro

        // Block regex mode in Free
        if !isPro && useRegexMode {
            showUpgradeSheet = true
            return
        }

        // Filter out Pro-only files in Free mode
        var itemsToRename = previewItems
        if !isPro {
            itemsToRename = itemsToRename.filter { !$0.file.requiresPro }
        }

        // Check file limit in Free mode
        if !isPro && itemsToRename.count > FeatureGate.freeFileLimit {
            fileLimitAlertCount = itemsToRename.count
            showFileLimitAlert = true
            return
        }

        currentTask = Task { await executeRename() }
    }

    /// Called when user chooses "Continue with first 100" from the file limit alert.
    func beginRenameWithLimit() {
        currentTask = Task { await executeRename(applyFreeLimit: true) }
    }

    func executeRename(applyFreeLimit: Bool = false) async {
        guard !previewItems.isEmpty else { return }

        let isPro = ProManager.shared.isPro
        var itemsToProcess = previewItems
        if !isPro {
            itemsToProcess = itemsToProcess.filter { !$0.file.requiresPro }
            if applyFreeLimit && itemsToProcess.count > FeatureGate.freeFileLimit {
                itemsToProcess = Array(itemsToProcess.prefix(FeatureGate.freeFileLimit))
            }
        }

        isRenaming = true
        progress = 0
        renamedCount = 0
        errorCount = 0
        operationStartTime = Date()
        filesPerSecond = 0
        estimatedTimeRemaining = 0

        let fm = FileManager.default
        let total = itemsToProcess.count
        let logger = ActivityLogger.shared
        let isCopy = renameMode == .copyToFolder

        // Create destination if needed
        if isCopy, let dest = destinationURL {
            try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        }

        for (index, item) in itemsToProcess.enumerated() {
            if Task.isCancelled { break }
            currentFileIndex = index + 1
            totalFiles = total
            currentFileName = item.originalName
            progress = Double(index + 1) / Double(total)
            updateETA(processed: index + 1, total: total)

            let targetDir: URL
            if isCopy, let dest = destinationURL {
                targetDir = dest
            } else {
                targetDir = item.file.url.deletingLastPathComponent()
            }

            let newURL = targetDir.appendingPathComponent(item.newName)

            // Skip if name unchanged and not copying
            if !isCopy && item.originalName == item.newName {
                continue
            }

            do {
                // Handle collision
                var target = newURL
                if fm.fileExists(atPath: target.path) {
                    target = uniqueURL(for: target, fm: fm)
                }

                if isCopy {
                    try fm.copyItem(at: item.file.url, to: target)
                } else {
                    try fm.moveItem(at: item.file.url, to: target)
                }
                renamedCount += 1
                let action = isCopy ? "rename-copy" : "rename"
                await logger.log(action: action, source: item.file.url.path, destination: target.path, status: .success)
            } catch {
                errorCount += 1
                await logger.log(action: "rename", source: item.file.url.path, status: .error, details: error.localizedDescription)
            }
        }

        isRenaming = false
        renameComplete = !Task.isCancelled
        operationStartTime = nil
        filesPerSecond = 0
        estimatedTimeRemaining = 0
    }

    // MARK: - Cancel

    func cancelOperation() {
        currentTask?.cancel()
        currentTask = nil
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
        discoveredFiles = []
        previewItems = []
        renameComplete = false
        renamedCount = 0
        errorCount = 0
        progress = 0
    }

    // MARK: - Private

    private func uniqueURL(for url: URL, fm: FileManager) -> URL {
        let directory = url.deletingLastPathComponent()
        let stem = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        var counter = 1
        var candidate = url
        while fm.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(stem)_\(counter)" : "\(stem)_\(counter).\(ext)"
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    private static func buildMediaFile(from url: URL) async -> MediaFile? {
        await OrganizerViewModel.buildMediaFile(from: url)
    }
}

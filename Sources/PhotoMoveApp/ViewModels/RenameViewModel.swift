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

    // MARK: - State

    var isScanning: Bool = false
    var isRenaming: Bool = false
    var isCancelling: Bool = false
    var progress: Double = 0
    var currentFileIndex: Int = 0
    var totalFiles: Int = 0
    var currentFileName: String = ""
    var previewItems: [RenamePreview] = []
    var renameComplete: Bool = false
    var renamedCount: Int = 0
    var errorCount: Int = 0

    struct RenamePreview: Identifiable {
        let id = UUID()
        let originalName: String
        let newName: String
        let file: MediaFile
    }

    // MARK: - Folder Selection

    func selectSource() {
        let panel = NSOpenPanel()
        panel.title = "Select Folder to Rename Files"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        sourceURL = url
        reset()
    }

    func selectDestination() {
        let panel = NSOpenPanel()
        panel.title = "Select Destination Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationURL = url
    }

    // MARK: - Scan + Preview

    func scanAndPreview() async -> [RenamePreview] {
        guard let source = sourceURL else { return [] }
        isScanning = true
        isCancelling = false
        previewItems = []
        renameComplete = false

        let urls = FileEnumerator.enumerateMedia(
            in: source,
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            includeOtherFiles: includeOtherFiles,
            includeSubfolders: includeSubfolders
        )

        totalFiles = urls.count

        var files: [MediaFile] = []
        let batchSize = 20

        for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
            if isCancelling { break }
            let batchEnd = min(batchStart + batchSize, urls.count)
            let batch = Array(urls[batchStart..<batchEnd])

            let batchResults = await withTaskGroup(of: MediaFile?.self) { group in
                for url in batch {
                    if isCancelling { group.cancelAll(); break }
                    group.addTask { await Self.buildMediaFile(from: url) }
                }
                var results: [MediaFile] = []
                for await mf in group { if let mf { results.append(mf) } }
                return results
            }
            if isCancelling { break }
            files.append(contentsOf: batchResults)
        }

        if isCancelling {
            isScanning = false
            return []
        }
        
        // Sort by date
        files.sort { ($0.effectiveDate(fallback: dateFallback) ?? .distantPast) < ($1.effectiveDate(fallback: dateFallback) ?? .distantPast) }

        // Generate preview
        var previews: [RenamePreview] = []
        for (index, file) in files.enumerated() {
            guard let date = file.effectiveDate(fallback: dateFallback) else { continue }
            let newName = pattern.rename(
                originalName: file.fileName,
                date: date,
                camera: file.cameraModel,
                sequenceNumber: index + 1
            )
            previews.append(RenamePreview(originalName: file.fileName, newName: newName, file: file))
        }
        
        isScanning = false
        return previews
    }

    // MARK: - Execute Rename

    func executeRename(items: [RenamePreview]) async {
        guard !items.isEmpty else { return }
        isRenaming = true
        isCancelling = false
        progress = 0
        renamedCount = 0
        errorCount = 0

        let fm = FileManager.default
        let total = items.count
        let logger = ActivityLogger.shared
        let isCopy = renameMode == .copyToFolder

        // Create destination if needed
        if isCopy, let dest = destinationURL {
            try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        }

        for (index, item) in items.enumerated() {
            if isCancelling { break }
            
            currentFileIndex = index + 1
            totalFiles = total
            currentFileName = item.originalName
            progress = Double(index + 1) / Double(total)

            let targetDir: URL
            if isCopy, let dest = destinationURL {
                targetDir = dest
            } else {
                targetDir = item.file.url.deletingLastPathComponent()
            }

            let newURL = targetDir.appendingPathComponent(item.newName)

            // Skip if name unchanged and not copying
            if !isCopy && item.originalName == item.newName {
                renamedCount += 1
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
        if !isCancelling {
            renameComplete = true
        }
    }
    
    func cancelOperation() {
        isCancelling = true
    }

    // MARK: - Reset

    func reset() {
        previewItems = []
        renameComplete = false
        renamedCount = 0
        errorCount = 0
        progress = 0
        isScanning = false
        isRenaming = false
        isCancelling = false
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
        let fm = FileManager.default
        let attrs: [FileAttributeKey: Any]
        do {
            attrs = try fm.attributesOfItem(atPath: url.path)
        } catch {
            await ActivityLogger.shared.log(action: "read_attributes", source: url.path, status: .error, details: error.localizedDescription)
            return nil
        }

        let modDate = (attrs[.modificationDate] as? Date) ?? Date()
        let creationDate = attrs[.creationDate] as? Date
        let fileSize = (attrs[.size] as? Int64) ?? 0
        let ext = url.pathExtension.lowercased()
        let mediaType = SupportedFormats.mediaType(for: ext)

        let dateTaken: Date?
        let cameraModel: String?
        switch mediaType {
        case .photo:
            let meta = MetadataExtractor.extractPhotoMetadata(from: url)
            dateTaken = meta.dateTaken; cameraModel = meta.cameraModel
        case .video:
            let meta = await MetadataExtractor.extractVideoMetadata(from: url)
            dateTaken = meta.dateTaken; cameraModel = meta.cameraModel
        case .other, nil:
            dateTaken = nil; cameraModel = nil
        }

        return MediaFile(
            url: url, dateTaken: dateTaken, cameraModel: cameraModel,
            fileCreationDate: creationDate, fileModificationDate: modDate,
            fileSize: fileSize, mediaType: mediaType
        )
    }
}

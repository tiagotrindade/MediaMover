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
    var duplicateHandling: DuplicateHandling = .skip
    var includePhotos: Bool = true
    var includeVideos: Bool = true

    // MARK: - State

    var isScanning: Bool = false
    var isProcessing: Bool = false
    var progress: Double = 0
    var currentFileIndex: Int = 0
    var totalFiles: Int = 0
    var currentFileName: String = ""
    var discoveredFiles: [MediaFile] = []
    var result: OperationResult?
    var scanMessage: String = ""
    private var cancelRequested: Bool = false

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
        cancelRequested = false
        progress = 0
        currentFileIndex = 0
        result = nil

        let organizer = FileOrganizer()
        let files = discoveredFiles

        let opResult = await organizer.organize(
            files: files,
            destination: destination,
            pattern: pattern,
            mode: operationMode,
            duplicateHandling: duplicateHandling,
            progressCallback: { current, total, fileName in
                await MainActor.run { [weak self] in
                    self?.currentFileIndex = current
                    self?.totalFiles = total
                    self?.currentFileName = fileName
                    self?.progress = total > 0 ? Double(current) / Double(total) : 0
                }
            }
        )

        result = opResult
        isProcessing = false
    }

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

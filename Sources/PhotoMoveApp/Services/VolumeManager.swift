import Foundation
import AppKit

// MARK: - Volume Types

enum VolumeType: String, Sendable, CaseIterable {
    case local
    case network    // SMB/AFP shares, NAS
    case iCloud
}

enum ICloudDownloadStatus: Sendable {
    case downloaded
    case notDownloaded
    case downloading
}

struct MountedVolume: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let name: String
    let type: VolumeType
    let isAvailable: Bool
}

// MARK: - VolumeManager

@MainActor
final class VolumeManager {

    static let shared = VolumeManager()
    private init() {}

    // MARK: - Volume Discovery

    /// Lists all mounted volumes categorized by type.
    func discoverVolumes() -> [MountedVolume] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsLocalKey, .volumeIsRemovableKey, .volumeIsReadOnlyKey]

        guard let volumeURLs = fm.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return [] }

        var volumes: [MountedVolume] = []

        for url in volumeURLs {
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            let name = values.volumeName ?? url.lastPathComponent
            let isLocal = values.volumeIsLocal ?? true

            let type: VolumeType = isLocal ? .local : .network
            volumes.append(MountedVolume(url: url, name: name, type: type, isAvailable: true))
        }

        // Add iCloud Drive if available
        if let iCloudURL = iCloudRootURL() {
            volumes.append(MountedVolume(
                url: iCloudURL,
                name: "iCloud Drive",
                type: .iCloud,
                isAvailable: true
            ))
        }

        return volumes
    }

    /// Returns only network volumes.
    func networkVolumes() -> [MountedVolume] {
        discoverVolumes().filter { $0.type == .network }
    }

    // MARK: - Volume Type Detection

    /// Determines the volume type for a given file/folder URL.
    func volumeType(for url: URL) -> VolumeType {
        // Check iCloud first
        if isICloudURL(url) { return .iCloud }

        // Check volume properties
        let keys: Set<URLResourceKey> = [.volumeIsLocalKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return .local }

        if values.volumeIsLocal == false {
            return .network
        }

        return .local
    }

    /// Checks if a URL resides within iCloud Drive.
    func isICloudURL(_ url: URL) -> Bool {
        let path = url.path
        // Standard iCloud Drive path
        if path.contains("/Library/Mobile Documents/com~apple~CloudDocs") { return true }
        // Generic iCloud container path
        if path.contains("/Library/Mobile Documents/") { return true }
        return false
    }

    // MARK: - iCloud Drive

    /// Returns the iCloud Drive root URL, or nil if not available.
    func iCloudRootURL() -> URL? {
        // Try the ubiquity container first
        if let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            return url
        }
        // Fallback to known path
        let home = FileManager.default.homeDirectoryForCurrentUser
        let iCloudPath = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: iCloudPath.path) {
            return iCloudPath
        }
        return nil
    }

    /// Checks the download status of an iCloud file.
    func iCloudDownloadStatus(for url: URL) -> ICloudDownloadStatus {
        let keys: Set<URLResourceKey> = [.ubiquitousItemDownloadingStatusKey]
        guard let values = try? url.resourceValues(forKeys: keys),
              let status = values.ubiquitousItemDownloadingStatus else {
            return .downloaded // Not an iCloud file or already local
        }

        switch status {
        case .current:
            return .downloaded
        case .downloaded:
            return .downloaded
        case .notDownloaded:
            return .notDownloaded
        default:
            return .downloading
        }
    }

    /// Triggers download for iCloud files that are not yet downloaded locally.
    /// Returns the count of files that needed downloading.
    func downloadICloudFiles(
        _ urls: [URL],
        progressCallback: @escaping @Sendable (Int, Int) async -> Void
    ) async -> Int {
        let fm = FileManager.default
        var toDownload: [URL] = []

        for url in urls {
            let status = iCloudDownloadStatus(for: url)
            if status == .notDownloaded {
                toDownload.append(url)
            }
        }

        guard !toDownload.isEmpty else { return 0 }

        // Trigger downloads
        for url in toDownload {
            try? fm.startDownloadingUbiquitousItem(at: url)
        }

        // Poll for completion
        let total = toDownload.count
        var downloaded = 0
        let maxWaitIterations = 600 // 10 minutes max (1s per iteration)
        var iteration = 0

        while downloaded < total && iteration < maxWaitIterations {
            if Task.isCancelled { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            iteration += 1

            downloaded = 0
            for url in toDownload {
                let status = iCloudDownloadStatus(for: url)
                if status == .downloaded {
                    downloaded += 1
                }
            }
            await progressCallback(downloaded, total)
        }

        return toDownload.count
    }

    // MARK: - Connect to Server

    /// Opens the macOS "Connect to Server" dialog or mounts a specific address.
    func connectToServer(address: String? = nil) {
        if let address, let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        } else {
            // Open the Finder "Connect to Server" dialog
            if let url = URL(string: "smb://") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Space Checking

    /// Returns the available space in bytes at the given URL's volume, or nil if unavailable.
    func availableSpace(at url: URL) -> Int64? {
        let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return nil }

        // Prefer the "important usage" key (more accurate on APFS)
        if let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        if let capacity = values.volumeAvailableCapacity {
            return Int64(capacity)
        }
        return nil
    }

    /// Formats bytes into a human-readable string (e.g., "42.5 GB").
    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Volume Monitoring

    /// Checks if a volume is still mounted/accessible.
    func isVolumeAvailable(at url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    /// Monitors a volume for disconnect/reconnect events.
    /// Returns a Task that can be cancelled to stop monitoring.
    func monitorVolume(
        at url: URL,
        checkInterval: TimeInterval = 2.0,
        onDisconnect: @escaping @Sendable () async -> Void,
        onReconnect: @escaping @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task.detached { [weak self] in
            var wasAvailable = true
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                guard let self else { break }

                let isAvailable = await self.isVolumeAvailable(at: url)

                if wasAvailable && !isAvailable {
                    wasAvailable = false
                    await onDisconnect()
                } else if !wasAvailable && isAvailable {
                    wasAvailable = true
                    await onReconnect()
                }
            }
        }
    }
}

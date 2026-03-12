import Foundation

struct FileEnumerator: Sendable {

    static func enumerateMedia(
        in directory: URL,
        includePhotos: Bool,
        includeVideos: Bool
    ) -> [URL] {
        var allowedExtensions = Set<String>()
        if includePhotos { allowedExtensions.formUnion(SupportedFormats.photoExtensions) }
        if includeVideos { allowedExtensions.formUnion(SupportedFormats.videoExtensions) }

        guard !allowedExtensions.isEmpty else { return [] }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard allowedExtensions.contains(ext) else { continue }

            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
               resourceValues.isRegularFile == true {
                results.append(fileURL)
            }
        }

        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

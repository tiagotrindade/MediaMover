import Foundation

struct FileEnumerator: Sendable {

    static func enumerateMedia(
        in directory: URL,
        includePhotos: Bool,
        includeVideos: Bool,
        includeOtherFiles: Bool = false
    ) -> [URL] {
        var allowedExtensions = Set<String>()
        if includePhotos { allowedExtensions.formUnion(SupportedFormats.photoExtensions) }
        if includeVideos { allowedExtensions.formUnion(SupportedFormats.videoExtensions) }

        // If nothing is selected and not including other files, return empty
        guard !allowedExtensions.isEmpty || includeOtherFiles else { return [] }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .creationDateKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let allMediaExtensions = SupportedFormats.allExtensions
        var results: [URL] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true else { continue }

            let ext = fileURL.pathExtension.lowercased()

            if allowedExtensions.contains(ext) {
                // It's a selected media type
                results.append(fileURL)
            } else if includeOtherFiles && !allMediaExtensions.contains(ext) {
                // It's a non-media file and user wants those included
                results.append(fileURL)
            }
        }

        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

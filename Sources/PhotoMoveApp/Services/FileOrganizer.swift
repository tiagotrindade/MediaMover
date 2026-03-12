import Foundation

enum OperationMode: String, CaseIterable, Sendable {
    case copy = "Copy"
    case move = "Move"
}

enum DuplicateHandling: String, CaseIterable, Sendable {
    case skip = "Skip"
    case rename = "Rename"
    case overwrite = "Overwrite"
}

actor FileOrganizer {

    func organize(
        files: [MediaFile],
        destination: URL,
        pattern: OrganizationPattern,
        mode: OperationMode,
        duplicateHandling: DuplicateHandling,
        progressCallback: @Sendable (Int, Int, String) async -> Void
    ) async -> OperationResult {
        let startTime = Date()
        var result = OperationResult(totalFiles: files.count)
        let fm = FileManager.default

        for (index, file) in files.enumerated() {
            await progressCallback(index + 1, files.count, file.fileName)

            let subpath = pattern.destinationSubpath(for: file.effectiveDate, camera: file.cameraModel)
            let destDir = destination.appendingPathComponent(subpath)

            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            } catch {
                result.errors.append((file: file.fileName, error: "Failed to create directory: \(error.localizedDescription)"))
                result.processedFiles += 1
                continue
            }

            var targetURL = destDir.appendingPathComponent(file.fileName)

            if fm.fileExists(atPath: targetURL.path) {
                switch duplicateHandling {
                case .skip:
                    let isDuplicate = isDuplicateFile(source: file.url, target: targetURL)
                    if isDuplicate {
                        result.skippedDuplicates += 1
                        result.processedFiles += 1
                        continue
                    }
                    targetURL = uniqueURL(for: targetURL, fm: fm)

                case .rename:
                    targetURL = uniqueURL(for: targetURL, fm: fm)

                case .overwrite:
                    try? fm.removeItem(at: targetURL)
                }
            }

            do {
                switch mode {
                case .copy:
                    try fm.copyItem(at: file.url, to: targetURL)
                case .move:
                    try fm.moveItem(at: file.url, to: targetURL)
                }
                result.processedFiles += 1
            } catch {
                result.errors.append((file: file.fileName, error: error.localizedDescription))
                result.processedFiles += 1
            }
        }

        result.elapsedTime = Date().timeIntervalSince(startTime)
        return result
    }

    // MARK: - Helpers

    private func isDuplicateFile(source: URL, target: URL) -> Bool {
        guard let sourceHash = try? FileHashing.sha256(of: source),
              let targetHash = try? FileHashing.sha256(of: target) else {
            return false
        }
        return sourceHash == targetHash
    }

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
}

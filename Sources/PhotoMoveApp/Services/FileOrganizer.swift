import Foundation

// MARK: - Enums

enum OperationMode: String, CaseIterable, Sendable, Codable {
    case copy = "Copy"
    case move = "Move"
}

enum DuplicateStrategy: String, CaseIterable, Sendable {
    case ask = "Ask Each Time"
    case automatic = "Automatic"
    case skip = "Don't Move"
}

enum DuplicateAction: String, CaseIterable, Sendable {
    case rename = "Rename File"
    case overwrite = "Replace"
    case overwriteIfLarger = "Replace if Larger"
}

// MARK: - Organizer Configuration

struct OrganizerConfig: Sendable {
    let mode: OperationMode
    let pattern: OrganizationPattern
    let duplicateStrategy: DuplicateStrategy
    let duplicateAction: DuplicateAction        // used when strategy == .automatic
    let verifyIntegrity: Bool
    let hashAlgorithm: HashAlgorithm
}

// MARK: - Duplicate resolution callback (for "Ask" mode)

typealias DuplicateResolver = @Sendable (
    _ sourceFile: String,
    _ sourceSize: Int64,
    _ existingFile: String,
    _ existingSize: Int64
) async -> DuplicateAction?

// MARK: - File Organizer

actor FileOrganizer {

    func organize(
        files: [MediaFile],
        destination: URL,
        config: OrganizerConfig,
        duplicateResolver: DuplicateResolver? = nil,
        progressCallback: @Sendable (Int, Int, String) async -> Void
    ) async -> (result: OperationResult, records: [FileOperationRecord]) {
        let startTime = Date()
        var result = OperationResult(totalFiles: files.count)
        var records: [FileOperationRecord] = []
        let fm = FileManager.default
        let logger = ActivityLogger.shared

        for (index, file) in files.enumerated() {
            await progressCallback(index + 1, files.count, file.fileName)

            let subpath = config.pattern.destinationSubpath(for: file.effectiveDate, camera: file.cameraModel)
            let destDir = destination.appendingPathComponent(subpath)

            // Create destination directory
            do {
                try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            } catch {
                let msg = "Failed to create directory: \(error.localizedDescription)"
                result.errors.append((file: file.fileName, error: msg))
                result.processedFiles += 1
                await logger.log(action: "error", source: file.url.path, status: .error, details: msg)
                continue
            }

            var targetURL = destDir.appendingPathComponent(file.fileName)

            // MARK: Duplicate detection
            if fm.fileExists(atPath: targetURL.path) {
                let resolvedAction: DuplicateAction?

                switch config.duplicateStrategy {
                case .skip:
                    result.skippedDuplicates += 1
                    result.processedFiles += 1
                    await logger.log(action: "skip", source: file.url.path, destination: targetURL.path, status: .info, details: "Duplicate skipped")
                    continue

                case .automatic:
                    resolvedAction = config.duplicateAction

                case .ask:
                    let existingSize = (try? fm.attributesOfItem(atPath: targetURL.path)[.size] as? Int64) ?? 0
                    resolvedAction = await duplicateResolver?(
                        file.fileName,
                        file.fileSize,
                        targetURL.lastPathComponent,
                        existingSize
                    )
                    if resolvedAction == nil {
                        // User chose to skip
                        result.skippedDuplicates += 1
                        result.processedFiles += 1
                        await logger.log(action: "skip", source: file.url.path, status: .info, details: "User skipped duplicate")
                        continue
                    }
                }

                if let action = resolvedAction {
                    switch action {
                    case .rename:
                        targetURL = uniqueURL(for: targetURL, fm: fm)

                    case .overwrite:
                        try? fm.removeItem(at: targetURL)

                    case .overwriteIfLarger:
                        let existingSize = (try? fm.attributesOfItem(atPath: targetURL.path)[.size] as? Int64) ?? 0
                        if file.fileSize > existingSize {
                            try? fm.removeItem(at: targetURL)
                        } else {
                            result.skippedDuplicates += 1
                            result.processedFiles += 1
                            await logger.log(action: "skip", source: file.url.path, status: .info, details: "Existing file is same size or larger")
                            continue
                        }
                    }
                }
            }

            // MARK: Copy/Move
            do {
                switch config.mode {
                case .copy:
                    try fm.copyItem(at: file.url, to: targetURL)
                case .move:
                    try fm.moveItem(at: file.url, to: targetURL)
                }

                result.processedFiles += 1

                // Record for undo
                records.append(FileOperationRecord(
                    action: config.mode,
                    sourcePath: file.url.path,
                    destinationPath: targetURL.path,
                    timestamp: Date()
                ))

                await logger.log(
                    action: config.mode.rawValue.lowercased(),
                    source: file.url.path,
                    destination: targetURL.path,
                    status: .success
                )

                // MARK: Integrity Verification
                if config.verifyIntegrity {
                    do {
                        let verified = try verifyIntegrity(
                            source: config.mode == .copy ? file.url : targetURL,
                            destination: targetURL,
                            mode: config.mode,
                            algorithm: config.hashAlgorithm
                        )
                        if verified {
                            result.verifiedFiles += 1
                        } else {
                            result.verificationFailures += 1
                            result.verificationErrors.append((
                                file: file.fileName,
                                error: "Hash mismatch after \(config.mode.rawValue.lowercased())"
                            ))
                            await logger.log(action: "verify", source: targetURL.path, status: .error, details: "INTEGRITY FAILURE: hash mismatch")
                        }
                    } catch {
                        result.verificationErrors.append((
                            file: file.fileName,
                            error: "Verification error: \(error.localizedDescription)"
                        ))
                        await logger.log(action: "verify", source: targetURL.path, status: .warning, details: error.localizedDescription)
                    }
                }

            } catch {
                result.errors.append((file: file.fileName, error: error.localizedDescription))
                result.processedFiles += 1
                await logger.log(action: "error", source: file.url.path, status: .error, details: error.localizedDescription)
            }
        }

        result.elapsedTime = Date().timeIntervalSince(startTime)
        return (result, records)
    }

    // MARK: - Integrity Verification

    private func verifyIntegrity(source: URL, destination: URL, mode: OperationMode, algorithm: HashAlgorithm) throws -> Bool {
        if mode == .move {
            // For moves, source no longer exists — we can only verify the destination is readable
            _ = try FileHashing.hash(of: destination, algorithm: algorithm)
            return true
        }

        // For copies, compare source and destination hashes
        let sourceHash = try FileHashing.hash(of: source, algorithm: algorithm)
        let destHash = try FileHashing.hash(of: destination, algorithm: algorithm)
        return sourceHash == destHash
    }

    // MARK: - Helpers

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

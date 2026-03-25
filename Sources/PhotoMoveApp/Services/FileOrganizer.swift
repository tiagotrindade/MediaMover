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
    let dateFallback: DateFallback
    let separateVideos: Bool                     // put videos in a "Videos" subfolder
    let renameWithDate: Bool                     // prepend YYYYMMDD_HHMMSSmmm_ to filename
    let separateByCamera: Bool                   // add camera-name subfolder

    // Template-based folder pattern (Phase 2). When set, overrides `pattern`.
    let folderTemplate: String?

    // Network volume support
    let isNetworkVolume: Bool

    init(
        mode: OperationMode,
        pattern: OrganizationPattern,
        duplicateStrategy: DuplicateStrategy,
        duplicateAction: DuplicateAction,
        verifyIntegrity: Bool,
        hashAlgorithm: HashAlgorithm,
        dateFallback: DateFallback,
        separateVideos: Bool,
        renameWithDate: Bool,
        separateByCamera: Bool,
        folderTemplate: String? = nil,
        isNetworkVolume: Bool = false
    ) {
        self.mode = mode
        self.pattern = pattern
        self.duplicateStrategy = duplicateStrategy
        self.duplicateAction = duplicateAction
        self.verifyIntegrity = verifyIntegrity
        self.hashAlgorithm = hashAlgorithm
        self.dateFallback = dateFallback
        self.separateVideos = separateVideos
        self.renameWithDate = renameWithDate
        self.separateByCamera = separateByCamera
        self.folderTemplate = folderTemplate
        self.isNetworkVolume = isNetworkVolume
    }
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
        resilientOperator: ResilientFileOperator? = nil,
        progressCallback: @Sendable (Int, Int, String) async -> Void
    ) async -> (result: OperationResult, records: [FileOperationRecord]) {
        let startTime = Date()
        var result = OperationResult(totalFiles: files.count)
        var records: [FileOperationRecord] = []
        let fm = FileManager.default
        let logger = ActivityLogger.shared

        for (index, file) in files.enumerated() {
            if Task.isCancelled { break }
            await progressCallback(index + 1, files.count, file.fileName)

            // Determine the effective date using the configured fallback
            guard let effectiveDate = file.effectiveDate(fallback: config.dateFallback) else {
                // No date available and user chose "no fallback" — skip this file
                result.skippedNoDate += 1
                result.processedFiles += 1
                await logger.log(action: "skip", source: file.url.path, status: .warning, details: "No date available (metadata or file date)")
                continue
            }

            var subpath: String
            if let template = config.folderTemplate {
                // Template-based path (Phase 2)
                let context = file.templateContext(fallback: config.dateFallback, sequenceNumber: index + 1)
                subpath = TemplateEngine.evaluate(template: template, context: context)
            } else {
                // Legacy pattern-based path
                subpath = config.pattern.destinationSubpath(for: effectiveDate, camera: file.cameraModel)
            }

            // Add camera subfolder if enabled and camera info is available
            // BUG-03 FIX: Skip if the pattern already includes camera in the path
            if config.folderTemplate == nil,
               config.separateByCamera, !config.pattern.includesCamera,
               let camera = file.cameraModel, !camera.isEmpty {
                let safeCam = sanitizeFolderName(camera)
                subpath += "/\(safeCam)"
            }

            // Add "Videos" subfolder for video files if enabled
            if config.separateVideos && file.mediaType == .video {
                subpath += "/Videos"
            }

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

            // Determine target filename (optionally prepend date)
            let targetFileName: String
            if config.renameWithDate {
                targetFileName = datePrefix(for: effectiveDate) + file.fileName
            } else {
                targetFileName = file.fileName
            }

            var targetURL = destDir.appendingPathComponent(targetFileName)

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
                        do {
                            try fm.removeItem(at: targetURL)
                        } catch {
                            let msg = "Failed to remove existing file for overwrite: \(error.localizedDescription)"
                            result.errors.append((file: file.fileName, error: msg))
                            result.processedFiles += 1
                            await logger.log(action: "error", source: targetURL.path, status: .error, details: msg)
                            continue
                        }

                    case .overwriteIfLarger:
                        let existingSize = (try? fm.attributesOfItem(atPath: targetURL.path)[.size] as? Int64) ?? 0
                        if file.fileSize > existingSize {
                            do {
                                try fm.removeItem(at: targetURL)
                            } catch {
                                let msg = "Failed to remove existing file for overwrite: \(error.localizedDescription)"
                                result.errors.append((file: file.fileName, error: msg))
                                result.processedFiles += 1
                                await logger.log(action: "error", source: targetURL.path, status: .error, details: msg)
                                continue
                            }
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
                // BUG-01 FIX: Pre-compute source hash BEFORE move (original is destroyed by move)
                var preMoveHash: String?
                if config.verifyIntegrity && config.mode == .move {
                    preMoveHash = try FileHashing.hash(of: file.url, algorithm: config.hashAlgorithm)
                }

                if let resilientOperator, config.isNetworkVolume {
                    // Use resilient operator for network volumes (retry + speed tracking)
                    switch config.mode {
                    case .copy:
                        try await resilientOperator.copyItem(at: file.url, to: targetURL, isNetwork: true)
                    case .move:
                        try await resilientOperator.moveItem(at: file.url, to: targetURL, isNetwork: true)
                    }
                } else {
                    switch config.mode {
                    case .copy:
                        try fm.copyItem(at: file.url, to: targetURL)
                    case .move:
                        try fm.moveItem(at: file.url, to: targetURL)
                    }
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
                            source: file.url,
                            destination: targetURL,
                            mode: config.mode,
                            algorithm: config.hashAlgorithm,
                            preComputedSourceHash: preMoveHash
                        )
                        if verified {
                            result.verifiedFiles += 1
                        } else {
                            // H-06 FIX: Count verification failures as errors
                            result.verificationFailures += 1
                            result.errors.append((
                                file: file.fileName,
                                error: "Integrity verification failed: hash mismatch after \(config.mode.rawValue.lowercased())"
                            ))
                            result.verificationErrors.append((
                                file: file.fileName,
                                error: "Hash mismatch after \(config.mode.rawValue.lowercased())"
                            ))
                            await logger.log(action: "verify", source: targetURL.path, status: .error, details: "INTEGRITY FAILURE: hash mismatch")
                        }
                    } catch {
                        result.verificationFailures += 1
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

    private func verifyIntegrity(source: URL, destination: URL, mode: OperationMode, algorithm: HashAlgorithm, preComputedSourceHash: String? = nil) throws -> Bool {
        let destHash = try FileHashing.hash(of: destination, algorithm: algorithm)

        if mode == .move {
            // For moves, compare against pre-computed hash (calculated before source was destroyed)
            guard let sourceHash = preComputedSourceHash else {
                return false // No pre-computed hash available — cannot verify
            }
            return sourceHash == destHash
        }

        // For copies, compare source and destination hashes
        let sourceHash = try FileHashing.hash(of: source, algorithm: algorithm)
        return sourceHash == destHash
    }

    // MARK: - Helpers

    /// Generates a date prefix like "20260312_143522123_"
    private func datePrefix(for date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let y = cal.component(.year, from: date)
        let mo = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let h = cal.component(.hour, from: date)
        let mi = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)
        let ns = cal.component(.nanosecond, from: date)
        let ms = ns / 1_000_000
        return String(format: "%04d%02d%02d_%02d%02d%02d%03d_", y, mo, d, h, mi, s, ms)
    }

    private func sanitizeFolderName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "_").trimmingCharacters(in: .whitespaces)
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

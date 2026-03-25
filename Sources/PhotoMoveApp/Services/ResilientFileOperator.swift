import Foundation

// MARK: - ResilientFileOperator

/// Wraps FileManager copy/move with retry logic, transfer speed tracking, and pause/resume
/// support for network volume operations.
actor ResilientFileOperator {

    // MARK: - Configuration

    static let maxRetries = 3
    static let retryDelays: [UInt64] = [1_000_000_000, 3_000_000_000, 9_000_000_000] // 1s, 3s, 9s

    // MARK: - Transfer Speed Tracking

    private var totalBytesTransferred: Int64 = 0
    private var speedTrackingStart: Date?
    private var recentBytesLog: [(timestamp: Date, bytes: Int64)] = []

    /// Whether the operation is currently paused (e.g., volume disconnected).
    private(set) var isPaused: Bool = false

    /// Continuation to resume a paused operation.
    private var pauseContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Speed Calculation

    /// Returns the current transfer speed in bytes per second (rolling 10-second window).
    var bytesPerSecond: Int64 {
        let now = Date()
        let window: TimeInterval = 10.0
        let recent = recentBytesLog.filter { now.timeIntervalSince($0.timestamp) <= window }
        guard let oldest = recent.first else { return 0 }
        let elapsed = now.timeIntervalSince(oldest.timestamp)
        guard elapsed > 0.1 else { return 0 }
        let totalBytes = recent.reduce(Int64(0)) { $0 + $1.bytes }
        return Int64(Double(totalBytes) / elapsed)
    }

    /// Returns a formatted speed string (e.g., "45.2 MB/s").
    var formattedSpeed: String {
        let bps = bytesPerSecond
        if bps <= 0 { return "" }
        if bps >= 1_073_741_824 { // 1 GB/s
            return String(format: "%.1f GB/s", Double(bps) / 1_073_741_824.0)
        } else if bps >= 1_048_576 { // 1 MB/s
            return String(format: "%.1f MB/s", Double(bps) / 1_048_576.0)
        } else if bps >= 1_024 {
            return String(format: "%.0f KB/s", Double(bps) / 1_024.0)
        }
        return "\(bps) B/s"
    }

    // MARK: - Pause / Resume

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
        // C-01 FIX: Resume the stored continuation safely and clear it
        let continuation = pauseContinuation
        pauseContinuation = nil
        continuation?.resume()
    }

    /// Waits if the operator is paused. Returns when resumed or cancelled.
    private func waitIfPaused() async {
        guard isPaused else { return }
        // C-01 FIX: Cancel any previously stored continuation before storing a new one
        let oldContinuation = pauseContinuation
        pauseContinuation = nil
        oldContinuation?.resume()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            if isPaused {
                pauseContinuation = continuation
            } else {
                // Already resumed while we were setting up
                continuation.resume()
            }
        }
    }

    // MARK: - Resilient Copy / Move

    /// Copies a file with retry logic for network volumes.
    /// - Parameters:
    ///   - source: Source file URL
    ///   - destination: Destination file URL
    ///   - isNetwork: Whether this is a network operation (enables retries)
    func copyItem(at source: URL, to destination: URL, isNetwork: Bool) async throws {
        if isNetwork {
            try await performWithRetry {
                try FileManager.default.copyItem(at: source, to: destination)
            }
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }

        // Track bytes transferred
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
        recordTransfer(bytes: fileSize)
    }

    /// Moves a file with retry logic for network volumes.
    func moveItem(at source: URL, to destination: URL, isNetwork: Bool) async throws {
        if isNetwork {
            try await performWithRetry {
                try FileManager.default.moveItem(at: source, to: destination)
            }
        } else {
            try FileManager.default.moveItem(at: source, to: destination)
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
        recordTransfer(bytes: fileSize)
    }

    // MARK: - Retry Logic

    private func performWithRetry(_ operation: @escaping () throws -> Void) async throws {
        var lastError: Error?

        for attempt in 0...Self.maxRetries {
            if Task.isCancelled { throw CancellationError() }

            // Wait if paused (volume disconnected)
            await waitIfPaused()

            do {
                try operation()
                return // Success
            } catch {
                lastError = error

                // Don't retry on the last attempt
                if attempt < Self.maxRetries {
                    let delay = Self.retryDelays[min(attempt, Self.retryDelays.count - 1)]
                    try? await Task.sleep(nanoseconds: delay)
                }
            }
        }

        throw lastError ?? NSError(domain: "ResilientFileOperator", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Operation failed after \(Self.maxRetries) retries"])
    }

    // MARK: - Transfer Tracking

    private func recordTransfer(bytes: Int64) {
        let now = Date()
        if speedTrackingStart == nil { speedTrackingStart = now }
        totalBytesTransferred += bytes
        recentBytesLog.append((timestamp: now, bytes: bytes))

        // Keep only last 30 seconds of entries
        let cutoff = now.addingTimeInterval(-30)
        recentBytesLog.removeAll { $0.timestamp < cutoff }
    }

    func resetTracking() {
        totalBytesTransferred = 0
        speedTrackingStart = nil
        recentBytesLog = []
        isPaused = false
        pauseContinuation = nil
    }
}

import Foundation

struct OperationResult: Sendable, Identifiable {
    let id = UUID()
    var totalFiles: Int = 0
    var processedFiles: Int = 0
    var skippedDuplicates: Int = 0
    var skippedNoDate: Int = 0
    var errors: [(file: String, error: String)] = []
    var elapsedTime: TimeInterval = 0

    // Integrity verification
    var verifiedFiles: Int = 0
    var verificationFailures: Int = 0
    var verificationErrors: [(file: String, error: String)] = []

    // BUG-05 FIX: successCount excludes skipped duplicates and skipped no-date files
    var successCount: Int { processedFiles - errors.count - skippedDuplicates - skippedNoDate }
}

extension OperationResult {
    struct FileError: Sendable {
        let file: String
        let error: String
    }
}

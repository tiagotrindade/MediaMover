import Foundation

struct OperationResult: Sendable {
    var totalFiles: Int = 0
    var processedFiles: Int = 0
    var skippedDuplicates: Int = 0
    var errors: [(file: String, error: String)] = []
    var elapsedTime: TimeInterval = 0

    var successCount: Int { processedFiles - errors.count }
}

extension OperationResult {
    struct FileError: Sendable {
        let file: String
        let error: String
    }
}

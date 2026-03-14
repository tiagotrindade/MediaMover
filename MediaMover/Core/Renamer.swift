
import Foundation

class Renamer {
    
    struct ProgressUpdate {
        let message: String
        let current: Int
        let total: Int
    }
    
    static func processFiles(files: [FileRenamePreview], progressHandler: @escaping (ProgressUpdate) -> Void) async throws {
        let fileManager = FileManager.default
        let totalFiles = files.count

        for (index, file) in files.enumerated() {
            let progressUpdate = ProgressUpdate(message: "Renomeando \(file.originalURL.lastPathComponent)...", current: index + 1, total: totalFiles)
            progressHandler(progressUpdate)

            let destinationURL = file.originalURL.deletingLastPathComponent().appendingPathComponent(file.newFilename)

            // Skip if new name is the same as the old one
            if file.originalURL.path == destinationURL.path {
                continue
            }
            
            // Check for pre-existing file (should be handled by view model, but as a safeguard)
            if fileManager.fileExists(atPath: destinationURL.path) {
                 throw NSError(domain: "com.mediamover.renamer", code: 101, userInfo: [NSLocalizedDescriptionKey: "Conflito: O ficheiro \(destinationURL.lastPathComponent) já existe."])
            }

            try fileManager.moveItem(at: file.originalURL, to: destinationURL)
        }
    }
}

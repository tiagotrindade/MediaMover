
import Foundation

class Organizer {
    enum OperationMode {
        case copy
        case move
    }

    struct ProgressUpdate {
        let fileURL: URL
        let message: String
        let current: Int
        let total: Int
    }

    static func processFiles(sourceDir: URL, destDir: URL, mode: OperationMode, groupByYear: Bool, groupByMonth: Bool, progressHandler: @escaping (ProgressUpdate) -> Void) async throws {
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(at: sourceDir, includingPropertiesForKeys: [.isRegularFileKey, .creationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            // Could throw a custom error here
            return
        }

        let allFiles = enumerator.allObjects.compactMap { $0 as? URL }
        let totalFiles = allFiles.count

        for (index, sourceURL) in allFiles.enumerated() {
            let progressUpdate = ProgressUpdate(fileURL: sourceURL, message: "Processando \(sourceURL.lastPathComponent)...", current: index + 1, total: totalFiles)
            progressHandler(progressUpdate)

            // --- CORREÇÃO PARA BUG-03 (Estrutura de pastas) ---
            let creationDate = (try? sourceURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date()
            var targetSubdirectory = destDir

            if groupByYear {
                let year = Calendar.current.component(.year, from: creationDate)
                targetSubdirectory.appendPathComponent("\(year)")
            }
            if groupByMonth {
                let month = Calendar.current.component(.month, from: creationDate)
                let monthName = DateFormatter().monthSymbols[month - 1]
                targetSubdirectory.appendPathComponent("\(String(format: "%02d", month))-\(monthName)")
            }

            try fileManager.createDirectory(at: targetSubdirectory, withIntermediateDirectories: true, attributes: nil)
            
            let destinationURL = targetSubdirectory.appendingPathComponent(sourceURL.lastPathComponent)
            
            // --- CORREÇÃO PARA BUG-02 (Overwrite) ---
            if fileManager.fileExists(atPath: destinationURL.path) {
                // For now, we skip. A more advanced implementation could offer renaming.
                continue
            }

            switch mode {
            case .copy:
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            case .move:
                // --- CORREÇÃO PARA BUG-01 (Integridade de Dados) ---
                // 1. Calcular hash da ORIGEM antes de qualquer ação
                let sourceHash = Hasher.sha256(for: sourceURL)
                
                // 2. Mover o ficheiro
                try fileManager.moveItem(at: sourceURL, to: destinationURL)
                
                // 3. Calcular hash do DESTINO depois da operação
                let destinationHash = Hasher.sha256(for: destinationURL)

                // 4. Comparar. Se falhar, tentar reverter.
                if sourceHash == nil || sourceHash != destinationHash {
                    // Hashing failed or hashes do not match. CRITICAL ERROR.
                    // Attempt to move the file back if possible.
                    try? fileManager.moveItem(at: destinationURL, to: sourceURL)
                    // Throw a critical error to be caught by the ViewModel.
                    throw NSError(domain: "com.mediamover.organizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Falha na verificação de integridade para o ficheiro \(sourceURL.lastPathComponent). Operação abortada e revertida se possível."])
                }
            }
        }
    }
}

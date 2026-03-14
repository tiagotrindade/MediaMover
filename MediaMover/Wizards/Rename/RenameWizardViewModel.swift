
import Foundation
import SwiftUI

struct FilenameComponent: Identifiable, Hashable {
    let id = UUID()
    var type: ComponentType
    var value: String = ""
    
    enum ComponentType: String, CaseIterable, Codable {
        case customText = "Texto Personalizado"
        case sequence = "Nº Sequencial"
        case originalName = "Nome Original"
        case creationDate = "Data de Criação"
        case fileExtension = "Extensão Original"
    }
}

struct FileRenamePreview: Identifiable {
    let id = UUID()
    let originalURL: URL
    var newFilename: String
    var hasConflict: Bool = false
}

@MainActor
class RenameWizardViewModel: ObservableObject {
    // ... (restante do código igual)
    
    // MARK: - Private Helpers
    private func buildNewFilename(for url: URL, index: Int) -> String {
        let fileExtension = url.pathExtension
        var finalName = ""
        
        for component in nameComponents {
            switch component.type {
            case .customText:
                // --- CORREÇÃO PARA TC-REN-004 ---
                finalName += sanitize(component.value)
            case .sequence:       finalName += String(format: "%03d", index + 1)
            case .originalName:   finalName += url.deletingPathExtension().lastPathComponent
            case .creationDate:   finalName += getFileCreationDate(url: url)
            case .fileExtension:  finalName += fileExtension
            }
        }
        
        if !nameComponents.contains(where: { $0.type == .fileExtension }) && !fileExtension.isEmpty {
            finalName += "." + fileExtension
        }
        
        return finalName
    }
    
    private func sanitize(_ filename: String) -> String {
        // Remove characters that are illegal in file names on most OSes.
        return filename.replacingOccurrences(of: "[\\/:*?\"<>|]", with: "", options: .regularExpression)
    }

    // ... (restante do código igual)
}

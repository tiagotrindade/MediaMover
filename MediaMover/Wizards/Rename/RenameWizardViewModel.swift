
import Foundation
import SwiftUI

// (As estruturas FilenameComponent e FileRenamePreview permanecem as mesmas)
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
    
    // As suas propriedades existentes (selectedFiles, nameComponents, etc.)
    @Published var selectedFiles: [URL] = []
    @Published var nameComponents: [FilenameComponent] = [
        .init(type: .originalName),
        .init(type: .fileExtension)
    ]
    @Published var previews: [FileRenamePreview] = []
    @Published var currentStep: RenameStep = .selectFiles
    @Published var progress: Double = 0.0
    @Published var progressMessage: String = ""
    @Published var isFinished: Bool = false
    
    // MARK: - Steps Enum
    enum RenameStep: CaseIterable {
        case selectFiles
        case definePattern
        case confirm
        case progress
        case complete
        
        var title: String {
            switch self {
            case .selectFiles: "Passo 1: Selecionar Ficheiros"
            case .definePattern: "Passo 2: Definir o Padrão de Nomes"
            case .confirm: "Passo 3: Confirmar e Renomear"
            case .progress: "A Renomear..."
            case .complete: "Concluído!"
            }
        }
    }

    // MARK: - Public Methods
    
    func addComponent() {
        nameComponents.append(FilenameComponent(type: .customText))
        generatePreviews()
    }
    
    func removeComponent(at offsets: IndexSet) {
        nameComponents.remove(atOffsets: offsets)
        generatePreviews()
    }
    
    func moveComponent(from source: IndexSet, to destination: Int) {
        nameComponents.move(fromOffsets: source, toOffset: destination)
        generatePreviews()
    }
    
    func generatePreviews() {
        previews = selectedFiles.enumerated().map { (index, url) in
            let newName = buildNewFilename(for: url, index: index)
            return FileRenamePreview(originalURL: url, newFilename: newName)
        }
        checkForConflicts()
    }
    
    func startRenaming() async {
        currentStep = .progress
        progressMessage = "A preparar para renomear..."
        let totalFiles = Double(selectedFiles.count)
        
        for (index, preview) in previews.enumerated() {
            let originalURL = preview.originalURL
            let newFilename = preview.newFilename
            
            let directory = originalURL.deletingLastPathComponent()
            let newURL = directory.appendingPathComponent(newFilename)
            
            progressMessage = "A renomear: \(originalURL.lastPathComponent) -> \(newFilename)"
            
            do {
                try FileManager.default.moveItem(at: originalURL, to: newURL)
            } catch {
                print("Erro ao renomear ficheiro \(originalURL.path): \(error)")
                // Poderia adicionar uma lógica para lidar com o erro,
                // como marcar o preview com erro.
            }
            
            // Atualizar o progresso
            progress = Double(index + 1) / totalFiles
            // Pequeno delay para a UI atualizar
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        progressMessage = "Renomeação concluída com sucesso!"
        isFinished = true
        currentStep = .complete
    }
    
    func resetWizard() {
        selectedFiles = []
        nameComponents = [.init(type: .originalName), .init(type: .fileExtension)]
        previews = []
        currentStep = .selectFiles
        progress = 0.0
        progressMessage = ""
        isFinished = false
    }

    // MARK: - Private Helpers
    
    private func checkForConflicts() {
        let newNames = previews.map(\.newFilename)
        var nameCounts = [String: Int]()
        for name in newNames {
            nameCounts[name, default: 0] += 1
        }
        
        for i in 0..<previews.count {
            let name = previews[i].newFilename
            previews[i].hasConflict = (nameCounts[name] ?? 0) > 1
        }
    }
    
    // --- FUNÇÃO CORRIGIDA ---
    private func buildNewFilename(for url: URL, index: Int) -> String {
        let fileExtension = url.pathExtension
        var finalName = ""
        
        // CORREÇÃO: Usar 'self.nameComponents' para aceder à propriedade
        for component in self.nameComponents {
            switch component.type {
            case .customText:
                finalName += sanitize(component.value)
            case .sequence:
                finalName += String(format: "%03d", index + 1)
            case .originalName:
                finalName += url.deletingPathExtension().lastPathComponent
            case .creationDate:
                // CORREÇÃO: Usar 'self.getFileCreationDate'
                finalName += self.getFileCreationDate(url: url)
            case .fileExtension:
                // Não adiciona a extensão aqui, será feito no fim se necessário
                break
            }
        }
        
        // CORREÇÃO: Usar 'self.nameComponents' e a variável 'fileExtension'
        if !self.nameComponents.contains(where: { $0.type == .fileExtension }) && !fileExtension.isEmpty {
            finalName += "." + fileExtension
        } else if self.nameComponents.contains(where: { $0.type == .fileExtension }) && !fileExtension.isEmpty {
            // Se o componente de extensão existe, adicionamos aqui
            finalName += "." + fileExtension
        }

        return finalName
    }
    
    private func sanitize(_ filename: String) -> String {
        return filename.replacingOccurrences(of: "[\\\\/:*?\\\"<>|]", with: "", options: .regularExpression)
    }

    // --- FUNÇÃO ADICIONADA ---
    private func getFileCreationDate(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.string(from: creationDate)
            }
        } catch {
            print("Erro ao obter a data de criação para \(url.path): \(error)")
        }
        return "sem_data"
    }
}


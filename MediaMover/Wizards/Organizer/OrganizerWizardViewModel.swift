
import Foundation
import SwiftUI

@MainActor
class OrganizerWizardViewModel: ObservableObject {
    // MARK: - Step Management
    enum OrganizerStep {
        case selectSourceAndDestination
        case chooseActionAndRules
        case preview
        case progress
        case complete
    }
    @Published var currentStep: OrganizerStep = .selectSourceAndDestination
    @Published var errorMessage: String?

    // MARK: - Step 1: Source & Destination
    @Published var sourceURL: URL?
    @Published var destinationURL: URL?
    @Published var sourceFileCount: Int = 0
    @Published var isSourceAndDestValid: Bool = false

    // MARK: - Step 2: Action & Rules
    @Published var operationMode: Organizer.OperationMode = .copy // Default to safer option
    @Published var groupByYear: Bool = true
    @Published var groupByMonth: Bool = true

    // MARK: - Step 3: Preview
    @Published var fileStructurePreview: String = ""

    // MARK: - Step 4: Progress
    @Published var progress: Double = 0.0
    @Published var progressMessage: String = ""
    @Published var isProcessing: Bool = false

    // MARK: - Logic
    func selectSourceURL(_ url: URL) {
        self.sourceURL = url
        validateSourceAndDestination()
        Task {
            let count = await countFilesIn(url: url)
            DispatchQueue.main.async {
                self.sourceFileCount = count
            }
        }
    }
    
    func selectDestinationURL(_ url: URL) {
        self.destinationURL = url
        validateSourceAndDestination()
    }
    
    private func validateSourceAndDestination() {
        errorMessage = nil
        guard let source = sourceURL, let dest = destinationURL else {
            isSourceAndDestValid = false
            return
        }
        
        // --- CORREÇÃO PARA TC-ORG-006 (Origem e Destino Iguais) ---
        if source.path == dest.path {
            errorMessage = "A pasta de origem e destino não podem ser a mesma."
            isSourceAndDestValid = false
            return
        }
        isSourceAndDestValid = true
    }
    
    func generatePreview() {
        guard let dest = destinationURL else { return }
        let formatter = DateFormatter()
        let month = formatter.monthSymbols[Calendar.current.component(.month, from: Date()) - 1]
        
        var preview = dest.lastPathComponent + "/"
        if groupByYear {
            preview += "\n└── 📁 \(Calendar.current.component(.year, from: Date()))/"
            if groupByMonth {
                preview += "\n    └── 📁 \(String(format: "%02d", Calendar.current.component(.month, from: Date())))-\(month)/"
                preview += "\n        └── 📄 ficheiro.jpg"
            } else {
                preview += "\n    └── 📄 ficheiro.jpg"
            }
        } else {
            preview += "\n└── 📄 ficheiro.jpg"
        }
        self.fileStructurePreview = preview
    }

    func startOrganization() async {
        guard isSourceAndDestValid, let sourceURL = sourceURL, let destinationURL = destinationURL else {
            errorMessage = "Condições inválidas para iniciar a organização."
            return
        }

        isProcessing = true
        currentStep = .progress
        errorMessage = nil

        do {
            // --- INTEGRAÇÃO COM LÓGICA REAL ---
            try await Organizer.processFiles(sourceDir: sourceURL, destDir: destinationURL, mode: operationMode, groupByYear: groupByYear, groupByMonth: groupByMonth) { [weak self] update in
                DispatchQueue.main.async {
                    self?.progress = Double(update.current) / Double(update.total)
                    self?.progressMessage = "(\(update.current)/\(update.total)) \(update.message)"
                }
            }
            progressMessage = "Organização concluída com sucesso!"
            currentStep = .complete
        } catch {
            errorMessage = "Ocorreu um erro crítico: \(error.localizedDescription)"
            currentStep = .complete // Move to complete to show the error
        }

        isProcessing = false
    }
    
    func reset() {
        sourceURL = nil
        destinationURL = nil
        sourceFileCount = 0
        operationMode = .copy
        groupByYear = true
        groupByMonth = true
        fileStructurePreview = ""
        progress = 0.0
        progressMessage = ""
        errorMessage = nil
        isSourceAndDestValid = false
        currentStep = .selectSourceAndDestination
    }
    
    private func countFilesIn(url: URL) async -> Int {
        var count = 0
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants])
        for case let fileURL as URL in enumerator ?? NSEnumerator() {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), resourceValues.isRegularFile == true {
                count += 1
            }
        }
        return count
    }
}

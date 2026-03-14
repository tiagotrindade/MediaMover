
import Foundation
import SwiftUI

@MainActor
class OrganizerWizardViewModel: ObservableObject {
    // ... (código existente sem alterações)

    func startOrganization() async {
        guard isSourceAndDestValid, let sourceURL = sourceURL, let destinationURL = destinationURL else {
            errorMessage = "Condições inválidas para iniciar a organização."
            return
        }

        isProcessing = true
        currentStep = .progress
        errorMessage = nil

        do {
            // --- CORREÇÃO DE CONCORRÊNCIA ---
            // A captura de `self` é segura aqui porque a classe é um MainActor.
            // No entanto, para sermos explícitos e seguirmos as melhores práticas,
            // usamos uma função auxiliar assíncrona.
            try await Organizer.processFiles(sourceDir: sourceURL, destDir: destinationURL, mode: operationMode, groupByYear: groupByYear, groupByMonth: groupByMonth) { [weak self] update in
                self?.updateProgress(with: update)
            }
            progressMessage = "Organização concluída com sucesso!"
            currentStep = .complete
        } catch {
            errorMessage = "Ocorreu um erro crítico: \(error.localizedDescription)"
            currentStep = .complete
        }

        isProcessing = false
    }
    
    // --- FUNÇÃO AUXILIAR PARA ATUALIZAR A UI ---
    // Esta função, marcada como @MainActor, garante que as atualizações da UI
    // acontecem sempre na thread principal, resolvendo os avisos.
    private func updateProgress(with update: Organizer.ProgressUpdate) {
        self.progress = Double(update.current) / Double(update.total)
        self.progressMessage = "(\(update.current)/\(update.total)) \(update.message)"
    }

    // ... (resto do código)
}

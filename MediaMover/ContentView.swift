
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            OrganizerModuleView()
                .tabItem {
                    Label("Organizar", systemImage: "folder.arrow.down")
                }
            
            RenameModuleView()
                .tabItem {
                    Label("Renomear", systemImage: "pencil.and.selection.rectangle")
                }
        }
        .padding()
    }
}

// A view that represents the "Organize" tab, and contains the button to launch the wizard.
struct OrganizerModuleView: View {
    @State private var showWizard = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            Text("Módulo de Organização")
                .font(.largeTitle)
            Text("Use o assistente para organizar os seus ficheiros de forma segura e guiada.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("✨ Iniciar Assistente de Organização") {
                showWizard = true
            }
            .font(.title2)
            .padding()
            .sheet(isPresented: $showWizard) {
                OrganizerWizardView(isPresented: $showWizard)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// A view that represents the "Rename" tab, and contains the button to launch the wizard.
struct RenameModuleView: View {
    @State private var showWizard = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.cursor")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            Text("Módulo de Renomeação")
                .font(.largeTitle)
            Text("Use o assistente para construir novos nomes para os seus ficheiros passo a passo.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button("✨ Iniciar Assistente de Renomeação") {
                showWizard = true
            }
            .font(.title2)
            .padding()
            .sheet(isPresented: $showWizard) {
                RenameWizardView(isPresented: $showWizard)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

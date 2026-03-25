import SwiftUI

enum SidebarItem: String, CaseIterable, Hashable {
    case mover    = "Mover"
    case rename   = "Rename"
    case activity = "Activity"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .mover:    return "folder.badge.gearshape"
        case .rename:   return "textformat.abc"
        case .activity: return "list.clipboard"
        case .settings: return "gear"
        }
    }
}

@main
struct FolioSortApplication: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1120, height: 720)
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem? = .mover
    @State private var organizerVM = OrganizerViewModel()
    @State private var renameVM    = RenameViewModel()
    @State private var hasValidatedLicense = false
    /// Bump this number whenever the onboarding content changes significantly
    /// (e.g. major feature additions) to re-show the wizard to returning users.
    private static let currentOnboardingVersion = 2

    @State private var showOnboarding: Bool = {
        let completed = UserDefaults.standard.integer(forKey: "completedOnboardingVersion")
        return completed < ContentView.currentOnboardingVersion
    }()

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 150, ideal: 190, max: 230)
        } detail: {
            ZStack(alignment: .bottom) {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                StatusBarView(
                    organizerVM: organizerVM,
                    renameVM: renameVM,
                    selection: selection ?? .mover
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding, viewModel: organizerVM)
        }
        .task {
            // Validate license on launch (once per app session)
            guard !hasValidatedLicense else { return }
            hasValidatedLicense = true
            await ProManager.shared.validateOnLaunch()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .mover {
        case .mover:
            MoverView(viewModel: organizerVM)
        case .rename:
            RenameView(viewModel: renameVM)
        case .activity:
            ActivityView(organizerVM: organizerVM)
        case .settings:
            SettingsView(viewModel: organizerVM)
        }
    }
}

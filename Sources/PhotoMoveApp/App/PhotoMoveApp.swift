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

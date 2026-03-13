import SwiftUI

enum AppTab: String, CaseIterable {
    case mover = "Mover"
    case rename = "Rename"
}

@main
struct MediaMoverApplication: App {
    var body: some Scene {
        WindowGroup {
            AppShell()
        }
        .defaultSize(width: 720, height: 560)
    }
}

struct AppShell: View {
    @State private var selectedTab: AppTab = .mover

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    TabButton(
                        title: tab.rawValue,
                        icon: tab == .mover ? "tray.and.arrow.up" : "pencil.and.list.clipboard",
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            Group {
                switch selectedTab {
                case .mover:
                    MainView()
                case .rename:
                    RenameView()
                }
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

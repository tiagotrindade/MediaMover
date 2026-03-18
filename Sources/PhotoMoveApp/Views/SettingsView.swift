import SwiftUI

struct SettingsView: View {
    var viewModel: OrganizerViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("Settings")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
            Text("Coming soon")
                .font(.system(size: 13)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

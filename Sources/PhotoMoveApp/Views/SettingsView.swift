import SwiftUI

struct SettingsView: View {
    var viewModel: OrganizerViewModel
    @State private var showUpgrade = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pro Status
                proStatusSection

                // Development section (remove before release)
                devSection
            }
            .padding(40)
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
    }

    // MARK: - Pro Status

    private var proStatusSection: some View {
        VStack(spacing: 16) {
            if ProManager.shared.isPro {
                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("FolioSort Pro")
                    .font(.system(size: 18, weight: .bold))
                Text("All features unlocked")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "crown")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("FolioSort Free")
                    .font(.system(size: 18, weight: .bold))
                Text("Upgrade to unlock all features")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button("Upgrade to Pro") {
                    showUpgrade = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            ProManager.shared.isPro ? Color.orange.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Development (remove before release)

    private var devSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "hammer")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
                Text("DEVELOPMENT")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange).tracking(0.5)
            }

            VStack(spacing: 0) {
                HStack {
                    Label("Pro Mode", systemImage: "crown.fill")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { ProManager.shared.isPro },
                        set: { newValue in
                            if newValue {
                                ProManager.shared.unlock()
                            } else {
                                ProManager.shared.lock()
                            }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

            Text("Toggle Pro mode for testing. Remove before release.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

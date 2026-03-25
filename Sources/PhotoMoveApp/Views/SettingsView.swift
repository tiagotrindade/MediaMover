import SwiftUI

struct SettingsView: View {
    var viewModel: OrganizerViewModel
    @State private var showUpgrade = false
    @State private var showDeactivateConfirm = false
    @State private var isDeactivating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pro Status
                proStatusSection

                // License info (when Pro is active)
                if ProManager.shared.isPro {
                    licenseSection
                }

                // C-06 FIX: Dev section only in DEBUG builds
                #if DEBUG
                devSection
                #endif
            }
            .padding(40)
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
        .task {
            // Re-validate license on settings view appearance
            await ProManager.shared.validateOnLaunch()
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

                // Status badge
                statusBadge
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

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        switch ProManager.shared.licenseStatus {
        case .active:
            Label("License active", systemImage: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
        case .offline:
            Label("Offline mode — license will re-validate when online", systemImage: "wifi.slash")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
        case .expired:
            Label("License expired", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        case .disabled:
            Label("License disabled", systemImage: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        case .invalid:
            Label("License invalid", systemImage: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }

    // MARK: - License Section

    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "key.fill")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Text("LICENSE")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            }

            VStack(spacing: 0) {
                // Masked key display
                HStack {
                    Label("License Key", systemImage: "key")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text(ProManager.shared.maskedKey)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)

                Divider().padding(.horizontal, 12)

                // Deactivate button
                HStack {
                    Label("Deactivate License", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Button(isDeactivating ? "Deactivating..." : "Deactivate") {
                        showDeactivateConfirm = true
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                    .disabled(isDeactivating)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))

            Text("Deactivating frees this license to be used on another Mac.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .alert("Deactivate License?", isPresented: $showDeactivateConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Deactivate", role: .destructive) {
                isDeactivating = true
                Task {
                    await ProManager.shared.deactivate()
                    isDeactivating = false
                }
            }
        } message: {
            Text("This will disable Pro features on this Mac. You can re-activate later with the same license key.")
        }
    }

    // MARK: - Development (DEBUG only)

    #if DEBUG
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

            Text("Toggle Pro mode for testing. Only visible in DEBUG builds.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
    #endif
}

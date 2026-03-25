import SwiftUI
import AppKit

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var licenseKey = ""
    @State private var showSuccess = false

    private let features: [(category: String, items: [String])] = [
        ("Organization", [
            "Unlimited files per operation",
            "All 7+ folder presets",
            "Custom Template Builder with all tokens",
            "Profiles — save & reuse configurations",
            "Video subfolder toggle",
            "Rename with date toggle",
        ]),
        ("Rename", [
            "Unlimited files per operation",
            "All 7 rename presets",
            "Regex Rename (find/replace with regex)",
            "Custom rename templates via Template Builder",
        ]),
        ("Formats", [
            "RAW Photos (CR2, CR3, NEF, ARW, DNG, +20 more)",
            "RAW Video (BRAW, R3D, ARI, CRM, MXF)",
            "Other Files toggle (documents, archives)",
        ]),
        ("Safety", [
            "SHA-256 integrity verification",
            "Smart duplicates: Ask Each Time & Automatic",
            "Persistent undo — up to 50 batches across sessions",
        ]),
        ("Metadata", [
            "Reverse Geocoding (GPS to location names)",
            "Extended EXIF tokens (Lens, ISO, Aperture, Shutter)",
            "Location tokens ({City}, {Country}, {State})",
        ]),
        ("Cloud & Network", [
            "Import from NAS (Synology, QNAP, SMB/AFP shares)",
            "iCloud Drive source & destination support",
        ]),
        ("Activity Log", [
            "Search & filter by status",
            "Export log file",
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Feature list
            featureList

            Divider()

            // Footer — Purchase + Activation
            footer
        }
        .frame(width: 440, height: 640)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("Upgrade to FolioSort Pro")
                .font(.system(size: 18, weight: .bold))
            Text("One-time purchase — unlock everything, forever.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Feature list

    private var featureList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(features, id: \.category) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(group.category.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        ForEach(group.items, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.green)
                                    .frame(width: 14, height: 14)
                                Text(item)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            if showSuccess {
                // Success state
                successBanner
            } else if ProManager.shared.isPro {
                // Already Pro
                alreadyProBanner
            } else {
                // Purchase + License activation
                purchaseSection
                activationSection
            }

            Button("Maybe Later") {
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
        }
        .padding(20)
    }

    // MARK: - Sub-sections

    private var purchaseSection: some View {
        VStack(spacing: 6) {
            Text("€9.99 / $9.99")
                .font(.system(size: 20, weight: .bold))
            Text("One-time purchase")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Button {
                NSWorkspace.shared.open(LemonSqueezyService.checkoutURL)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 11))
                    Text("Buy FolioSort Pro")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 4)

            Text("You'll receive a license key by email after purchase.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var activationSection: some View {
        VStack(spacing: 8) {
            Divider().padding(.vertical, 4)

            Text("Already purchased? Enter your license key:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { activateLicense() }

                Button {
                    activateLicense()
                } label: {
                    if ProManager.shared.isActivating {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 60)
                    } else {
                        Text("Activate")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ProManager.shared.isActivating)
            }
            .padding(.horizontal, 4)

            // Error message
            if let error = ProManager.shared.activationError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(error)
                        .font(.system(size: 11))
                }
                .foregroundStyle(.red)
            }
        }
    }

    private var successBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("Pro Unlocked!")
                .font(.system(size: 16, weight: .bold))
            Text("All features are now available.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button("Close") { dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)
        }
    }

    private var alreadyProBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("FolioSort Pro")
                .font(.system(size: 16, weight: .bold))
            Text("All features unlocked")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button("Close") { dismiss() }
                .buttonStyle(SecondaryButtonStyle())
        }
    }

    // MARK: - Actions

    private func activateLicense() {
        Task {
            await ProManager.shared.activate(licenseKey: licenseKey)
            if ProManager.shared.isPro {
                withAnimation { showSuccess = true }
            }
        }
    }
}

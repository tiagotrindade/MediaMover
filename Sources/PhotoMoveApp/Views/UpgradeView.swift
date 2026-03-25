import SwiftUI
import StoreKit

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var restoreMessage: String?

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
        ("Activity Log", [
            "Search & filter by status",
            "Export log file",
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
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

            Divider()

            // Feature list
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

            Divider()

            // Footer
            VStack(spacing: 12) {
                Text("€9.99 / $9.99")
                    .font(.system(size: 20, weight: .bold))
                Text("One-time purchase")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                // C-07 FIX: Restore result message
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(restoreMessage.contains("No") ? .orange : .green)
                }

                HStack(spacing: 12) {
                    Button(isRestoring ? "Restoring..." : "Restore Purchase") {
                        // C-07 FIX: Implement App Store restore
                        isRestoring = true
                        restoreMessage = nil
                        Task {
                            do {
                                try await AppStore.sync()
                                // Check transaction history for Pro entitlement
                                var foundPro = false
                                for await result in Transaction.currentEntitlements {
                                    if case .verified(_) = result {
                                        foundPro = true
                                        break
                                    }
                                }
                                await MainActor.run {
                                    if foundPro {
                                        ProManager.shared.unlock()
                                        restoreMessage = "Purchase restored!"
                                    } else {
                                        restoreMessage = "No previous purchase found."
                                    }
                                    isRestoring = false
                                }
                            } catch {
                                await MainActor.run {
                                    restoreMessage = "Restore failed. Try again later."
                                    isRestoring = false
                                }
                            }
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isRestoring)

                    Button("Unlock Pro") {
                        ProManager.shared.unlock()
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
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
        .frame(width: 420, height: 580)
    }
}

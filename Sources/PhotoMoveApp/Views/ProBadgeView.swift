import SwiftUI

// MARK: - ProBadge (overlay lock for a section/control)

/// Wraps content with a semi-transparent lock overlay when the feature requires Pro.
/// Tapping the lock opens the UpgradeView sheet.
struct ProBadge<Content: View>: View {
    let gate: FeatureGate
    @ViewBuilder let content: () -> Content

    @State private var showUpgrade = false

    var body: some View {
        if FeatureGate.isAvailable(gate) {
            content()
        } else {
            content()
                .opacity(0.4)
                .allowsHitTesting(false)
                .overlay(alignment: .center) {
                    Button {
                        showUpgrade = true
                    } label: {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .sheet(isPresented: $showUpgrade) {
                    UpgradeView()
                }
        }
    }
}

// MARK: - ProInlineBadge (small "PRO" label next to text)

/// Shows a small "PRO" badge next to a label when the feature is locked.
/// Tapping the badge opens the UpgradeView sheet.
struct ProInlineBadge: View {
    let gate: FeatureGate

    @State private var showUpgrade = false

    var body: some View {
        if !FeatureGate.isAvailable(gate) {
            Button {
                showUpgrade = true
            } label: {
                Text("PRO")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.12))
                    )
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showUpgrade) {
                UpgradeView()
            }
        }
    }
}

// MARK: - ProLockedRow (config row that shows lock when not Pro)

/// A config row wrapper: shows content normally when Pro, shows locked version with tap-to-upgrade when Free.
struct ProLockedRow<Content: View>: View {
    let gate: FeatureGate
    @ViewBuilder let content: () -> Content

    @State private var showUpgrade = false

    var body: some View {
        if FeatureGate.isAvailable(gate) {
            content()
        } else {
            Button {
                showUpgrade = true
            } label: {
                content()
                    .opacity(0.5)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 12)
                    }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showUpgrade) {
                UpgradeView()
            }
        }
    }
}

// MARK: - ProPickerOption modifier

/// Disables a picker option and appends a lock icon when not Pro.
struct ProPickerOptionModifier: ViewModifier {
    let gate: FeatureGate

    func body(content: Content) -> some View {
        if FeatureGate.isAvailable(gate) {
            content
        } else {
            HStack(spacing: 4) {
                content
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension View {
    func proPickerOption(_ gate: FeatureGate) -> some View {
        modifier(ProPickerOptionModifier(gate: gate))
    }
}

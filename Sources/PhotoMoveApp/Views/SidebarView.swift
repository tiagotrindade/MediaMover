import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @State private var showUpgrade = false

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases, id: \.self) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }

            Spacer()

            // Pro status at bottom of sidebar
            Section {
                if ProManager.shared.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Pro")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                } else {
                    Button {
                        showUpgrade = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("Upgrade to Pro")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("FolioSort")
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
    }
}

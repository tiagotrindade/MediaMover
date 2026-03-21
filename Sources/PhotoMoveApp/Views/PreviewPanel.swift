import SwiftUI

// MARK: - Preview tree node

struct PreviewNode: Identifiable {
    let id = UUID()
    let name: String
    let isFolder: Bool
    let mediaType: MediaType?
    var children: [PreviewNode]?

    static func folder(_ name: String, children: [PreviewNode]) -> PreviewNode {
        PreviewNode(name: name, isFolder: true, mediaType: nil, children: children)
    }

    static func file(_ name: String, mediaType: MediaType?) -> PreviewNode {
        PreviewNode(name: name, isFolder: false, mediaType: mediaType, children: nil)
    }
}

// MARK: - Preview Panel

struct PreviewPanel: View {
    var viewModel: OrganizerViewModel

    private var previewTree: [PreviewNode] {
        buildTree(from: viewModel.previewItems)
    }

    var body: some View {
        VStack(spacing: 0) {
            panelHeader
            Divider()
            if previewTree.isEmpty {
                emptyState
            } else {
                treeView
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            Text("PREVIEW")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).tracking(0.5)
            Spacer()
            if !viewModel.previewItems.isEmpty {
                Text("Updates automatically")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 34)).foregroundStyle(.tertiary)
            Text("Select a source folder\nto see preview")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tree view

    private var treeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(previewTree) { node in
                    PreviewNodeView(node: node, depth: 0)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Build tree

    private func buildTree(from items: [OrganizerViewModel.MoverPreview]) -> [PreviewNode] {
        guard !items.isEmpty else { return [] }
        return buildLevel(from: items, depth: 0)
    }

    private func buildLevel(from items: [OrganizerViewModel.MoverPreview], depth: Int) -> [PreviewNode] {
        var folderBuckets: [String: [OrganizerViewModel.MoverPreview]] = [:]
        var leafItems: [OrganizerViewModel.MoverPreview] = []

        for item in items {
            let components = item.destinationSubpath
                .split(separator: "/", omittingEmptySubsequences: true)
                .map(String.init)
            if depth < components.count {
                let key = components[depth]
                folderBuckets[key, default: []].append(item)
            } else {
                leafItems.append(item)
            }
        }

        var nodes: [PreviewNode] = []
        for key in folderBuckets.keys.sorted() {
            let children = buildLevel(from: folderBuckets[key]!, depth: depth + 1)
            nodes.append(.folder(key, children: children))
        }
        let maxLeaves = 30
        for item in leafItems.prefix(maxLeaves) {
            nodes.append(.file(item.fileName, mediaType: item.mediaType))
        }
        if leafItems.count > maxLeaves {
            nodes.append(.file("+ \(leafItems.count - maxLeaves) more…", mediaType: nil))
        }
        return nodes
    }
}

// MARK: - Preview Node View

struct PreviewNodeView: View {
    let node: PreviewNode
    let depth: Int
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent
            if node.isFolder && isExpanded, let children = node.children {
                ForEach(children) { child in
                    PreviewNodeView(node: child, depth: depth + 1)
                }
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 4) {
            // Indentation
            if depth > 0 {
                Rectangle().fill(Color.clear).frame(width: CGFloat(depth) * 14)
            }
            if node.isFolder {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .semibold)).foregroundStyle(.secondary).frame(width: 10)
                Image(systemName: isExpanded ? "folder.open" : "folder")
                    .font(.system(size: 11)).foregroundStyle(Color.orange)
                Text(node.name)
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.primary)
            } else {
                Rectangle().fill(Color.clear).frame(width: 10)
                nodeFileIcon
                    .font(.system(size: 10))
                Text(node.name)
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isFolder {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 2)
    }

    @ViewBuilder
    private var nodeFileIcon: some View {
        switch node.mediaType {
        case .photo:  Image(systemName: "photo").foregroundStyle(Color.blue)
        case .video:  Image(systemName: "film").foregroundStyle(Color.green)
        case .other:  Image(systemName: "doc.text").foregroundStyle(Color.gray)
        case nil:     Image(systemName: "ellipsis").foregroundStyle(Color.secondary)
        }
    }
}

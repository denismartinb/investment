import SwiftUI

struct TreeMapItem: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let value: Double
    let share: Double
    let color: Color
}

struct TreeMapView: View {
    let items: [TreeMapItem]
    @State private var selectedTitle: String?

    private var selectedItem: TreeMapItem? {
        guard let selectedTitle else { return nil }
        return items.first(where: { $0.title == selectedTitle })
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = TreeMapLayout.layout(items: items, in: proxy.size)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTitle = nil
                        }
                    }

                ForEach(layout) { node in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTitle = selectedTitle == node.item.title ? nil : node.item.title
                        }
                    } label: {
                        TreeMapNodeView(node: node, isSelected: selectedTitle == node.item.title)
                            .frame(width: node.rect.width, height: node.rect.height)
                    }
                    .buttonStyle(.plain)
                    .position(x: node.rect.midX, y: node.rect.midY)
                }

                if let selectedItem {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedItem.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(selectedItem.share.percentString) · \(selectedItem.value.currencyString)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedTitle = nil
        }
    }
}

private struct TreeMapNodeView: View {
    let node: TreeMapNode
    let isSelected: Bool

    private var showTitle: Bool { node.rect.width > 58 && node.rect.height > 28 }
    private var showShare: Bool { node.rect.width > 78 && node.rect.height > 48 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(node.item.color.opacity(isSelected ? 1 : 0.96))
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.30 : 0.16), lineWidth: isSelected ? 2 : 1)

            if showTitle {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.item.title)
                        .font(.system(size: node.fontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.62)
                        .fixedSize(horizontal: false, vertical: true)
                    if showShare {
                        Text(node.item.share.percentString)
                            .font(.system(size: max(node.fontSize - 1, 9), weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                }
                .padding(10)
            }
        }
        .clipped()
        .shadow(color: .black.opacity(isSelected ? 0.16 : 0), radius: 10, y: 4)
    }
}

private struct TreeMapNode: Identifiable {
    var id: String { item.id }
    let item: TreeMapItem
    let rect: CGRect
    let fontSize: CGFloat
}

private enum TreeMapLayout {
    static func layout(items: [TreeMapItem], in size: CGSize) -> [TreeMapNode] {
        guard !items.isEmpty else { return [] }
        let sorted = items.sorted { $0.value > $1.value }
        let total = max(sorted.reduce(0) { $0 + $1.value }, 1)
        let columns = size.width > 520 ? 3 : 2
        var groups: [[TreeMapItem]] = Array(repeating: [], count: columns)
        var sums = Array(repeating: 0.0, count: columns)
        for item in sorted {
            if let index = sums.enumerated().min(by: { $0.element < $1.element })?.offset {
                groups[index].append(item)
                sums[index] += item.value
            }
        }
        var nodes: [TreeMapNode] = []
        var xOffset: CGFloat = 0
        for (columnIndex, group) in groups.enumerated() where !group.isEmpty {
            let columnShare = group.reduce(0) { $0 + $1.value } / total
            let width = columnIndex == groups.count - 1 ? size.width - xOffset : size.width * columnShare
            var yOffset: CGFloat = 0
            let columnTotal = max(group.reduce(0) { $0 + $1.value }, 1)
            for (itemIndex, item) in group.enumerated() {
                let height = itemIndex == group.count - 1 ? size.height - yOffset : size.height * (item.value / columnTotal)
                let rect = CGRect(x: xOffset, y: yOffset, width: max(width - 8, 0), height: max(height - 8, 0))
                let fontSize = min(max(min(rect.width, rect.height) * 0.11, 9), 14)
                nodes.append(TreeMapNode(item: item, rect: rect, fontSize: fontSize))
                yOffset += height
            }
            xOffset += width
        }
        return nodes
    }
}

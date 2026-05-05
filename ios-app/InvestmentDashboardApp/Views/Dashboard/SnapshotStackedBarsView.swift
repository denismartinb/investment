import SwiftUI

struct SnapshotStackedBarsView: View {
    let points: [AllocationHistoryPoint]
    @State private var selectedIndex: Int?

    private var rawGroups: [(index: Int, label: String, slices: [AllocationHistoryPoint])] {
        Dictionary(grouping: points, by: \.index)
            .sorted { $0.key < $1.key }
            .compactMap { index, slices in
                guard let label = slices.first?.label else { return nil }
                return (index, label, slices)
            }
    }

    private var typeOrder: [String] {
        let latestTypes = rawGroups.last?.slices.sorted { $0.share > $1.share }.map(\.type) ?? []
        let remaining = Array(Set(points.map(\.type)).subtracting(latestTypes)).sorted()
        return latestTypes + remaining
    }

    private var grouped: [(index: Int, label: String, slices: [AllocationHistoryPoint])] {
        rawGroups.map { group in
            let ordered = group.slices.sorted {
                let left = typeOrder.firstIndex(of: $0.type) ?? .max
                let right = typeOrder.firstIndex(of: $1.type) ?? .max
                if left == right { return $0.type < $1.type }
                return left > right
            }
            return (group.index, group.label, ordered)
        }
    }

    private var selectedGroup: (index: Int, label: String, slices: [AllocationHistoryPoint])? {
        guard let selectedIndex else { return nil }
        return grouped.first(where: { $0.index == selectedIndex })
    }

    var body: some View {
        GeometryReader { proxy in
            let count = max(grouped.count, 1)
            let axisHeight: CGFloat = 34
            let topInset: CGFloat = 4
            let spacing: CGFloat = count > 28 ? 1 : count > 20 ? 2 : count > 12 ? 4 : 8
            let totalWidth = max(proxy.size.width, 1)
            let barWidth = max((totalWidth - CGFloat(count - 1) * spacing) / CGFloat(count), 2)
            let chartHeight = max(proxy.size.height - axisHeight - topInset, 84)
            let xLabels = sampledXAxisLabels(for: grouped.map(\.label), availableWidth: totalWidth)

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.16)) {
                            selectedIndex = nil
                        }
                    }

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(grouped, id: \.index) { entry in
                        let normalized = normalizedSlices(entry.slices)
                        VStack(spacing: 0) {
                            ForEach(normalized, id: \.id) { slice in
                                Rectangle()
                                    .fill(AppTheme.color(for: slice.type))
                                    .frame(height: chartHeight * slice.share)
                            }
                        }
                        .frame(width: barWidth, height: chartHeight, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                selectedIndex = (selectedIndex == entry.index ? nil : entry.index)
                            }
                        }
                    }
                }
                .frame(width: totalWidth, height: chartHeight, alignment: .bottomLeading)
                .offset(y: topInset)
                .clipped()

                ForEach(Array(grouped.enumerated()), id: \.element.index) { tuple in
                    let offset = xPosition(for: tuple.offset, barWidth: barWidth, spacing: spacing)
                    if xLabels.contains(tuple.element.label) {
                        Text(DashboardDateFormatter.wrappedLabel(tuple.element.label))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                            .frame(width: min(max(barWidth * 3.2, 52), 76))
                            .position(x: offset + barWidth / 2, y: chartHeight + axisHeight * 0.48)
                    }
                }

                if let selectedGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedGroup.label)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                        ForEach(selectedGroup.slices.sorted { $0.share > $1.share }, id: \.id) { slice in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(AppTheme.color(for: slice.type))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 3)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(slice.type)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(slice.share.percentString) · \(slice.value.currencyString)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.92))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.leading, 8)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedIndex = nil
        }
    }

    private func normalizedSlices(_ slices: [AllocationHistoryPoint]) -> [AllocationHistoryPoint] {
        let total = max(slices.reduce(0) { $0 + $1.share }, 0.0001)
        return slices.map { slice in
            AllocationHistoryPoint(id: slice.id, index: slice.index, label: slice.label, type: slice.type, share: slice.share / total, value: slice.value)
        }
    }

    private func sampledXAxisLabels(for labels: [String], availableWidth: CGFloat) -> Set<String> {
        let unique = labels.reduce(into: [String]()) { result, label in
            if result.last != label { result.append(label) }
        }
        guard unique.count > 1 else { return Set(unique) }
        let maxLabels = max(Int(availableWidth / 92), 2)
        let step = max(Int(ceil(Double(unique.count) / Double(maxLabels))), 1)
        let sampled = unique.enumerated().compactMap { index, label in
            index % step == 0 || index == unique.count - 1 ? label : nil
        }
        return Set(sampled)
    }

    private func xPosition(for index: Int, barWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(index) * (barWidth + spacing)
    }
}

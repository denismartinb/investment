import SwiftUI
import Charts

struct PerformanceView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                overviewCard
                assetProfitHistoryCard
                currentTypePerformanceCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onTapGesture {
            DashboardTooltipDismissal.post()
        }
        .navigationTitle("Rentabilidad")
        .sheet(isPresented: $appViewModel.isTypeFilterPresented) {
            TypeFilterSheetView().environmentObject(appViewModel)
        }
    }

    private var overviewCard: some View {
        PremiumPanel(highlight: AppTheme.positive) {
            SectionHeader(title: "Performance", subtitle: "ROI, beneficio y porcentaje de capital invertido")
            filterRow
            PerformanceMetricLineCard(title: "Evolución del ROI", subtitle: "Beneficio sobre aportación", points: appViewModel.performanceTimeline, color: AppTheme.positive, value: { $0.roi }, formatter: { $0.percentString })
            PerformanceMetricBarCard(title: "Evolución del beneficio", subtitle: "Resultado agregado de la cartera", points: appViewModel.performanceTimeline.filter { abs($0.profit) > 0.01 }, color: AppTheme.accentBlue, value: { $0.profit }, formatter: { $0.compactCurrencyString })
            PerformanceMetricLineCard(title: "% de capital invertido", subtitle: "Peso ex liquidez sobre activos brutos", points: appViewModel.performanceTimeline.filter { $0.investedRatio > 0 }, color: AppTheme.accentOrange, value: { $0.investedRatio }, formatter: { $0.percentString })
        }
    }

    private var assetProfitHistoryCard: some View {
        PremiumPanel(highlight: AppTheme.accentPurple) {
            SectionHeader(title: "Beneficio por activo", subtitle: "Lectura histórica del resultado por activo")
            filterRow
            AssetProfitHistoryChartCard(points: appViewModel.profitHistoryByAsset)
        }
    }

    private var currentTypePerformanceCard: some View {
        PremiumPanel(highlight: AppTheme.accentPink) {
            SectionHeader(title: "Rentabilidad actual por tipo", subtitle: "Foto actual de valor, beneficio y ROI de cada categoría.")
            ForEach(appViewModel.typePerformance) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.type).font(.headline).foregroundStyle(AppTheme.textPrimary)
                            Text(item.share.percentString + " de la cartera").font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer(minLength: 12)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(item.profit.signedCurrencyString).font(.headline.weight(.bold)).foregroundStyle(item.profit >= 0 ? AppTheme.positive : AppTheme.negative).lineLimit(1)
                            Text(item.roi.percentString).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    HStack {
                        Text(item.value.currencyString).foregroundStyle(AppTheme.textPrimary).lineLimit(1)
                        Spacer()
                        Text(item.contribution.currencyString).foregroundStyle(AppTheme.textMuted).lineLimit(1)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(16)
                .background(AppTheme.surface.opacity(0.50), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var filterRow: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(appViewModel.rangeOptions, id: \.self) { months in
                    Button("Últimos \(months) meses") {
                        appViewModel.performanceRangeMonths = months
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Periodo")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textMuted)
                    Text(appViewModel.performanceRangeLabel)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppTheme.surface.opacity(0.50), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            GlassTag(text: "Seleccionar activos", accent: AppTheme.accentOrange)
                .onTapGesture { appViewModel.isTypeFilterPresented = true }
        }
    }
}

private struct PerformanceMetricLineCard: View {
    let title: String
    let subtitle: String
    let points: [TimelinePoint]
    let color: Color
    let value: (TimelinePoint) -> Double
    let formatter: (Double) -> String
    @State private var selectedLabel: String?

    private var selectedPoint: TimelinePoint? {
        guard let selectedLabel else { return nil }
        return points.first(where: { $0.label == selectedLabel })
    }

    var body: some View {
        let values = points.map(value)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, abs(maxValue) * 0.10, 1)
        let domain = (minValue - span * 0.15)...(maxValue + span * 0.18)
        let labels = sampledLabels(from: points.map(\.label))

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if let last = values.last {
                    Text(formatter(last)).font(.headline.weight(.bold)).foregroundStyle(color).lineLimit(1)
                }
            }
            ZStack(alignment: .topLeading) {
                Chart(points) { item in
                    LineMark(x: .value("Fecha", item.label), y: .value(title, value(item)))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.linear)
                }
                .frame(maxWidth: .infinity, minHeight: 178, maxHeight: 178)
                .chartYScale(domain: domain)
                .chartXScale(range: .plotDimension(padding: 8))
                .chartXAxis {
                    AxisMarks(values: labels) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(DashboardDateFormatter.wrappedLabel(label))
                                    .foregroundStyle(AppTheme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatter(amount)).foregroundStyle(AppTheme.textMuted).lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { gesture in
                                        let frame = geometry[proxy.plotAreaFrame]
                                        let locationX = gesture.location.x - frame.origin.x
                                        let locationY = gesture.location.y - frame.origin.y
                                        guard locationX >= 0, locationX <= proxy.plotAreaSize.width,
                                              locationY >= 0, locationY <= proxy.plotAreaSize.height,
                                              let label = proxy.value(atX: locationX, as: String.self) else {
                                            selectedLabel = nil
                                            return
                                        }
                                        selectedLabel = label
                                    }
                            )
                    }
                }

                if let selectedPoint {
                    FloatingTooltip(lines: [selectedPoint.label, formatter(value(selectedPoint))], accent: color)
                        .padding(.top, 8)
                        .padding(.leading, 8)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedLabel = nil
        }
    }
}

private struct PerformanceMetricBarCard: View {
    let title: String
    let subtitle: String
    let points: [TimelinePoint]
    let color: Color
    let value: (TimelinePoint) -> Double
    let formatter: (Double) -> String
    @State private var selectedLabel: String?

    private var selectedPoint: TimelinePoint? {
        guard let selectedLabel else { return nil }
        return points.first(where: { $0.label == selectedLabel })
    }

    var body: some View {
        let labels = sampledLabels(from: points.map(\.label))
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                if let last = points.last { Text(formatter(value(last))).font(.headline.weight(.bold)).foregroundStyle(color).lineLimit(1) }
            }
            ZStack(alignment: .topLeading) {
                Chart(points) { item in
                    BarMark(x: .value("Fecha", item.label), y: .value(title, value(item)), width: .ratio(0.56))
                        .foregroundStyle(color.gradient)
                        .cornerRadius(5)
                }
                .frame(maxWidth: .infinity, minHeight: 178, maxHeight: 178)
                .chartXScale(range: .plotDimension(padding: 10))
                .chartXAxis {
                    AxisMarks(values: labels) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(DashboardDateFormatter.wrappedLabel(label))
                                    .foregroundStyle(AppTheme.textMuted)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.72)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(formatter(amount)).foregroundStyle(AppTheme.textMuted).lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { gesture in
                                        let frame = geometry[proxy.plotAreaFrame]
                                        let locationX = gesture.location.x - frame.origin.x
                                        let locationY = gesture.location.y - frame.origin.y
                                        guard locationX >= 0, locationX <= proxy.plotAreaSize.width,
                                              locationY >= 0, locationY <= proxy.plotAreaSize.height,
                                              let label = proxy.value(atX: locationX, as: String.self) else {
                                            selectedLabel = nil
                                            return
                                        }
                                        selectedLabel = label
                                    }
                            )
                    }
                }

                if let selectedPoint {
                    FloatingTooltip(lines: [selectedPoint.label, formatter(value(selectedPoint))], accent: color)
                        .padding(.top, 8)
                        .padding(.leading, 8)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedLabel = nil
        }
    }
}

private struct AssetProfitHistoryChartCard: View {
    let points: [AssetProfitHistoryPoint]
    @State private var selectedLabel: String?

    private var groupedLegend: [(String, Color)] {
        let assets = Array(Set(points.map(\.asset))).sorted()
        return assets.enumerated().map { index, asset in
            (asset, assetPalette[index % assetPalette.count])
        }
    }

    private var selectedItems: [AssetProfitHistoryPoint] {
        guard let selectedLabel else { return [] }
        return points.filter { $0.label == selectedLabel }.sorted { $0.profit > $1.profit }
    }

    var body: some View {
        let labels = sampledLabels(from: points.map(\.label))
        VStack(alignment: .leading, spacing: 12) {
            Chart(points) { item in
                BarMark(x: .value("Fecha", item.label), y: .value("Beneficio", item.profit), width: .ratio(0.58), stacking: .standard)
                    .foregroundStyle(assetColor(for: item.asset))
            }
            .frame(maxWidth: .infinity, minHeight: 310, maxHeight: 310)
            .chartLegend(.hidden)
            .chartXScale(range: .plotDimension(padding: 10))
            .chartXAxis {
                AxisMarks(values: labels) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(DashboardDateFormatter.wrappedLabel(label))
                                .foregroundStyle(AppTheme.textMuted)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.compactCurrencyString).foregroundStyle(AppTheme.textMuted).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { gesture in
                                        let frame = geometry[proxy.plotAreaFrame]
                                        let locationX = gesture.location.x - frame.origin.x
                                        let locationY = gesture.location.y - frame.origin.y
                                        guard locationX >= 0, locationX <= proxy.plotAreaSize.width,
                                              locationY >= 0, locationY <= proxy.plotAreaSize.height,
                                              let label = proxy.value(atX: locationX, as: String.self) else {
                                            selectedLabel = nil
                                            return
                                        }
                                        selectedLabel = label
                                    }
                            )

                        if !selectedItems.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedItems.first?.label ?? "")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                ForEach(selectedItems, id: \.id) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(assetColor(for: item.asset))
                                            .frame(width: 8, height: 8)
                                            .padding(.top, 3)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(item.asset)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text(item.profit.compactCurrencyString)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.92))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.top, 8)
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }
            ChartLegendRow(items: groupedLegend)
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedLabel = nil
        }
    }

    private func assetColor(for asset: String) -> Color {
        let assets = Array(Set(points.map(\.asset))).sorted()
        let index = assets.firstIndex(of: asset) ?? 0
        return assetPalette[index % assetPalette.count]
    }

    private var assetPalette: [Color] {
        [
            AppTheme.accentBlue,
            AppTheme.accentOrange,
            AppTheme.positive,
            AppTheme.accentPurple,
            AppTheme.accentPink,
            Color(red: 0.17, green: 0.74, blue: 0.73),
            Color(red: 0.93, green: 0.33, blue: 0.44),
            Color(red: 0.98, green: 0.77, blue: 0.27),
            Color(red: 0.43, green: 0.56, blue: 0.96),
            Color(red: 0.54, green: 0.79, blue: 0.29)
        ]
    }
}

private struct FloatingTooltip: View {
    let lines: [String]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(index == 0 ? .caption.weight(.bold) : .caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(accent.opacity(0.25), lineWidth: 1))
        .allowsHitTesting(false)
    }
}

private func sampledLabels(from labels: [String]) -> [String] {
    let unique = labels.reduce(into: [String]()) { result, label in
        if result.last != label { result.append(label) }
    }
    guard unique.count > 4 else { return unique }
    let maxLabels: Int
    if unique.count > 24 {
        maxLabels = 3
    } else if unique.count > 12 {
        maxLabels = 4
    } else {
        maxLabels = 5
    }
    let step = max(Int(ceil(Double(unique.count) / Double(maxLabels))), 1)
    return unique.enumerated().compactMap { index, label in
        index % step == 0 || index == unique.count - 1 ? label : nil
    }
}

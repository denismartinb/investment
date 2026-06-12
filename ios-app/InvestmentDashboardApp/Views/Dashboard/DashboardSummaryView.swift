import SwiftUI
import Charts

struct DashboardSummaryView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @AppStorage("dashboardLightMode") private var prefersLightMode = false
    @AppStorage("dashboardHideSensitive") private var hideSensitiveValues = false

    private var shouldShowCompanions: Bool { appViewModel.trajectoryMode != .profit }

    private var previousSummary: PortfolioSummary? {
        guard let payload = appViewModel.payload,
              let selectedDate = appViewModel.selectedDate,
              let index = payload.sortedDates.firstIndex(of: selectedDate),
              index > 0 else { return nil }
        let previousDate = payload.sortedDates[index - 1]
        return payload.summary(for: previousDate, includedTypes: appViewModel.selectedTypes)
    }

    private var trajectoryDomain: ClosedRange<Double> {
        let points = appViewModel.timeline
        let activeValues = points.map { appViewModel.trajectoryValue(for: $0) }
        let companionValues = shouldShowCompanions ? points.flatMap { [$0.investedValue, $0.debt] } : []
        let values = (activeValues + companionValues).filter { $0.isFinite }
        guard let minValue = values.min(), let maxValue = values.max() else { return 0...1 }
        let span = max(maxValue - minValue, abs(maxValue) * 0.10, 1)
        return (minValue - span * 0.12)...(maxValue + span * 0.16)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                hero
                summaryGrid
                trajectoryCard
                snapshotComparisonCard
                topPositions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onTapGesture {
            DashboardTooltipDismissal.post()
        }
        .navigationTitle("Resumen")
        .toolbar { toolbarContent }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(AppTheme.heroGradient)
            VStack(alignment: .leading, spacing: 14) {
                Text("Patrimonio y activos")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Resumen de patrimonio, asignación y rentabilidad")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 10) {
                    GlassTag(text: "Seleccionar activos", accent: AppTheme.accentOrange)
                        .onTapGesture { appViewModel.isTypeFilterPresented = true }
                    Text(appViewModel.activeTypeCountLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Snapshot activo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    if let payload = appViewModel.payload {
                        Picker("Snapshot", selection: Binding(
                            get: { appViewModel.selectedDate ?? payload.latestDate ?? "" },
                            set: { appViewModel.selectedDate = $0 }
                        )) {
                            ForEach(payload.sortedDates.reversed(), id: \.self) { date in
                                Text(DashboardDateFormatter.display(date)).tag(date)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.textPrimary)
                    }
                }
            }
            .padding(22)
        }
        .frame(minHeight: 146)
    }

    private var summaryGrid: some View {
        let summary = appViewModel.summary
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            DashboardMetricCard(title: "Activos brutos", value: summary.grossAssets.currencyString, subtitle: deltaSubtitle(current: summary.grossAssets, previous: previousSummary?.grossAssets), accent: AppTheme.positive, isHidden: hideSensitiveValues, compact: true)
            DashboardMetricCard(title: "Patrimonio neto", value: summary.netWorth.currencyString, subtitle: deltaSubtitle(current: summary.netWorth, previous: previousSummary?.netWorth), accent: AppTheme.accentBlue, isHidden: hideSensitiveValues, compact: true)
            DashboardMetricCard(title: "Capital invertido", value: summary.investedValue.currencyString, subtitle: investedSubtitle(summary: summary, previous: previousSummary), accent: AppTheme.accentOrange, isHidden: hideSensitiveValues, compact: true)
            DashboardMetricCard(title: "ROI", value: summary.roi.percentString, subtitle: "Beneficio sobre aportación", accent: AppTheme.accentPurple, isHidden: hideSensitiveValues, compact: true)
            DashboardMetricCard(title: "Liquidez", value: summary.liquidity.currencyString, subtitle: deltaSubtitle(current: summary.liquidity, previous: previousSummary?.liquidity), accent: AppTheme.accentCyan, isHidden: hideSensitiveValues, compact: true)
            DashboardMetricCard(title: "Beneficio", value: summary.profit.currencyString, subtitle: deltaSubtitle(current: summary.profit, previous: previousSummary?.profit), accent: AppTheme.accentPink, isHidden: hideSensitiveValues, compact: true)
        }
    }

    private var trajectoryCard: some View {
        PremiumPanel(highlight: AppTheme.accentBlue) {
            SectionHeader(title: "Evolución de patrimonio", subtitle: "Serie principal, capital invertido e hipoteca")
            filterRow
            ChartLegendRow(items: trajectoryLegendItems)
            TrajectoryLineChart(
                labels: appViewModel.timeline.map(\.label),
                series: trajectorySeries,
                domain: trajectoryDomain,
                hideSensitiveValues: hideSensitiveValues
            )
            .frame(height: 292)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AppViewModel.TrajectoryMode.allCases) { mode in
                    Button {
                        appViewModel.trajectoryMode = mode
                    } label: {
                        Text(mode.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(appViewModel.trajectoryMode == mode ? AppTheme.textPrimary : AppTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background((appViewModel.trajectoryMode == mode ? AppTheme.accentBlue.opacity(0.24) : AppTheme.surface.opacity(0.55)), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var trajectoryLegendItems: [(String, Color)] {
        var items: [(String, Color)] = [(appViewModel.trajectoryMode.rawValue, AppTheme.positive)]
        if shouldShowCompanions {
            items.append(("Capital invertido", AppTheme.accentBlue))
            items.append(("Hipoteca", AppTheme.accentOrange))
        }
        return items
    }

    private var trajectorySeries: [TrajectorySeries] {
        var items: [TrajectorySeries] = [
            TrajectorySeries(name: appViewModel.trajectoryMode.rawValue, color: AppTheme.positive, values: appViewModel.timeline.map { appViewModel.trajectoryValue(for: $0) }, dashed: false)
        ]
        if shouldShowCompanions {
            items.append(TrajectorySeries(name: "Capital invertido", color: AppTheme.accentBlue, values: appViewModel.timeline.map(\.investedValue), dashed: true))
            items.append(TrajectorySeries(name: "Hipoteca", color: AppTheme.accentOrange, values: appViewModel.timeline.map(\.debt), dashed: true))
        }
        return items
    }

    private var snapshotComparisonCard: some View {
        PremiumPanel(highlight: AppTheme.accentPurple) {
            SectionHeader(title: "Comparación de snapshots", subtitle: "Contrasta dos cortes temporales y cómo se mueve cada KPI clave.")
            HStack(spacing: 12) {
                datePickerCard(title: "Base", selection: $appViewModel.comparisonBaseDate)
                datePickerCard(title: "Comparado", selection: $appViewModel.comparisonTargetDate)
            }
            .padding(.bottom, 12)
            comparisonSnapshotCard(title: appViewModel.comparisonBaseDate.map(DashboardDateFormatter.display) ?? "-", summary: appViewModel.comparisonBaseSummary, accent: AppTheme.accentBlue)

            VStack(spacing: 12) {
                ForEach(Array(appViewModel.comparisonMetrics.enumerated()), id: \.element.id) { _, metric in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(metric.title).font(.headline).foregroundStyle(AppTheme.textPrimary)
                            if let ratio = metric.deltaRatio {
                                Text((ratio >= 0 ? "+" : "") + ratio.percentString).font(.caption.weight(.semibold)).foregroundStyle(metric.delta >= 0 ? AppTheme.positive : AppTheme.negative)
                            }
                        }
                        Spacer()
                        Text(displayDelta(metric)).font(.headline.weight(.bold)).foregroundStyle(metric.delta >= 0 ? AppTheme.positive : AppTheme.negative).lineLimit(1)
                    }
                    .padding(16)
                    .background(AppTheme.surface.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            comparisonSnapshotCard(title: appViewModel.comparisonTargetDate.map(DashboardDateFormatter.display) ?? "-", summary: appViewModel.comparisonTargetSummary, accent: AppTheme.positive)
        }
    }

    private func comparisonSnapshotCard(title: String, summary: PortfolioSummary, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline.weight(.bold)).foregroundStyle(AppTheme.textPrimary).padding(.top, 4)
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                DashboardMetricCard(title: "Activos brutos", value: summary.grossAssets.currencyString, subtitle: "Sin descontar deuda", accent: accent, isHidden: hideSensitiveValues, compact: true)
                DashboardMetricCard(title: "Patrimonio neto", value: summary.netWorth.currencyString, subtitle: "Tras descontar hipoteca", accent: accent, isHidden: hideSensitiveValues, compact: true)
                DashboardMetricCard(title: "Capital invertido", value: summary.investedValue.currencyString, subtitle: summary.investedRatio.percentString + " sobre activos brutos", accent: accent, isHidden: hideSensitiveValues, compact: true)
                DashboardMetricCard(title: "Beneficio", value: summary.profit.currencyString, subtitle: "Resultado acumulado", accent: accent, isHidden: hideSensitiveValues, compact: true)
            }
        }
    }

    private func datePickerCard(title: String, selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.textMuted)
            if let payload = appViewModel.payload {
                Picker(title, selection: Binding(get: { selection.wrappedValue ?? payload.latestDate ?? "" }, set: { selection.wrappedValue = $0 })) {
                    ForEach(payload.sortedDates.reversed(), id: \.self) { date in
                        Text(DashboardDateFormatter.display(date)).tag(date)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.surface.opacity(0.50), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var topPositions: some View {
        PremiumPanel(highlight: AppTheme.accentOrange) {
            SectionHeader(title: "Top posiciones", subtitle: "Concentración de la cartera en las posiciones con más peso.")
            ForEach(appViewModel.summary.topPositions) { position in
                let share = position.value.percentOf(appViewModel.summary.grossAssets)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(position.name).font(.headline).foregroundStyle(AppTheme.textPrimary)
                            Text(position.type).font(.subheadline).foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer(minLength: 12)
                        GlassTag(text: share.percentString, accent: AppTheme.accentOrange)
                    }
                    HStack {
                        Text(hideSensitiveValues ? "••••••" : position.value.currencyString)
                            .font(.title3.weight(.bold)).foregroundStyle(AppTheme.textPrimary).lineLimit(1).minimumScaleFactor(0.7)
                        Spacer()
                        Text(hideSensitiveValues ? "••••" : position.profit.signedCurrencyString)
                            .font(.subheadline.weight(.semibold)).foregroundStyle(position.profit >= 0 ? AppTheme.positive : AppTheme.negative).lineLimit(1)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.surface.opacity(0.65))
                            Capsule().fill(AppTheme.accentOrange).frame(width: proxy.size.width * share)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(16)
                .background(AppTheme.surface.opacity(0.50), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private func deltaSubtitle(current: Double, previous: Double?) -> String {
        guard let previous else { return "Sin periodo anterior" }
        return "\((current - previous).signedCurrencyString) frente a periodo anterior"
    }

    private func investedSubtitle(summary: PortfolioSummary, previous: PortfolioSummary?) -> String {
        let deltaText = previous.map { (summary.investedValue - $0.investedValue).signedCurrencyString } ?? "-"
        return "\(summary.investedRatio.percentString), \(deltaText) frente a periodo anterior"
    }

    private func displayDelta(_ metric: SnapshotComparisonMetric) -> String {
        switch metric.format {
        case .currency: return metric.delta.signedCurrencyString
        case .percent:
            return (metric.delta >= 0 ? "+" : "") + metric.delta.percentString
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button { hideSensitiveValues.toggle() } label: { Image(systemName: hideSensitiveValues ? "eye.slash" : "eye") }
            Button { prefersLightMode.toggle() } label: { Image(systemName: prefersLightMode ? "moon.fill" : "sun.max.fill") }
            Menu {
                Button { Task { await appViewModel.refreshDashboard() } } label: {
                    Label("Actualizar datos", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) { Task { await appViewModel.logout() } } label: {
                    Label("Salir", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { appViewModel.isProfilePresented = true } label: {
                ProfileToolbarAvatar()
            }
        }
    }
}

private struct TrajectorySeries {
    let name: String
    let color: Color
    let values: [Double]
    let dashed: Bool
}

private struct TrajectoryLineChart: View {
    let labels: [String]
    let series: [TrajectorySeries]
    let domain: ClosedRange<Double>
    let hideSensitiveValues: Bool

    @State private var selectedIndex: Int?

    private var yAxisValues: [Double] {
        let lower = domain.lowerBound
        let upper = domain.upperBound
        let steps = 3.0
        return (0...3).map { step in
            upper - ((upper - lower) * Double(step) / steps)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(yAxisValues.enumerated()), id: \.offset) { index, value in
                        Text(hideSensitiveValues ? "•••" : value.compactCurrencyString)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        if index < yAxisValues.count - 1 {
                            Spacer()
                        }
                    }
                }
                .frame(width: 54, height: 228)

                GeometryReader { proxy in
                    let width = max(proxy.size.width, 1)
                    let height = max(proxy.size.height, 1)
                    let baseline = domain.lowerBound
                    let span = max(domain.upperBound - domain.lowerBound, 0.0001)

                    ZStack(alignment: .topLeading) {
                        ForEach(0..<4, id: \.self) { index in
                            let y = height * CGFloat(index) / 3
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                            .stroke(AppTheme.axis.opacity(0.55), style: StrokeStyle(lineWidth: 0.8, dash: [4, 5]))
                        }

                        ForEach(Array(series.enumerated()), id: \.offset) { _, item in
                            Path { path in
                                guard !item.values.isEmpty else { return }
                                for (index, value) in item.values.enumerated() {
                                    let x = xPosition(index: index, count: item.values.count, width: width)
                                    let y = yPosition(value: value, baseline: baseline, span: span, height: height)
                                    if index == 0 {
                                        path.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        path.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                            }
                            .stroke(item.color, style: StrokeStyle(lineWidth: item.dashed ? 2 : 3, lineCap: .round, lineJoin: .round, dash: item.dashed ? [6, 5] : []))
                        }

                        if let selectedIndex {
                            let x = xPosition(index: selectedIndex, count: labels.count, width: width)
                            Path { path in
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: height))
                            }
                            .stroke(.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            ForEach(Array(series.enumerated()).filter { selectedIndex < $0.element.values.count }, id: \.offset) { _, item in
                                let value = item.values[selectedIndex]
                                let y = yPosition(value: value, baseline: baseline, span: span, height: height)
                                Circle()
                                    .fill(item.color)
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                                    .position(x: x, y: y)
                            }

                            ProfileTrajectoryTooltip(
                                title: labels[selectedIndex],
                                items: series.compactMap { item in
                                    guard selectedIndex < item.values.count else { return nil }
                                    let value = item.values[selectedIndex]
                                    return (item.name, item.color, hideSensitiveValues ? "••••••" : value.currencyString)
                                }
                            )
                            .padding(.top, 8)
                            .padding(.leading, min(max(x - 70, 8), max(width - 180, 8)))
                        }

                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .simultaneousGesture(
                                SpatialTapGesture()
                                    .onEnded { gesture in
                                        guard !labels.isEmpty else {
                                            selectedIndex = nil
                                            return
                                        }
                                        let location = gesture.location
                                        guard location.x >= 0, location.x <= width, location.y >= 0, location.y <= height else {
                                            selectedIndex = nil
                                            return
                                        }
                                        let ratio = max(0, min(1, location.x / width))
                                        let index = Int(round(ratio * CGFloat(max(labels.count - 1, 0))))
                                        selectedIndex = min(max(index, 0), max(labels.count - 1, 0))
                                    }
                            )
                    }
                }
                .frame(height: 228)
            }

            HStack {
                ForEach(sampledTrajectoryLabels(from: labels), id: \.self) { label in
                    Text(DashboardDateFormatter.wrappedLabel(label))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, 64)
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedIndex = nil
        }
    }

    private func xPosition(index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        return CGFloat(index) / CGFloat(count - 1) * width
    }

    private func yPosition(value: Double, baseline: Double, span: Double, height: CGFloat) -> CGFloat {
        let normalized = (value - baseline) / span
        return height - CGFloat(normalized) * height
    }
}

private struct ProfileTrajectoryTooltip: View {
    let title: String
    let items: [(String, Color, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(item.1)
                        .frame(width: 8, height: 8)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.0)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(item.2)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }
}

private func sampledTrajectoryLabels(from labels: [String]) -> [String] {
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


private struct ProfileToolbarAvatar: View {
    var body: some View {
        Group {
            if let image = UIImage(named: "profile_photo") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(LinearGradient(colors: [AppTheme.accentBlue, AppTheme.accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("D")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
    }
}

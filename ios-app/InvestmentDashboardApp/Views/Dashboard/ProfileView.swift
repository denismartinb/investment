import SwiftUI
import Charts

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dashboardHideSensitive") private var hideSensitiveValues = false

    private var profile: ProfilePayload { appViewModel.profile }
    private var incomeVisibleMaxYear: Int {
        let incomeMax = (profile.totalIncomeAnnual ?? []).map(\.year).max() ?? Int.max
        return min(incomeMax, 2025)
    }

    private var incomePoints: [ProfileAnnualIncomePoint] {
        (profile.totalIncomeAnnual ?? [])
            .filter { $0.year <= incomeVisibleMaxYear }
            .sorted { $0.year < $1.year }
    }

    private var salaryPoints: [ProfileSalaryPoint] {
        (profile.salaryEvolution ?? [])
            .sorted { $0.year < $1.year }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                headerCard
                incomeCard
                salaryCard
                summaryCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onTapGesture {
            DashboardTooltipDismissal.post()
        }
        .navigationTitle("Mi Perfil")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cerrar") { dismiss() }
            }
        }
    }

    private var headerCard: some View {
        PremiumPanel(highlight: AppTheme.accentBlue) {
            VStack(spacing: 14) {
                ProfileAvatarView()
                Text(profile.fullName ?? "Denis Martín Barroso")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("Perfil profesional y evolución de ingresos")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var incomeCard: some View {
        PremiumPanel(highlight: AppTheme.accentOrange) {
            SectionHeader(title: "Evolución de ingresos totales anuales", subtitle: "Ingresos totales frente a salario Telefónica")
            ProfileIncomeComparisonChart(
                incomePoints: incomePoints,
                salaryPoints: salaryPoints,
                hideSensitiveValues: hideSensitiveValues
            )
            .frame(height: 248)
            ChartLegendRow(items: [
                ("Ingresos totales", AppTheme.accentOrange),
                ("Salario Telefónica", AppTheme.accentBlue)
            ])
        }
    }

    private var salaryCard: some View {
        PremiumPanel(highlight: AppTheme.accentPurple) {
            SectionHeader(title: "Evolución salarial en Telefónica", subtitle: "Salario bruto, bonus y top performer")
            ProfileSalaryStackedChart(points: salaryPoints, hideSensitiveValues: hideSensitiveValues)
                .frame(height: 248)
            ChartLegendRow(items: [
                ("Salario bruto", AppTheme.accentBlue),
                ("Bonus", AppTheme.accentOrange),
                ("Top performer", AppTheme.accentPurple)
            ])
        }
    }

    private var summaryCard: some View {
        let years = Array(Set(incomePoints.map(\.year) + salaryPoints.map(\.year))).sorted(by: >)
        let incomeByYear = Dictionary(uniqueKeysWithValues: incomePoints.map { ($0.year, $0) })
        let salaryByYear = Dictionary(uniqueKeysWithValues: salaryPoints.map { ($0.year, $0) })

        return PremiumPanel(highlight: AppTheme.accentBlue) {
            SectionHeader(title: "Resumen anual", subtitle: "Ingresos y desglose salarial por año")
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ProfileTableHeaderCell(title: "Año", width: 66, alignment: .leading)
                        ProfileTableHeaderCell(title: "Ingresos", width: 118)
                        ProfileTableHeaderCell(title: "Total salario", width: 124)
                        ProfileTableHeaderCell(title: "Bruto", width: 110)
                        ProfileTableHeaderCell(title: "Bonus", width: 104)
                        ProfileTableHeaderCell(title: "Top perf.", width: 108)
                    }
                    ForEach(Array(years.enumerated()), id: \.element) { index, year in
                        let income = incomeByYear[year]?.totalIncome
                        let salary = salaryByYear[year]
                        HStack(spacing: 0) {
                            ProfileTableValueCell(text: String(year), width: 66, alignment: .leading, emphasized: true)
                            ProfileTableValueCell(text: maskedCurrency(income, hideSensitive: hideSensitiveValues), width: 118)
                            ProfileTableValueCell(text: maskedCurrency(salary?.salary, hideSensitive: hideSensitiveValues), width: 124)
                            ProfileTableValueCell(text: maskedCurrency(salary?.grossSalary, hideSensitive: hideSensitiveValues), width: 110)
                            ProfileTableValueCell(text: maskedCurrency(salary?.bonus, hideSensitive: hideSensitiveValues), width: 104)
                            ProfileTableValueCell(text: salary?.topPerformer ?? 0 > 0 ? maskedCurrency(salary?.topPerformer, hideSensitive: hideSensitiveValues) : "-", width: 108)
                        }
                        .background((index % 2 == 0 ? AppTheme.surface.opacity(0.42) : AppTheme.surface.opacity(0.28)), in: RoundedRectangle(cornerRadius: 0, style: .continuous))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct ProfileIncomeComparisonChart: View {
    let incomePoints: [ProfileAnnualIncomePoint]
    let salaryPoints: [ProfileSalaryPoint]
    let hideSensitiveValues: Bool

    @State private var selectedYear: String?

    private var selectedIncomePoint: ProfileAnnualIncomePoint? {
        guard let selectedYear else { return nil }
        return incomePoints.first(where: { String($0.year) == selectedYear })
    }

    private var selectedSalaryPoint: ProfileSalaryPoint? {
        guard let selectedYear else { return nil }
        return salaryPoints.first(where: { String($0.year) == selectedYear })
    }

    var body: some View {
        let allYears = Array(Set(incomePoints.map(\.year) + salaryPoints.map(\.year))).sorted()
        let labels = sampledProfileYearLabels(from: allYears)
        let values = incomePoints.map(\.totalIncome) + salaryPoints.map(\.salary)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, abs(maxValue) * 0.10, 1)
        let domain = (minValue - span * 0.15)...(maxValue + span * 0.18)

        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(salaryPoints.filter { $0.salary > 0 }) { point in
                    RectangleMark(
                        xStart: .value("Inicio", Double(point.year) - 0.32),
                        xEnd: .value("Fin", Double(point.year) + 0.32),
                        yStart: .value("Base", 0),
                        yEnd: .value("Salario Telefónica", point.salary)
                    )
                    .foregroundStyle(AppTheme.accentBlue.opacity(0.40))
                    .cornerRadius(5)
                }

                ForEach(incomePoints) { point in
                    LineMark(x: .value("Año", point.year), y: .value("Ingresos", point.totalIncome))
                        .foregroundStyle(AppTheme.accentOrange)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.linear)
                    AreaMark(x: .value("Año", point.year), y: .value("Ingresos", point.totalIncome))
                        .foregroundStyle(AppTheme.accentOrange.opacity(0.14))
                }
            }
            .chartYScale(domain: domain)
            .chartXScale(domain: (allYears.first ?? 0)...(allYears.last ?? 1), range: .plotDimension(padding: 14))
            .chartXAxis {
                AxisMarks(values: labels) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let year = value.as(Int.self) {
                            Text(String(year))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(hideSensitiveValues ? "•••" : amount.compactCurrencyString)
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { gesture in
                                    let frame = geometry[proxy.plotAreaFrame]
                                    let locationX = gesture.location.x - frame.origin.x
                                    let locationY = gesture.location.y - frame.origin.y
                                    guard locationX >= 0,
                                          locationX <= proxy.plotAreaSize.width,
                                          locationY >= 0,
                                          locationY <= proxy.plotAreaSize.height,
                                          let year = proxy.value(atX: locationX, as: Int.self) else {
                                        selectedYear = nil
                                        return
                                    }
                                    selectedYear = String(year)
                                }
                        )
                }
            }

            if let selectedYear {
                let lines = [
                    selectedYear,
                    "Ingresos totales · \(maskedCurrency(selectedIncomePoint?.totalIncome, hideSensitive: hideSensitiveValues))",
                    "Salario Telefónica · \(maskedCurrency(selectedSalaryPoint?.salary, hideSensitive: hideSensitiveValues))"
                ]
                ProfileFloatingTooltip(lines: lines, accent: AppTheme.accentOrange)
                    .padding(.top, 8)
                    .padding(.leading, 8)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedYear = nil
        }
    }
}

private struct ProfileSalaryStackedChart: View {
    let points: [ProfileSalaryPoint]
    let hideSensitiveValues: Bool

    @State private var selectedYear: String?

    private var selectedPoint: ProfileSalaryPoint? {
        guard let selectedYear else { return nil }
        return points.first(where: { String($0.year) == selectedYear })
    }

    var body: some View {
        let years = points.map(\.year)
        let labels = sampledProfileYearLabels(from: years).map(Double.init)
        let domainStart = Double((years.first ?? 0)) - 0.6
        let domainEnd = Double((years.last ?? 1)) + 0.6

        ZStack(alignment: .topLeading) {
            Chart {
                ForEach(points) { point in
                    let startX = Double(point.year) - 0.32
                    let endX = Double(point.year) + 0.32

                    RectangleMark(
                        xStart: .value("Inicio", startX),
                        xEnd: .value("Fin", endX),
                        yStart: .value("Base", 0),
                        yEnd: .value("Salario bruto", point.grossSalary)
                    )
                    .foregroundStyle(AppTheme.accentBlue)
                    .cornerRadius(5)

                    if point.bonus > 0 {
                        RectangleMark(
                            xStart: .value("Inicio", startX),
                            xEnd: .value("Fin", endX),
                            yStart: .value("Bonus base", point.grossSalary),
                            yEnd: .value("Bonus", point.grossSalary + point.bonus)
                        )
                        .foregroundStyle(AppTheme.accentOrange)
                        .cornerRadius(5)
                    }

                    if point.topPerformer > 0 {
                        RectangleMark(
                            xStart: .value("Inicio", startX),
                            xEnd: .value("Fin", endX),
                            yStart: .value("Top base", point.grossSalary + point.bonus),
                            yEnd: .value("Top performer", point.salary)
                        )
                        .foregroundStyle(AppTheme.accentPurple)
                        .cornerRadius(5)
                    }
                }
            }
            .chartXScale(domain: domainStart...domainEnd, range: .plotDimension(padding: 14))
            .chartXAxis {
                AxisMarks(values: labels) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let year = value.as(Double.self) {
                            Text(String(Int(year.rounded())))
                                .foregroundStyle(AppTheme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(hideSensitiveValues ? "•••" : amount.compactCurrencyString)
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            SpatialTapGesture()
                                .onEnded { gesture in
                                    let frame = geometry[proxy.plotAreaFrame]
                                    let locationX = gesture.location.x - frame.origin.x
                                    let locationY = gesture.location.y - frame.origin.y
                                    guard locationX >= 0,
                                          locationX <= proxy.plotAreaSize.width,
                                          locationY >= 0,
                                          locationY <= proxy.plotAreaSize.height,
                                          let tappedYear = proxy.value(atX: locationX, as: Double.self) else {
                                        selectedYear = nil
                                        return
                                    }
                                    let nearestYear = years.min(by: { abs(Double($0) - tappedYear) < abs(Double($1) - tappedYear) })
                                    selectedYear = nearestYear.map(String.init)
                                }
                        )
                }
            }

            if let selectedPoint {
                let lines = [
                    String(selectedPoint.year),
                    "Salario bruto · \(maskedCurrency(selectedPoint.grossSalary, hideSensitive: hideSensitiveValues))",
                    "Bonus · \(maskedCurrency(selectedPoint.bonus, hideSensitive: hideSensitiveValues))"
                ] + (selectedPoint.topPerformer > 0 ? ["Top performer · \(maskedCurrency(selectedPoint.topPerformer, hideSensitive: hideSensitiveValues))"] : []) + [
                    "Total · \(maskedCurrency(selectedPoint.salary, hideSensitive: hideSensitiveValues))"
                ]

                ProfileFloatingTooltip(lines: lines, accent: AppTheme.accentPurple)
                    .padding(.top, 8)
                    .padding(.leading, 8)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: DashboardTooltipDismissal.notification)) { _ in
            selectedYear = nil
        }
    }
}

private struct ProfileTableHeaderCell: View {
    let title: String
    let width: CGFloat
    var alignment: Alignment = .center

    var body: some View {
        Text(title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(width: width, alignment: horizontalAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .background(AppTheme.surface.opacity(0.62))
    }

    private var horizontalAlignment: Alignment {
        alignment == .leading ? .leading : .center
    }
}

private struct ProfileTableValueCell: View {
    let text: String
    let width: CGFloat
    var alignment: Alignment = .center
    var emphasized: Bool = false

    var body: some View {
        Text(text)
            .font(emphasized ? .caption.weight(.bold) : .caption2.weight(.semibold))
            .foregroundStyle(emphasized ? AppTheme.textPrimary : AppTheme.textSecondary)
            .frame(width: width, alignment: horizontalAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
    }

    private var horizontalAlignment: Alignment {
        alignment == .leading ? .leading : .center
    }
}


private struct ProfileFloatingTooltip: View {
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

private struct ProfileAvatarView: View {
    var body: some View {
        Group {
            if let image = UIImage(named: "profile_photo") {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(LinearGradient(colors: [AppTheme.accentBlue, AppTheme.accentPurple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("DMB")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}

private func sampledProfileYearLabels(from years: [Int]) -> [Int] {
    guard years.count > 4 else { return years }
    let maxLabels: Int
    if years.count > 10 {
        maxLabels = 5
    } else if years.count > 7 {
        maxLabels = 4
    } else {
        maxLabels = 5
    }
    let step = max(Int(ceil(Double(years.count) / Double(maxLabels))), 1)
    return years.enumerated().compactMap { index, year in
        index % step == 0 || index == years.count - 1 ? year : nil
    }
}

private func maskedCurrency(_ value: Double?, hideSensitive: Bool) -> String {
    guard let value else { return "-" }
    return hideSensitive ? "••••••" : value.currencyString
}

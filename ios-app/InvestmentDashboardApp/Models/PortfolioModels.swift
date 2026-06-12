import Foundation

struct PortfolioPayload: Decodable {
    let generatedAt: String?
    let latestDate: String?
    let dates: [String]
    let snapshots: [String: [PortfolioPosition]]
    let series: [PortfolioSeriesPoint]?
    let contributionPlan: ContributionPlanPayload?
    let profile: ProfilePayload?
}

struct PortfolioSeriesPoint: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let label: String
    let grossAssets: Double
    let liabilities: Double
    let netWorth: Double
    let contribution: Double
    let profit: Double
}



struct ProfilePayload: Decodable, Equatable {
    let fullName: String?
    let salaryEvolution: [ProfileSalaryPoint]?
    let totalIncomeAnnual: [ProfileAnnualIncomePoint]?

    static let placeholder = ProfilePayload(
        fullName: "Denis Martín Barroso",
        salaryEvolution: [
            ProfileSalaryPoint(year: 2016, grossSalary: 44032, bonus: 2078, topPerformer: 0, salary: 46110),
            ProfileSalaryPoint(year: 2017, grossSalary: 47245, bonus: 7490, topPerformer: 0, salary: 54735),
            ProfileSalaryPoint(year: 2018, grossSalary: 48190, bonus: 8326, topPerformer: 0, salary: 56516),
            ProfileSalaryPoint(year: 2019, grossSalary: 55135, bonus: 17849, topPerformer: 4000, salary: 76984),
            ProfileSalaryPoint(year: 2020, grossSalary: 70770, bonus: 18206, topPerformer: 0, salary: 88976),
            ProfileSalaryPoint(year: 2021, grossSalary: 75209, bonus: 19248, topPerformer: 0, salary: 94457),
            ProfileSalaryPoint(year: 2022, grossSalary: 86433, bonus: 23098, topPerformer: 0, salary: 109531),
            ProfileSalaryPoint(year: 2023, grossSalary: 95214, bonus: 26084, topPerformer: 0, salary: 121298),
            ProfileSalaryPoint(year: 2024, grossSalary: 108640, bonus: 32340, topPerformer: 0, salary: 140980),
            ProfileSalaryPoint(year: 2025, grossSalary: 119680, bonus: 34660, topPerformer: 0, salary: 154340)
        ],
        totalIncomeAnnual: [
            ProfileAnnualIncomePoint(year: 2020, totalIncome: 92000),
            ProfileAnnualIncomePoint(year: 2021, totalIncome: 105000),
            ProfileAnnualIncomePoint(year: 2022, totalIncome: 124000),
            ProfileAnnualIncomePoint(year: 2023, totalIncome: 138000),
            ProfileAnnualIncomePoint(year: 2024, totalIncome: 154000),
            ProfileAnnualIncomePoint(year: 2025, totalIncome: 171000)
        ]
    )
}

struct ProfileSalaryPoint: Decodable, Identifiable, Hashable {
    var id: Int { year }
    let year: Int
    let grossSalary: Double
    let bonus: Double
    let topPerformer: Double
    let salary: Double
}

struct ProfileAnnualIncomePoint: Decodable, Identifiable, Hashable {
    var id: Int { year }
    let year: Int
    let totalIncome: Double
}

struct ContributionPlanPayload: Decodable, Equatable {
    let assets: [ContributionPlanAsset]
    let totalMonthly: Double
    let totalAnnual: Double
    let totalMonthlyEquity: Double
    let totalMonthlyFixedIncome: Double
    let averageMonthly: Double
    let assetCount: Int
    let error: String?
}

struct ContributionPlanAsset: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let type: String
    let allocation: String
    let monthlyAmount: Double
    let annualTotal: Double
    let monthlyEquityAmount: Double
    let monthlyFixedAmount: Double
}

struct PortfolioPosition: Decodable, Identifiable, Hashable {
    var id: String { "\(date)-\(name)-\(type)" }

    let name: String
    let date: String
    let dateLabel: String?
    let type: String
    let shares: Double
    let unitPrice: Double
    let value: Double
    let contribution: Double
    let profit: Double
    let ter: Double
    let isin: String
}

struct PortfolioSummary: Equatable {
    let grossAssets: Double
    let netWorth: Double
    let investedValue: Double
    let liquidity: Double
    let debt: Double
    let totalContribution: Double
    let profit: Double
    let roi: Double
    let investedRatio: Double
    let positions: [PortfolioPosition]
    let topPositions: [PortfolioPosition]

    static let empty = PortfolioSummary(
        grossAssets: 0,
        netWorth: 0,
        investedValue: 0,
        liquidity: 0,
        debt: 0,
        totalContribution: 0,
        profit: 0,
        roi: 0,
        investedRatio: 0,
        positions: [],
        topPositions: []
    )
}

struct TimelinePoint: Identifiable, Equatable {
    let id: String
    let index: Int
    let date: Date
    let label: String
    let grossAssets: Double
    let netWorth: Double
    let investedValue: Double
    let liquidity: Double
    let debt: Double
    let contribution: Double
    let profit: Double
    let roi: Double
    let investedRatio: Double
}

struct AllocationSlice: Identifiable, Hashable {
    var id: String { type }
    let type: String
    let value: Double
    let share: Double
    let profit: Double
}

struct AllocationHistoryPoint: Identifiable, Hashable {
    let id: String
    let index: Int
    let label: String
    let type: String
    let share: Double
    let value: Double
}

struct TypePerformance: Identifiable, Hashable {
    var id: String { type }
    let type: String
    let value: Double
    let contribution: Double
    let profit: Double
    let roi: Double
    let share: Double
}

struct AssetProfitHistoryPoint: Identifiable, Hashable {
    let id: String
    let index: Int
    let label: String
    let asset: String
    let profit: Double
}

struct SnapshotComparisonMetric: Identifiable, Hashable {
    enum Format {
        case currency
        case percent
    }

    let id: String
    let title: String
    let baseValue: Double
    let targetValue: Double
    let delta: Double
    let deltaRatio: Double?
    let format: Format
}

extension PortfolioPayload {
    var sortedDates: [String] {
        dates.sorted { DashboardDateFormatter.parseISO($0) < DashboardDateFormatter.parseISO($1) }
    }

    var availableTypes: [String] {
        Array(Set(snapshots.values.flatMap { $0.map(\.type) })).filter { !$0.isEmpty }.sorted()
    }

    var defaultComparisonDates: (String?, String?) {
        let sorted = sortedDates
        guard let target = latestDate ?? sorted.last else { return (nil, nil) }
        let base = sorted.dropLast().last ?? target
        return (base, target)
    }

    func filteredPositions(for date: String?, includedTypes: Set<String>) -> [PortfolioPosition] {
        guard let selectedDate = date ?? latestDate else { return [] }
        return (snapshots[selectedDate] ?? []).filter { includedTypes.contains($0.type) }
    }

    func summary(for date: String?, includedTypes: Set<String>) -> PortfolioSummary {
        let positions = filteredPositions(for: date, includedTypes: includedTypes)
        guard !positions.isEmpty else { return .empty }

        let positivePositions = positions.filter { $0.value > 0 }
        let investedPositions = positivePositions.filter { $0.type != "Cuentas Corrientes" }
        let liquidity = positivePositions.filter { $0.type == "Cuentas Corrientes" }.reduce(0) { $0 + $1.value }
        let grossAssets = positivePositions.reduce(0) { $0 + $1.value }
        let debt = abs(positions.filter { $0.value < 0 }.reduce(0) { $0 + $1.value })
        let netWorth = grossAssets - debt
        let investedValue = investedPositions.reduce(0) { $0 + $1.value }
        let totalContribution = investedPositions.reduce(0) { $0 + $1.contribution }
        let investedProfit = investedPositions.reduce(0) { $0 + $1.profit }
        let profit = positions.reduce(0) { $0 + $1.profit }
        let roi = totalContribution == 0 ? 0 : investedProfit / totalContribution
        let investedRatio = grossAssets == 0 ? 0 : investedValue / grossAssets
        let topPositions = positivePositions.sorted { $0.value > $1.value }

        return PortfolioSummary(
            grossAssets: grossAssets,
            netWorth: netWorth,
            investedValue: investedValue,
            liquidity: liquidity,
            debt: debt,
            totalContribution: totalContribution,
            profit: profit,
            roi: roi,
            investedRatio: investedRatio,
            positions: positions.sorted { $0.value > $1.value },
            topPositions: Array(topPositions.prefix(8))
        )
    }

    func timelinePoints(includedTypes: Set<String>, limit: Int? = nil) -> [TimelinePoint] {
        let datesToUse = recentDates(limit: limit)
        let raw = datesToUse.compactMap { date -> (String, PortfolioSummary)? in
            let summary = summary(for: date, includedTypes: includedTypes)
            return summary.positions.isEmpty ? nil : (date, summary)
        }
        return raw.enumerated().map { offset, element in
            let date = element.0
            let summary = element.1
            return TimelinePoint(
                id: date,
                index: offset,
                date: DashboardDateFormatter.parseISO(date),
                label: DashboardDateFormatter.display(date),
                grossAssets: summary.grossAssets,
                netWorth: summary.netWorth,
                investedValue: summary.investedValue,
                liquidity: summary.liquidity,
                debt: summary.debt,
                contribution: summary.totalContribution,
                profit: summary.profit,
                roi: summary.roi,
                investedRatio: summary.investedRatio
            )
        }
    }

    func allocation(for date: String?, includedTypes: Set<String>) -> [AllocationSlice] {
        let positions = filteredPositions(for: date, includedTypes: includedTypes).filter { $0.value > 0 }
        let grossAssets = max(positions.reduce(0) { $0 + $1.value }, 1)
        let grouped = Dictionary(grouping: positions, by: \.type)
        return grouped.map { type, positions in
            let value = positions.reduce(0) { $0 + $1.value }
            let profit = positions.reduce(0) { $0 + $1.profit }
            return AllocationSlice(type: type, value: value, share: value / grossAssets, profit: profit)
        }.sorted { $0.value > $1.value }
    }

    func allocationHistory(limit: Int?, includedTypes: Set<String>) -> [AllocationHistoryPoint] {
        let datesToUse = recentDates(limit: limit)
        var points: [AllocationHistoryPoint] = []
        var outputIndex = 0
        for date in datesToUse {
            let slices = allocation(for: date, includedTypes: includedTypes)
            guard !slices.isEmpty else { continue }
            let label = DashboardDateFormatter.display(date)
            for slice in slices {
                points.append(AllocationHistoryPoint(id: "\(date)-\(slice.type)", index: outputIndex, label: label, type: slice.type, share: slice.share, value: slice.value))
            }
            outputIndex += 1
        }
        return points
    }

    func typePerformance(for date: String?, includedTypes: Set<String>) -> [TypePerformance] {
        let positions = filteredPositions(for: date, includedTypes: includedTypes).filter { $0.value > 0 }
        let total = max(positions.reduce(0) { $0 + $1.value }, 1)
        let grouped = Dictionary(grouping: positions, by: \.type)
        return grouped.map { type, positions in
            let value = positions.reduce(0) { $0 + $1.value }
            let contribution = positions.reduce(0) { $0 + $1.contribution }
            let profit = positions.reduce(0) { $0 + $1.profit }
            let roi = contribution == 0 ? 0 : profit / contribution
            return TypePerformance(type: type, value: value, contribution: contribution, profit: profit, roi: roi, share: value / total)
        }.sorted { $0.value > $1.value }
    }

    func assetProfitHistory(limit: Int?, includedTypes: Set<String>) -> [AssetProfitHistoryPoint] {
        let datesToUse = recentDates(limit: limit)
        var points: [AssetProfitHistoryPoint] = []
        var outputIndex = 0
        for date in datesToUse {
            let positions = filteredPositions(for: date, includedTypes: includedTypes)
                .filter { $0.value > 0 && abs($0.profit) > 0.01 }
                .sorted { $0.profit > $1.profit }
            guard !positions.isEmpty else { continue }
            let label = DashboardDateFormatter.display(date)
            for position in positions {
                points.append(AssetProfitHistoryPoint(id: "\(date)-\(position.name)", index: outputIndex, label: label, asset: position.name, profit: position.profit))
            }
            outputIndex += 1
        }
        return points
    }

    func comparisonMetrics(baseDate: String?, targetDate: String?, includedTypes: Set<String>) -> [SnapshotComparisonMetric] {
        let baseSummary = summary(for: baseDate, includedTypes: includedTypes)
        let targetSummary = summary(for: targetDate, includedTypes: includedTypes)
        return [
            SnapshotComparisonMetric(id: "gross", title: "Activos brutos", baseValue: baseSummary.grossAssets, targetValue: targetSummary.grossAssets, delta: targetSummary.grossAssets - baseSummary.grossAssets, deltaRatio: baseSummary.grossAssets == 0 ? nil : (targetSummary.grossAssets - baseSummary.grossAssets) / baseSummary.grossAssets, format: .currency),
            SnapshotComparisonMetric(id: "net", title: "Patrimonio neto", baseValue: baseSummary.netWorth, targetValue: targetSummary.netWorth, delta: targetSummary.netWorth - baseSummary.netWorth, deltaRatio: baseSummary.netWorth == 0 ? nil : (targetSummary.netWorth - baseSummary.netWorth) / baseSummary.netWorth, format: .currency),
            SnapshotComparisonMetric(id: "invested", title: "Capital invertido", baseValue: baseSummary.investedValue, targetValue: targetSummary.investedValue, delta: targetSummary.investedValue - baseSummary.investedValue, deltaRatio: baseSummary.investedValue == 0 ? nil : (targetSummary.investedValue - baseSummary.investedValue) / baseSummary.investedValue, format: .currency),
            SnapshotComparisonMetric(id: "profit", title: "Beneficio", baseValue: baseSummary.profit, targetValue: targetSummary.profit, delta: targetSummary.profit - baseSummary.profit, deltaRatio: baseSummary.profit == 0 ? nil : (targetSummary.profit - baseSummary.profit) / abs(baseSummary.profit), format: .currency),
            SnapshotComparisonMetric(id: "liquidity", title: "Liquidez", baseValue: baseSummary.liquidity, targetValue: targetSummary.liquidity, delta: targetSummary.liquidity - baseSummary.liquidity, deltaRatio: baseSummary.liquidity == 0 ? nil : (targetSummary.liquidity - baseSummary.liquidity) / baseSummary.liquidity, format: .currency),
            SnapshotComparisonMetric(id: "roi", title: "ROI", baseValue: baseSummary.roi, targetValue: targetSummary.roi, delta: targetSummary.roi - baseSummary.roi, deltaRatio: nil, format: .percent),
        ]
    }

    func filteredContributionPlan(includedTypes: Set<String>) -> ContributionPlanPayload? {
        guard let contributionPlan else { return nil }
        let assets = contributionPlan.assets.filter { includedTypes.contains($0.type) }
        let totalMonthly = assets.reduce(0) { $0 + $1.monthlyAmount }
        let totalAnnual = assets.reduce(0) { $0 + $1.annualTotal }
        let totalMonthlyEquity = assets.reduce(0) { $0 + $1.monthlyEquityAmount }
        let totalMonthlyFixedIncome = assets.reduce(0) { $0 + $1.monthlyFixedAmount }
        return ContributionPlanPayload(assets: assets, totalMonthly: totalMonthly, totalAnnual: totalAnnual, totalMonthlyEquity: totalMonthlyEquity, totalMonthlyFixedIncome: totalMonthlyFixedIncome, averageMonthly: totalMonthly, assetCount: assets.count, error: contributionPlan.error)
    }

    func recentDates(limit: Int?) -> [String] {
        let sorted = sortedDates
        guard let limit, limit > 0, let latest = sorted.last.map(DashboardDateFormatter.parseISO) else { return sorted }
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .month, value: -limit, to: latest) else { return sorted }
        let filtered = sorted.filter { DashboardDateFormatter.parseISO($0) >= cutoff }
        return filtered.isEmpty ? [sorted.last!].compactMap { $0 } : filtered
    }
}

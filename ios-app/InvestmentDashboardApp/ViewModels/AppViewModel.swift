import Foundation

struct DashboardDerivedState: Equatable {
    let availableTypes: [String]
    let availableDatesDescending: [String]
    let summary: PortfolioSummary
    let timeline: [TimelinePoint]
    let allocations: [AllocationSlice]
    let allocationHistory: [AllocationHistoryPoint]
    let typePerformance: [TypePerformance]
    let performanceTimeline: [TimelinePoint]
    let profitHistoryByAsset: [AssetProfitHistoryPoint]
    let comparisonMetrics: [SnapshotComparisonMetric]
    let comparisonBaseSummary: PortfolioSummary
    let comparisonTargetSummary: PortfolioSummary
    let contributionPlan: ContributionPlanPayload?
    let profile: ProfilePayload

    static let empty = DashboardDerivedState(
        availableTypes: [],
        availableDatesDescending: [],
        summary: .empty,
        timeline: [],
        allocations: [],
        allocationHistory: [],
        typePerformance: [],
        performanceTimeline: [],
        profitHistoryByAsset: [],
        comparisonMetrics: [],
        comparisonBaseSummary: .empty,
        comparisonTargetSummary: .empty,
        contributionPlan: nil,
        profile: .placeholder
    )
}

@MainActor
final class AppViewModel: ObservableObject {
    enum Route {
        case loading
        case login
        case dashboard
    }

    enum TrajectoryMode: String, CaseIterable, Identifiable {
        case grossAssets = "Activos brutos"
        case netWorth = "Patrimonio neto"
        case profit = "Beneficio"
        var id: String { rawValue }
    }

    @Published var route: Route = .loading
    @Published var isBusy = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var payload: PortfolioPayload?
    @Published var selectedDate: String? { didSet { guard !isApplyingSelectionState, oldValue != selectedDate else { return }; refreshDerivedState() } }
    @Published var trajectoryMode: TrajectoryMode = .grossAssets
    @Published var allocationRangeMonths: Int = 30 { didSet { guard !isApplyingSelectionState, oldValue != allocationRangeMonths else { return }; refreshDerivedState() } }
    @Published var performanceRangeMonths: Int = 36 { didSet { guard !isApplyingSelectionState, oldValue != performanceRangeMonths else { return }; refreshDerivedState() } }
    @Published var comparisonBaseDate: String? { didSet { guard !isApplyingSelectionState, oldValue != comparisonBaseDate else { return }; refreshDerivedState() } }
    @Published var comparisonTargetDate: String? { didSet { guard !isApplyingSelectionState, oldValue != comparisonTargetDate else { return }; refreshDerivedState() } }
    @Published var selectedTypes: Set<String> = [] { didSet { guard !isApplyingSelectionState, oldValue != selectedTypes else { return }; refreshDerivedState() } }
    @Published var isTypeFilterPresented = false
    @Published var isProfilePresented = false
    @Published private(set) var derived = DashboardDerivedState.empty

    private var isApplyingSelectionState = false

    let rangeOptions: [Int] = [6, 12, 18, 24, 30, 36, 54]

    var availableTypes: [String] { derived.availableTypes }
    var activeTypeCountLabel: String { "\(selectedTypes.count) activos seleccionados" }
    var performanceRangeLabel: String { "Últimos \(performanceRangeMonths) meses" }
    var allocationRangeLabel: String { "Últimos \(allocationRangeMonths) meses" }

    var summary: PortfolioSummary { derived.summary }
    var timeline: [TimelinePoint] { derived.timeline }
    var selectedDateLabel: String { guard let selectedDate else { return "-" }; return DashboardDateFormatter.display(selectedDate) }
    var allocations: [AllocationSlice] { derived.allocations }
    var allocationHistory: [AllocationHistoryPoint] { derived.allocationHistory }
    var typePerformance: [TypePerformance] { derived.typePerformance }
    var performanceTimeline: [TimelinePoint] { derived.performanceTimeline }
    var profitHistoryByAsset: [AssetProfitHistoryPoint] { derived.profitHistoryByAsset }
    var comparisonMetrics: [SnapshotComparisonMetric] { derived.comparisonMetrics }
    var comparisonBaseSummary: PortfolioSummary { derived.comparisonBaseSummary }
    var comparisonTargetSummary: PortfolioSummary { derived.comparisonTargetSummary }
    var contributionPlan: ContributionPlanPayload? { derived.contributionPlan }
    var availableDatesDescending: [String] { derived.availableDatesDescending }
    var profile: ProfilePayload { derived.profile }

    func bootstrap() async { await refreshSession() }

    func refreshSession() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let payload = try await APIClient.shared.fetchPortfolio()
            apply(payload: payload)
            route = .dashboard
            errorMessage = nil
        } catch APIError.unauthorized {
            route = .login
            errorMessage = nil
        } catch {
            route = .login
            errorMessage = error.localizedDescription
        }
    }

    func refreshDashboard() async {
        guard route == .dashboard else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let payload = try await APIClient.shared.fetchPortfolio()
            apply(payload: payload)
            errorMessage = nil
        } catch APIError.unauthorized {
            route = .login
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func login(username: String, password: String) async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "Introduce usuario y contraseña."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            try await APIClient.shared.login(username: username, password: password)
            errorMessage = nil
            await refreshSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        isBusy = true
        await APIClient.shared.logout()
        isApplyingSelectionState = true
        payload = nil
        selectedDate = nil
        comparisonBaseDate = nil
        comparisonTargetDate = nil
        selectedTypes = []
        isApplyingSelectionState = false
        derived = .empty
        route = .login
        isBusy = false
    }

    func selectAllTypes() {
        let fullSet = Set(availableTypes)
        guard selectedTypes != fullSet else { return }
        selectedTypes = fullSet
    }

    func clearAllTypes() {
        guard !availableTypes.isEmpty else { return }
        selectedTypes = Set(availableTypes)
    }

    func isTypeSelected(_ type: String) -> Bool { selectedTypes.contains(type) }

    func toggleType(_ type: String) {
        var next = selectedTypes
        if next.contains(type) {
            next.remove(type)
        } else {
            next.insert(type)
        }
        if next.isEmpty {
            next = Set(availableTypes)
        }
        guard next != selectedTypes else { return }
        selectedTypes = next
    }

    func trajectoryValue(for item: TimelinePoint) -> Double {
        switch trajectoryMode {
        case .grossAssets: return item.grossAssets
        case .netWorth: return item.netWorth
        case .profit: return item.profit
        }
    }

    private func apply(payload: PortfolioPayload) {
        isApplyingSelectionState = true
        self.payload = payload

        let availableTypes = Set(payload.availableTypes)
        if selectedTypes.isEmpty {
            selectedTypes = availableTypes
        } else {
            let intersection = selectedTypes.intersection(availableTypes)
            selectedTypes = intersection.isEmpty ? availableTypes : intersection
        }

        if selectedDate == nil || !(payload.dates.contains(selectedDate ?? "")) {
            selectedDate = payload.latestDate ?? payload.dates.last
        }

        let defaults = payload.defaultComparisonDates
        if comparisonTargetDate == nil || !(payload.dates.contains(comparisonTargetDate ?? "")) {
            comparisonTargetDate = defaults.1
        }
        if comparisonBaseDate == nil || !(payload.dates.contains(comparisonBaseDate ?? "")) {
            comparisonBaseDate = defaults.0
        }

        isApplyingSelectionState = false
        refreshDerivedState()
    }

    private func refreshDerivedState() {
        guard let payload else {
            derived = .empty
            return
        }

        let newDerived = DashboardDerivedState(
            availableTypes: payload.availableTypes,
            availableDatesDescending: Array(payload.sortedDates.reversed()),
            summary: payload.summary(for: selectedDate, includedTypes: selectedTypes),
            timeline: payload.timelinePoints(includedTypes: selectedTypes),
            allocations: payload.allocation(for: selectedDate, includedTypes: selectedTypes),
            allocationHistory: payload.allocationHistory(limit: allocationRangeMonths, includedTypes: selectedTypes),
            typePerformance: payload.typePerformance(for: selectedDate, includedTypes: selectedTypes),
            performanceTimeline: payload.timelinePoints(includedTypes: selectedTypes, limit: performanceRangeMonths),
            profitHistoryByAsset: payload.assetProfitHistory(limit: performanceRangeMonths, includedTypes: selectedTypes),
            comparisonMetrics: payload.comparisonMetrics(baseDate: comparisonBaseDate, targetDate: comparisonTargetDate, includedTypes: selectedTypes),
            comparisonBaseSummary: payload.summary(for: comparisonBaseDate, includedTypes: selectedTypes),
            comparisonTargetSummary: payload.summary(for: comparisonTargetDate, includedTypes: selectedTypes),
            contributionPlan: payload.filteredContributionPlan(includedTypes: selectedTypes),
            profile: payload.profile ?? .placeholder
        )

        guard newDerived != derived else { return }
        derived = newDerived
    }
}

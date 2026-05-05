import Foundation

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
    @Published var selectedDate: String?
    @Published var trajectoryMode: TrajectoryMode = .grossAssets
    @Published var allocationRangeMonths: Int = 30
    @Published var performanceRangeMonths: Int = 36
    @Published var comparisonBaseDate: String?
    @Published var comparisonTargetDate: String?
    @Published var selectedTypes: Set<String> = []
    @Published var isTypeFilterPresented = false
    @Published var isProfilePresented = false

    let rangeOptions: [Int] = [6, 12, 18, 24, 30, 36, 54]

    var availableTypes: [String] { payload?.availableTypes ?? [] }
    var activeTypeCountLabel: String { "\(selectedTypes.count) activos seleccionados" }
    var performanceRangeLabel: String { "Últimos \(performanceRangeMonths) meses" }
    var allocationRangeLabel: String { "Últimos \(allocationRangeMonths) meses" }

    var summary: PortfolioSummary { payload?.summary(for: selectedDate, includedTypes: selectedTypes) ?? .empty }
    var timeline: [TimelinePoint] { payload?.timelinePoints(includedTypes: selectedTypes) ?? [] }
    var selectedDateLabel: String { guard let selectedDate else { return "-" }; return DashboardDateFormatter.display(selectedDate) }
    var allocations: [AllocationSlice] { payload?.allocation(for: selectedDate, includedTypes: selectedTypes) ?? [] }
    var allocationHistory: [AllocationHistoryPoint] { payload?.allocationHistory(limit: allocationRangeMonths, includedTypes: selectedTypes) ?? [] }
    var typePerformance: [TypePerformance] { payload?.typePerformance(for: selectedDate, includedTypes: selectedTypes) ?? [] }
    var performanceTimeline: [TimelinePoint] { payload?.timelinePoints(includedTypes: selectedTypes, limit: performanceRangeMonths) ?? [] }
    var profitHistoryByAsset: [AssetProfitHistoryPoint] { payload?.assetProfitHistory(limit: performanceRangeMonths, includedTypes: selectedTypes) ?? [] }
    var comparisonMetrics: [SnapshotComparisonMetric] { payload?.comparisonMetrics(baseDate: comparisonBaseDate, targetDate: comparisonTargetDate, includedTypes: selectedTypes) ?? [] }
    var comparisonBaseSummary: PortfolioSummary { payload?.summary(for: comparisonBaseDate, includedTypes: selectedTypes) ?? .empty }
    var comparisonTargetSummary: PortfolioSummary { payload?.summary(for: comparisonTargetDate, includedTypes: selectedTypes) ?? .empty }
    var contributionPlan: ContributionPlanPayload? { payload?.filteredContributionPlan(includedTypes: selectedTypes) }
    var availableDatesDescending: [String] { payload?.sortedDates.reversed() ?? [] }
    var profile: ProfilePayload { payload?.profile ?? .placeholder }

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
        payload = nil
        selectedDate = nil
        comparisonBaseDate = nil
        comparisonTargetDate = nil
        route = .login
        isBusy = false
    }

    func selectAllTypes() { selectedTypes = Set(availableTypes) }
    func clearAllTypes() { selectedTypes = [] }
    func isTypeSelected(_ type: String) -> Bool { selectedTypes.contains(type) }
    func toggleType(_ type: String) {
        if selectedTypes.contains(type) { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
        if selectedTypes.isEmpty { selectedTypes = Set(availableTypes) }
    }

    func trajectoryValue(for item: TimelinePoint) -> Double {
        switch trajectoryMode {
        case .grossAssets: return item.grossAssets
        case .netWorth: return item.netWorth
        case .profit: return item.profit
        }
    }

    private func apply(payload: PortfolioPayload) {
        self.payload = payload
        if selectedTypes.isEmpty {
            selectedTypes = Set(payload.availableTypes)
        } else {
            selectedTypes = selectedTypes.intersection(Set(payload.availableTypes))
            if selectedTypes.isEmpty { selectedTypes = Set(payload.availableTypes) }
        }
        if selectedDate == nil || !(payload.dates.contains(selectedDate ?? "")) { selectedDate = payload.latestDate ?? payload.dates.last }
        let defaults = payload.defaultComparisonDates
        if comparisonTargetDate == nil || !(payload.dates.contains(comparisonTargetDate ?? "")) { comparisonTargetDate = defaults.1 }
        if comparisonBaseDate == nil || !(payload.dates.contains(comparisonBaseDate ?? "")) { comparisonBaseDate = defaults.0 }
    }
}

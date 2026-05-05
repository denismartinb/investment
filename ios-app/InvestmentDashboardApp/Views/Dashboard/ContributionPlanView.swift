import SwiftUI
import Charts

struct ContributionPlanView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let plan = appViewModel.contributionPlan {
                    summaryCard(plan: plan)
                    monthlyContributionCard(plan: plan)
                    monthlyAllocationMixCard(plan: plan)
                } else {
                    PremiumPanel(highlight: AppTheme.accentBlue) {
                        Text("No hay plan de aportaciones disponible.").foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("Plan")
    }

    private func summaryCard(plan: ContributionPlanPayload) -> some View {
        PremiumPanel(highlight: AppTheme.accentBlue) {
            SectionHeader(title: "Plan de aportaciones", subtitle: "Ritmo mensual y capacidad anual comprometida.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                DashboardMetricCard(title: "Mensual", value: plan.totalMonthly.currencyString, subtitle: "Ritmo total de aportación", accent: AppTheme.accentBlue)
                DashboardMetricCard(title: "Anual", value: plan.totalAnnual.currencyString, subtitle: "Resumen del año equivalente", accent: AppTheme.positive)
                DashboardMetricCard(title: "Renta variable", value: plan.totalMonthlyEquity.currencyString, subtitle: plan.totalMonthlyEquity.percentOf(max(plan.totalMonthly, 1)).percentString + " del flujo mensual", accent: AppTheme.accentPurple)
                DashboardMetricCard(title: "Renta fija", value: plan.totalMonthlyFixedIncome.currencyString, subtitle: plan.totalMonthlyFixedIncome.percentOf(max(plan.totalMonthly, 1)).percentString + " del flujo mensual", accent: AppTheme.accentOrange)
            }
        }
    }

    private func monthlyContributionCard(plan: ContributionPlanPayload) -> some View {
        PremiumPanel(highlight: AppTheme.accentPurple) {
            SectionHeader(title: "Aportación mensual por activo", subtitle: "Distribución del flujo mensual entre los distintos vehículos.")
            Chart(plan.assets) { asset in
                BarMark(x: .value("Aportación", asset.monthlyAmount), y: .value("Activo", asset.name))
                    .foregroundStyle(AppTheme.color(for: asset.type).gradient)
                    .cornerRadius(5)
            }
            .frame(height: max(300, CGFloat(plan.assets.count) * 50))
            .chartXAxis {
                AxisMarks(position: .bottom, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(AppTheme.axis)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount.compactCurrencyString).foregroundStyle(AppTheme.textMuted).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let name = value.as(String.self) {
                            Text(name).foregroundStyle(AppTheme.textSecondary).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
    }

    private func monthlyAllocationMixCard(plan: ContributionPlanPayload) -> some View {
        let mix = [MixSlice(name: "Renta variable", value: plan.totalMonthlyEquity, color: AppTheme.accentPurple), MixSlice(name: "Renta fija", value: plan.totalMonthlyFixedIncome, color: AppTheme.accentOrange)].filter { $0.value > 0 }
        return PremiumPanel(highlight: AppTheme.accentOrange) {
            SectionHeader(title: "Mix mensual", subtitle: "Reparto simple entre renta variable y renta fija.")
            Chart(mix) { item in
                SectorMark(angle: .value("Valor", item.value), innerRadius: .ratio(0.55), angularInset: 3)
                    .foregroundStyle(item.color)
                    .annotation(position: .overlay) {
                        Text(item.value.percentOf(max(plan.totalMonthly, 1)).percentString).font(.caption2.weight(.bold)).foregroundStyle(.white)
                    }
            }
            .frame(height: 240)
            .chartLegend(.hidden)
            ChartLegendRow(items: mix.map { ($0.name, $0.color) })
        }
    }
}

private struct MixSlice: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let color: Color
}

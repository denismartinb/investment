import SwiftUI

struct AllocationView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                treeMapCard
                historicalAllocationCard
                typeListCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .onTapGesture {
            DashboardTooltipDismissal.post()
        }
        .navigationTitle("Asignación")
    }

    private var treeMapCard: some View {
        PremiumPanel(highlight: AppTheme.accentOrange) {
            SectionHeader(title: "Asignación por tipo", subtitle: "Peso actual de cada familia dentro del patrimonio bruto.")
            TreeMapView(items: appViewModel.allocations.map { TreeMapItem(title: $0.type, value: $0.value, share: $0.share, color: AppTheme.color(for: $0.type)) })
                .frame(height: 338)
        }
    }

    private var historicalAllocationCard: some View {
        PremiumPanel(highlight: AppTheme.accentPurple) {
            SectionHeader(title: "Evolución de asignación", subtitle: "Distribución relativa por tipo en el tiempo")
            periodSelector
            SnapshotStackedBarsView(points: appViewModel.allocationHistory)
                .frame(height: 260)
            ChartLegendRow(items: appViewModel.allocations.map { ($0.type, AppTheme.color(for: $0.type)) })
        }
    }

    private var typeListCard: some View {
        PremiumPanel(highlight: AppTheme.accentBlue) {
            SectionHeader(title: "Peso actual", subtitle: "Detalle de valor, beneficio y share por categoría.")
            ForEach(appViewModel.allocations) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.type).font(.headline).foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text(item.share.percentString).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.textSecondary)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.surface.opacity(0.65))
                            Capsule().fill(AppTheme.color(for: item.type)).frame(width: proxy.size.width * item.share)
                        }
                    }
                    .frame(height: 11)
                    HStack {
                        Text(item.value.currencyString).foregroundStyle(AppTheme.textPrimary).lineLimit(1)
                        Spacer()
                        Text(item.profit.signedCurrencyString).foregroundStyle(item.profit >= 0 ? AppTheme.positive : AppTheme.negative).lineLimit(1)
                    }
                    .font(.footnote.weight(.semibold))
                }
                .padding(14)
                .background(AppTheme.surface.opacity(0.50), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private var periodSelector: some View {
        Menu {
            ForEach(appViewModel.rangeOptions, id: \.self) { months in
                Button("Últimos \(months) meses") {
                    appViewModel.allocationRangeMonths = months
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Periodo")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textMuted)
                Text(appViewModel.allocationRangeLabel)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppTheme.surface.opacity(0.50), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

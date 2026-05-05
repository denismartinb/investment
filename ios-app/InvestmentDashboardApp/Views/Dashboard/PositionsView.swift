import SwiftUI

struct PositionsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var searchText = ""

    private var filteredPositions: [PortfolioPosition] {
        let positions = appViewModel.summary.positions
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return positions }
        let query = searchText.lowercased()
        return positions.filter {
            $0.name.lowercased().contains(query) ||
            $0.type.lowercased().contains(query) ||
            $0.isin.lowercased().contains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                searchCard
                positionsCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .background(
            LinearGradient(colors: [AppTheme.backgroundSecondary, AppTheme.background], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .navigationTitle("Posiciones")
    }

    private var searchCard: some View {
        PremiumPanel(highlight: AppTheme.accentCyan) {
            SectionHeader(title: "Detalle de posiciones", subtitle: "Explora el snapshot activo, filtra y revisa métricas por activo.")

            TextField("Buscar por nombre, tipo o ISIN", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(14)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 10) {
                GlassTag(text: "\(filteredPositions.count) activos", accent: AppTheme.accentCyan)
                GlassTag(text: appViewModel.selectedDateLabel, accent: AppTheme.accentBlue)
            }
        }
    }

    private var positionsCard: some View {
        PremiumPanel(highlight: AppTheme.accentBlue) {
            ForEach(filteredPositions) { position in
                let share = position.value.percentOf(max(appViewModel.summary.grossAssets, 1))
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(position.name)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(position.type)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer(minLength: 12)
                        GlassTag(text: share.percentString, accent: AppTheme.accentBlue)
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(position.value.currencyString)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Valor actual")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(position.profit.signedCurrencyString)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(position.profit >= 0 ? AppTheme.positive : AppTheme.negative)
                            Text(position.contribution.currencyString)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textMuted)
                        }
                    }

                    HStack(spacing: 16) {
                        stat(label: "Participaciones", value: position.shares == 0 ? "-" : String(format: "%.2f", locale: Locale(identifier: "es_ES"), position.shares))
                        stat(label: "Precio", value: position.unitPrice == 0 ? "-" : position.unitPrice.preciseCurrencyString)
                        stat(label: "TER", value: position.ter == 0 ? "-" : position.ter.percentString)
                    }

                    if !position.isin.isEmpty {
                        Text(position.isin)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.textMuted)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private func stat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

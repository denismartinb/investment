import SwiftUI

struct DashboardHomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryGrid
                    topPositions
                }
                .padding(20)
            }
            .background(Color(red: 0.03, green: 0.08, blue: 0.13).ignoresSafeArea())
            .navigationTitle("Patrimonio")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salir") {
                        Task {
                            await appViewModel.logout()
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Visualizador de activos y patrimonio")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Versión iOS nativa conectada al mismo backend privado.")
                .foregroundStyle(.secondary)

            if let payload = appViewModel.payload {
                Picker("Snapshot", selection: Binding(
                    get: { appViewModel.selectedDate ?? payload.latestDate ?? "" },
                    set: { appViewModel.selectedDate = $0 }
                )) {
                    ForEach(payload.dates, id: \.self) { date in
                        Text(date).tag(date)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
            }
        }
    }

    private var summaryGrid: some View {
        let summary = appViewModel.summary
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            DashboardMetricCard(title: "Activos brutos", value: summary.grossAssets.currencyString, accent: .green)
            DashboardMetricCard(title: "Patrimonio neto", value: summary.netWorth.currencyString, accent: .blue)
            DashboardMetricCard(title: "Capital invertido", value: summary.investedValue.currencyString, accent: .orange)
            DashboardMetricCard(title: "ROI", value: summary.roi.percentString, accent: .purple)
        }
    }

    private var topPositions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top posiciones")
                .font(.title3.bold())
                .foregroundStyle(.white)

            ForEach(appViewModel.summary.topPositions) { position in
                VStack(alignment: .leading, spacing: 6) {
                    Text(position.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(position.type)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(position.value.currencyString)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(position.profit.currencyString)
                            .foregroundStyle(position.profit >= 0 ? .green : .red)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .padding(16)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}

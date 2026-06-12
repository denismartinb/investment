import SwiftUI

struct DashboardTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView {
            NavigationStack {
                DashboardSummaryView()
            }
            .tabItem {
                Label("Resumen", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                AllocationView()
            }
            .tabItem {
                Label("Asignación", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                PerformanceView()
            }
            .tabItem {
                Label("Rentabilidad", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                ContributionPlanView()
            }
            .tabItem {
                Label("Plan", systemImage: "calendar.badge.clock")
            }

            NavigationStack {
                PositionsView()
            }
            .tabItem {
                Label("Posiciones", systemImage: "list.bullet.rectangle.portrait")
            }
        }
        .tint(AppTheme.textPrimary)
        .sheet(isPresented: $appViewModel.isTypeFilterPresented) {
            TypeFilterSheetView().environmentObject(appViewModel)
        }
        .sheet(isPresented: $appViewModel.isProfilePresented) {
            NavigationStack {
                ProfileView().environmentObject(appViewModel)
            }
        }
    }
}

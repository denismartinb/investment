import SwiftUI

@main
struct InvestmentDashboardApp: App {
    @StateObject private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .task {
                    await appViewModel.bootstrap()
                }
        }
    }
}

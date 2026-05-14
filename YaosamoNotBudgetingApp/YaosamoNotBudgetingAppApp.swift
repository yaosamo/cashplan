import SwiftUI

@main
struct YaosamoNotBudgetingAppApp: App {
    @StateObject private var store     = BudgetStore()
    @StateObject private var glassConfig = LiquidGlassConfig()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(glassConfig)
        }
    }
}

import SwiftUI

@main
struct ShieldApp: App {
    @State private var tunnel = TunnelController()
    @State private var lists = BlocklistManager()
    @State private var stats = StatsModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(tunnel)
                .environment(lists)
                .environment(stats)
                .task {
                    lists.onRulesChanged = { [tunnel] in tunnel.send(.reloadRules) }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-demoStats") {
                        StatsStore.save(.demo)
                        SafariStats.add(["youtubeAdsStripped": 42, "youtubeAdsSkipped": 3, "instagramSponsoredHidden": 17])
                    }
                    #endif
                    stats.startPolling()
                    await tunnel.load()
                    await lists.prepare()
                    if lists.needsUpdate { await lists.updateAll() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { stats.startPolling() } else { stats.stopPolling() }
                }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "shield.lefthalf.filled") {
                HomeView()
            }
            Tab("Stats", systemImage: "chart.bar.xaxis") {
                StatsView()
            }
            Tab("Activity", systemImage: "list.bullet.rectangle") {
                ActivityView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3") {
                SettingsView()
            }
        }
    }
}

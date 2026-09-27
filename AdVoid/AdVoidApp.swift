import RevenueCatUI
import SwiftUI

@main
struct AdVoidApp: App {
    @State private var tunnel = TunnelController()
    @State private var lists = BlocklistManager()
    @State private var stats = StatsModel()
    @State private var subscription = SubscriptionModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(tunnel)
                .environment(lists)
                .environment(stats)
                .environment(subscription)
                .task { await subscription.start() }
                .task {
                    lists.onRulesChanged = { [tunnel] in tunnel.send(.reloadRules) }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-demoStats") {
                        StatsStore.save(.demo)
                        SafariStats.add(["youtubeAdsStripped": 42, "youtubeAdsSkipped": 3, "youtubeSlotsHidden": 17])
                    }
                    if ProcessInfo.processInfo.arguments.contains("-demoLive") {
                        Stats.startDemoFeed()
                    }
                    #endif
                    stats.startPolling()
                    await tunnel.load()
                    await stopTunnelIfLapsed()
                    await lists.prepare()
                    if lists.needsUpdate { await lists.updateAll() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        stats.startPolling()
                        // The app can stay alive for days; don't let lists go stale in between.
                        if lists.needsUpdate { Task { await lists.updateAll() } }
                    } else {
                        stats.stopPolling()
                    }
                }
                .onChange(of: subscription.status) {
                    Task { await stopTunnelIfLapsed() }
                }
        }
    }

    /// The tunnel stops filtering on its own when a subscription lapses; this also
    /// turns the VPN off so it isn't left running for nothing.
    private func stopTunnelIfLapsed() async {
        guard subscription.status == .inactive, tunnel.isInstalled else { return }
        await tunnel.stop()
    }
}

struct RootView: View {
    @Environment(SubscriptionModel.self) private var subscription
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var tab = AppTab.home

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView { withAnimation { hasSeenOnboarding = true } }
        } else {
            gated
        }
    }

    @ViewBuilder
    private var gated: some View {
        switch subscription.status {
        case .unknown:
            ProgressView()
        case .inactive:
            PaywallView(displayCloseButton: false)
        case .active:
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "shield.lefthalf.filled", value: .home) {
                HomeView { tab = .settings }
            }
            Tab("Stats", systemImage: "chart.bar.xaxis", value: .stats) {
                StatsView()
            }
            Tab("Activity", systemImage: "list.bullet.rectangle", value: .activity) {
                ActivityView()
            }
            Tab("Settings", systemImage: "slider.horizontal.3", value: .settings) {
                SettingsView()
            }
        }
    }
}

enum AppTab: Hashable {
    case home, stats, activity, settings
}

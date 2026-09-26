import Foundation
import Observation

/// Polls the stats the tunnel and Safari extension write to the app group while the app is visible.
@MainActor
@Observable
final class StatsModel {
    private(set) var stats = StatsStore.load().current
    private(set) var safariCounts = SafariStats.counts
    private(set) var safariLastSeen = SafariStats.lastSeen
    private var timer: Timer?

    var blockedPercent: Int {
        guard stats.queriesToday > 0 else { return 0 }
        return Int((Double(stats.blockedToday) / Double(stats.queriesToday) * 100).rounded())
    }

    var safariTotal: Int { safariCounts.values.reduce(0, +) }

    /// Seen in the last week means the extension is switched on and has run.
    var safariExtensionActive: Bool {
        guard let safariLastSeen else { return false }
        return Date().timeIntervalSince(safariLastSeen) < 7 * 24 * 3600
    }

    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let latest = StatsStore.load().current
        if latest != stats { stats = latest }
        let counts = SafariStats.counts
        if counts != safariCounts { safariCounts = counts }
        safariLastSeen = SafariStats.lastSeen
    }

    func reset(via tunnel: TunnelController) {
        StatsStore.save(Stats())
        SafariStats.reset()
        tunnel.send(.resetStats)
        refresh()
    }
}

#if DEBUG
extension Stats {
    /// Sample data for screenshots and previews. Launch with `-demoStats` to load it.
    static var demo: Stats {
        var stats = Stats()
        let calendar = Calendar.current
        let blocked = ["securepubads.g.doubleclick.net", "app-measurement.com", "graph.facebook.com",
                       "ads.tiktok.com", "googleads.g.doubleclick.net", "api2.branch.io",
                       "sdk.iad-01.braze.com", "api.mixpanel.com", "aax.amazon-adsystem.com", "t.appsflyer.com"]
        let allowed = ["api.apple.com", "i.ytimg.com", "www.instagram.com", "gateway.icloud.com",
                       "rr3---sn-4g5e6nzl.googlevideo.com", "api.spotify.com", "cdn.discordapp.com"]
        var generator = SystemRandomNumberGenerator()
        for dayOffset in stride(from: 13, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let lastHour = dayOffset == 0 ? calendar.component(.hour, from: Date()) : 23
            for hour in 7...max(7, lastHour) {
                let at = calendar.date(bySettingHour: hour, minute: 10, second: 0, of: day)!
                let volume = Int.random(in: 20...90, using: &generator)
                for i in 0..<volume {
                    let isBlocked = i % 4 == 0
                    let pool = isBlocked ? blocked : allowed
                    stats.record(domain: pool[Int.random(in: 0..<pool.count) % (1 + i % pool.count)],
                                 blocked: isBlocked, at: at)
                }
            }
        }
        stats.since = calendar.date(byAdding: .day, value: -13, to: Date())!
        return stats
    }

    /// Simulates a running tunnel by recording a lookup every 0.7 s. Launch with `-demoLive`.
    static func startDemoFeed() {
        let domains = ["api.apple.com", "i.ytimg.com", "app-measurement.com", "graph.facebook.com",
                       "api.spotify.com", "securepubads.g.doubleclick.net", "gateway.icloud.com"]
        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { _ in
            var stats = StatsStore.load()
            let domain = domains.randomElement()!
            stats.record(domain: domain, blocked: domain.contains("measurement") || domain.contains("doubleclick"))
            StatsStore.save(stats)
        }
    }
}
#endif

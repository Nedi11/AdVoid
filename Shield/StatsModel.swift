import Foundation
import Observation

/// Polls the stats the tunnel writes to the app group while the app is visible.
@MainActor
@Observable
final class StatsModel {
    private(set) var stats = StatsStore.load().current
    private var timer: Timer?

    var blockedPercent: Int {
        guard stats.queriesToday > 0 else { return 0 }
        return Int((Double(stats.blockedToday) / Double(stats.queriesToday) * 100).rounded())
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
    }

    func reset(via tunnel: TunnelController) {
        StatsStore.save(Stats())
        tunnel.send(.resetStats)
        refresh()
    }
}

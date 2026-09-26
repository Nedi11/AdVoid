import Foundation

/// Batches stats updates and flushes them to the app group every couple of seconds.
/// All methods run on the tunnel queue.
final class StatsRecorder {
    private static let dedupeWindow: TimeInterval = 2

    private var stats = StatsStore.load()
    private var dirty = false
    private var timer: DispatchSourceTimer?
    /// One page load asks for A, AAAA and HTTPS records of the same name; count it once.
    private var lastSeen: [String: Date] = [:]

    func start(on queue: DispatchQueue) {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.flush() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        flush()
    }

    func record(domain: String, blocked: Bool) {
        let now = Date()
        if let last = lastSeen[domain], now.timeIntervalSince(last) < Self.dedupeWindow { return }
        lastSeen[domain] = now
        if lastSeen.count > 500 {
            lastSeen = lastSeen.filter { now.timeIntervalSince($0.value) < Self.dedupeWindow }
        }
        stats.record(domain: domain, blocked: blocked, at: now)
        dirty = true
    }

    func reset() {
        stats = Stats()
        lastSeen.removeAll()
        dirty = true
        flush()
    }

    private func flush() {
        guard dirty else { return }
        StatsStore.save(stats)
        dirty = false
    }
}

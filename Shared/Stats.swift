import Foundation

struct QueryLogEntry: Codable, Hashable, Identifiable {
    var domain: String
    var date: Date
    var blocked: Bool

    var id: String { "\(date.timeIntervalSince1970)|\(domain)" }
}

struct DaySummary: Codable, Hashable, Identifiable {
    var day: String
    var date: Date
    var queries: Int
    var blocked: Int

    var id: String { day }
}

/// Counters and recent activity. Written by the tunnel, read by the app.
struct Stats: Codable, Equatable {
    static let recentLimit = 300
    static let historyLimit = 30
    /// Per-domain counters are pruned back to `domainKeep` when they pass `domainLimit`.
    static let domainLimit = 1500
    static let domainKeep = 1000

    var day: String = Stats.dayKey(for: Date())
    var queriesToday = 0
    var blockedToday = 0
    var queriesAllTime = 0
    var blockedAllTime = 0
    var hourlyQueries = Array(repeating: 0, count: 24)
    var hourlyBlocked = Array(repeating: 0, count: 24)
    /// Previous days, oldest first. Today lives in the fields above.
    var history: [DaySummary] = []
    var blockedCounts: [String: Int] = [:]
    var allowedCounts: [String: Int] = [:]
    var since = Date()
    var recent: [QueryLogEntry] = []

    mutating func record(domain: String, blocked: Bool, at date: Date = Date()) {
        rollOver(to: date)
        let hour = Calendar.current.component(.hour, from: date)
        queriesToday += 1
        queriesAllTime += 1
        hourlyQueries[hour] += 1
        if blocked {
            blockedToday += 1
            blockedAllTime += 1
            hourlyBlocked[hour] += 1
            Stats.bump(&blockedCounts, domain)
        } else {
            Stats.bump(&allowedCounts, domain)
        }
        recent.insert(QueryLogEntry(domain: domain, date: date, blocked: blocked), at: 0)
        if recent.count > Stats.recentLimit { recent.removeLast(recent.count - Stats.recentLimit) }
    }

    /// Moves today's totals into history when the day changes.
    mutating func rollOver(to date: Date) {
        let today = Stats.dayKey(for: date)
        guard today != day else { return }
        if queriesToday > 0 {
            history.append(DaySummary(day: day, date: Stats.date(fromKey: day) ?? date,
                                      queries: queriesToday, blocked: blockedToday))
            if history.count > Stats.historyLimit { history.removeFirst(history.count - Stats.historyLimit) }
        }
        day = today
        queriesToday = 0
        blockedToday = 0
        hourlyQueries = Array(repeating: 0, count: 24)
        hourlyBlocked = Array(repeating: 0, count: 24)
    }

    /// A copy rolled over to the current day, for display.
    var current: Stats {
        var copy = self
        copy.rollOver(to: Date())
        return copy
    }

    /// History plus today, oldest first.
    var days: [DaySummary] {
        history + [DaySummary(day: day, date: Stats.date(fromKey: day) ?? Date(),
                              queries: queriesToday, blocked: blockedToday)]
    }

    func topBlocked(_ limit: Int) -> [(domain: String, count: Int)] {
        Stats.top(blockedCounts, limit)
    }

    func topAllowed(_ limit: Int) -> [(domain: String, count: Int)] {
        Stats.top(allowedCounts, limit)
    }

    private static func bump(_ counts: inout [String: Int], _ domain: String) {
        counts[domain, default: 0] += 1
        if counts.count > domainLimit {
            counts = Dictionary(uniqueKeysWithValues: top(counts, domainKeep).map { ($0.domain, $0.count) })
        }
    }

    private static func top(_ counts: [String: Int], _ limit: Int) -> [(domain: String, count: Int)] {
        counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map { (domain: $0.key, count: $0.value) }
    }

    static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

enum StatsStore {
    private static let key = "stats.v2"

    static func load() -> Stats {
        guard let data = AppGroup.defaults.data(forKey: key),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else { return Stats() }
        return stats
    }

    static func save(_ stats: Stats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        AppGroup.defaults.set(data, forKey: key)
    }
}

/// Counts reported by the Safari extension, which runs in its own process.
enum SafariStats {
    private enum Key {
        static let counts = "safari.counts"
        static let lastSeen = "safari.lastSeen"
    }

    static var counts: [String: Int] {
        AppGroup.defaults.dictionary(forKey: Key.counts) as? [String: Int] ?? [:]
    }

    static var total: Int { counts.values.reduce(0, +) }

    static var lastSeen: Date? { AppGroup.defaults.object(forKey: Key.lastSeen) as? Date }

    static func add(_ increments: [String: Int]) {
        var counts = self.counts
        for (kind, n) in increments where n > 0 { counts[kind, default: 0] += n }
        AppGroup.defaults.set(counts, forKey: Key.counts)
        markSeen()
    }

    static func markSeen() {
        AppGroup.defaults.set(Date(), forKey: Key.lastSeen)
    }

    static func reset() {
        AppGroup.defaults.removeObject(forKey: Key.counts)
    }
}

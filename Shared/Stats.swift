import Foundation

struct QueryLogEntry: Codable, Hashable, Identifiable {
    var domain: String
    var date: Date
    var blocked: Bool

    var id: String { "\(date.timeIntervalSince1970)|\(domain)" }
}

/// Counters and recent activity. Written by the tunnel, read by the app.
struct Stats: Codable, Equatable {
    static let recentLimit = 300

    var day: String = Stats.dayKey(for: Date())
    var queriesToday = 0
    var blockedToday = 0
    var blockedAllTime = 0
    var recent: [QueryLogEntry] = []

    mutating func record(domain: String, blocked: Bool, at date: Date = Date()) {
        let today = Stats.dayKey(for: date)
        if today != day {
            day = today
            queriesToday = 0
            blockedToday = 0
        }
        queriesToday += 1
        if blocked {
            blockedToday += 1
            blockedAllTime += 1
        }
        recent.insert(QueryLogEntry(domain: domain, date: date, blocked: blocked), at: 0)
        if recent.count > Stats.recentLimit { recent.removeLast(recent.count - Stats.recentLimit) }
    }

    /// Today's figures, zeroed if the last write was on an earlier day.
    var current: Stats {
        var copy = self
        if copy.day != Stats.dayKey(for: Date()) {
            copy.queriesToday = 0
            copy.blockedToday = 0
        }
        return copy
    }

    static func dayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

enum StatsStore {
    private static let key = "stats"

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

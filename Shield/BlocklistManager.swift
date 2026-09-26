import Foundation
import Observation

struct BlocklistSource: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let url: URL
    let enabledByDefault: Bool

    static let all: [BlocklistSource] = [
        BlocklistSource(
            id: "hagezi-pro", name: "HaGeZi Pro",
            detail: "Ads, trackers, telemetry and malware. Well balanced, rarely breaks sites.",
            url: URL(string: "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/pro-onlydomains.txt")!,
            enabledByDefault: true),
        BlocklistSource(
            id: "oisd-small", name: "OISD Small",
            detail: "Conservative ads and tracking list focused on zero breakage.",
            url: URL(string: "https://small.oisd.nl/domainswild")!,
            enabledByDefault: false),
        BlocklistSource(
            id: "adguard-dns", name: "AdGuard DNS filter",
            detail: "AdGuard's list for DNS-level ad and tracker blocking.",
            url: URL(string: "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt")!,
            enabledByDefault: false),
        BlocklistSource(
            id: "stevenblack", name: "StevenBlack Unified",
            detail: "Classic hosts file combining several ad and malware lists.",
            url: URL(string: "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts")!,
            enabledByDefault: false),
        BlocklistSource(
            id: "hagezi-tif-mini", name: "HaGeZi Threat Intelligence",
            detail: "Phishing, scam and malware domains seen recently.",
            url: URL(string: "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/wildcard/tif.mini-onlydomains.txt")!,
            enabledByDefault: false),
    ]
}

/// Downloads blocklists, compiles them into hash files the tunnel reads,
/// and manages the user's own allow and block rules.
@MainActor
@Observable
final class BlocklistManager {
    private enum Key {
        static let enabled = "enabledSources"
        static let counts = "sourceCounts"
        static let lastUpdated = "listsLastUpdated"
        static let customBlocked = "customBlocked"
        static let allowlist = "allowlist"
        static let totalDomains = "totalDomains"
    }

    private static let staleAfter: TimeInterval = 3 * 24 * 3600

    private(set) var enabledIDs: Set<String>
    private(set) var counts: [String: Int]
    private(set) var lastUpdated: Date?
    private(set) var totalDomains: Int
    private(set) var customBlocked: [String]
    private(set) var allowlist: [String]
    private(set) var isUpdating = false
    var lastError: String?

    /// Called after compiled rules change so the running tunnel can reload them.
    var onRulesChanged: (() -> Void)?

    private let defaults = AppGroup.defaults

    init() {
        let stored = defaults.stringArray(forKey: Key.enabled)
        enabledIDs = Set(stored ?? BlocklistSource.all.filter(\.enabledByDefault).map(\.id))
        counts = defaults.dictionary(forKey: Key.counts) as? [String: Int] ?? [:]
        lastUpdated = defaults.object(forKey: Key.lastUpdated) as? Date
        totalDomains = defaults.integer(forKey: Key.totalDomains)
        customBlocked = defaults.stringArray(forKey: Key.customBlocked) ?? []
        allowlist = defaults.stringArray(forKey: Key.allowlist) ?? []
    }

    var needsUpdate: Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > Self.staleAfter
    }

    /// Make sure there's something to block before the first download finishes.
    func prepare() async {
        if !FileManager.default.fileExists(atPath: AppGroup.blocklistURL.path) {
            await rebuild()
        }
    }

    func updateAll() async {
        guard !isUpdating else { return }
        isUpdating = true
        lastError = nil
        defer { isUpdating = false }

        var failures: [String] = []
        for source in BlocklistSource.all where enabledIDs.contains(source.id) {
            do {
                try await download(source)
            } catch {
                failures.append(source.name)
            }
        }
        if failures.count < enabledIDs.count {
            lastUpdated = Date()
            defaults.set(lastUpdated, forKey: Key.lastUpdated)
        }
        if !failures.isEmpty {
            lastError = "Couldn't update \(failures.joined(separator: ", ")). Using the previous copy."
        }
        await rebuild()
    }

    func setEnabled(_ source: BlocklistSource, _ enabled: Bool) async {
        if enabled { enabledIDs.insert(source.id) } else { enabledIDs.remove(source.id) }
        defaults.set(Array(enabledIDs), forKey: Key.enabled)

        if enabled, !FileManager.default.fileExists(atPath: Self.fileURL(for: source).path) {
            isUpdating = true
            do {
                try await download(source)
            } catch {
                lastError = "Couldn't download \(source.name): \(error.localizedDescription)"
            }
            isUpdating = false
        }
        await rebuild()
    }

    // MARK: - Your rules

    func allow(_ domain: String) async {
        guard let domain = BlocklistParser.validated(domain), !allowlist.contains(domain) else { return }
        allowlist.insert(domain, at: 0)
        customBlocked.removeAll { $0 == domain }
        await saveRules()
    }

    func block(_ domain: String) async {
        guard let domain = BlocklistParser.validated(domain), !customBlocked.contains(domain) else { return }
        customBlocked.insert(domain, at: 0)
        allowlist.removeAll { $0 == domain }
        await saveRules()
    }

    func removeFromAllowlist(_ domains: [String]) async {
        allowlist.removeAll { domains.contains($0) }
        await saveRules()
    }

    func removeFromCustomBlocked(_ domains: [String]) async {
        customBlocked.removeAll { domains.contains($0) }
        await saveRules()
    }

    private func saveRules() async {
        defaults.set(allowlist, forKey: Key.allowlist)
        defaults.set(customBlocked, forKey: Key.customBlocked)
        await rebuild()
    }

    // MARK: - Compiling

    private func download(_ source: BlocklistSource) async throws {
        var request = URLRequest(url: source.url)
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let url = Self.fileURL(for: source)
        let count = try await Task.detached(priority: .userInitiated) {
            let text = String(decoding: data, as: UTF8.self)
            let hashes = BlocklistParser.domains(in: text).map(DomainHash.hash)
            guard !hashes.isEmpty else { throw URLError(.cannotParseResponse) }
            try FileManager.default.createDirectory(at: AppGroup.sourcesDirectory, withIntermediateDirectories: true)
            try DomainMatcher.write(hashes, to: url)
            return Set(hashes).count
        }.value
        counts[source.id] = count
        defaults.set(counts, forKey: Key.counts)
    }

    /// Merges enabled sources, the bundled starter list and custom rules into
    /// the files the tunnel reads, then asks the tunnel to reload.
    func rebuild() async {
        let sourceURLs = BlocklistSource.all.filter { enabledIDs.contains($0.id) }.map(Self.fileURL)
        let custom = customBlocked
        let allowed = allowlist
        let seedURL = Bundle.main.url(forResource: "starter-blocklist", withExtension: "txt")

        let total = await Task.detached(priority: .userInitiated) { () -> Int in
            var hashes = Set<UInt64>()
            for url in sourceURLs {
                hashes.formUnion(DomainMatcher.readHashes(from: url))
            }
            if let seedURL, let text = try? String(contentsOf: seedURL, encoding: .utf8) {
                hashes.formUnion(BlocklistParser.domains(in: text).map(DomainHash.hash))
            }
            hashes.formUnion(custom.map(DomainHash.hash))
            try? DomainMatcher.write(hashes, to: AppGroup.blocklistURL)
            try? DomainMatcher.write(allowed.map(DomainHash.hash), to: AppGroup.allowlistURL)
            return hashes.count
        }.value

        totalDomains = total
        defaults.set(total, forKey: Key.totalDomains)
        onRulesChanged?()
    }

    private static func fileURL(for source: BlocklistSource) -> URL {
        AppGroup.sourcesDirectory.appendingPathComponent("\(source.id).bin")
    }
}

import CryptoKit
import Foundation
import Observation

struct BlocklistSource: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let detail: String
    let url: URL
    var enabledByDefault = false
    var isCustom = false
    /// Set for published lists, which arrive already compiled.
    var sha256: String?
    var domainCount: Int?

    var isCompiled: Bool { sha256 != nil }

    init(id: String, name: String, detail: String, url: URL, enabledByDefault: Bool = false, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.detail = detail
        self.url = url
        self.enabledByDefault = enabledByDefault
        self.isCustom = isCustom
    }

    init(_ entry: ListCatalog.Entry) {
        self.init(id: entry.id, name: entry.name, detail: entry.description, url: entry.file,
                  enabledByDefault: entry.enabledByDefault)
        sha256 = entry.sha256
        domainCount = entry.domainCount
    }
}

/// Downloads blocklists, compiles them into hash files the tunnel reads,
/// and manages the user's own allow and block rules.
@MainActor
@Observable
final class BlocklistManager {
    private enum Key {
        static let custom = "customSources"
        static let enabled = "enabledSources"
        static let counts = "sourceCounts"
        static let lastUpdated = "listsLastUpdated"
        static let customBlocked = "customBlocked"
        static let allowlist = "allowlist"
        static let totalDomains = "totalDomains"
        static let installedSHA = "installedListSHA"
        static let essentialsEnabled = "essentialsEnabled"
    }

    /// The catalog is tiny and files only download when they change, so check often.
    private static let staleAfter: TimeInterval = 12 * 3600
    private static let maxDownloadSize = 50 * 1024 * 1024

    private(set) var catalog: ListCatalog
    private(set) var customSources: [BlocklistSource]
    private(set) var enabledIDs: Set<String>
    private(set) var counts: [String: Int]
    private(set) var lastUpdated: Date?
    private(set) var totalDomains: Int
    private(set) var customBlocked: [String]
    private(set) var allowlist: [String]
    /// The small list bundled with the app, on until the user turns it off.
    private(set) var essentialsEnabled: Bool
    private(set) var isUpdating = false
    var lastError: String?

    /// Called after compiled rules change so the running tunnel can reload them.
    var onRulesChanged: (() -> Void)?

    /// Where settings and compiled lists live. Tests pass a scratch location.
    struct Storage {
        var defaults: UserDefaults
        var container: URL
        /// False when the App Group is missing, so the tunnel couldn't see what's written.
        var isAvailable = true

        static var shared: Storage {
            Storage(defaults: AppGroup.defaults, container: AppGroup.containerURL, isAvailable: AppGroup.isAvailable)
        }

        var sourcesDirectory: URL { container.appendingPathComponent("sources", isDirectory: true) }
        var blocklistURL: URL { container.appendingPathComponent("blocklist.bin") }
        var allowlistURL: URL { container.appendingPathComponent("allowlist.bin") }
        var catalogCacheURL: URL { container.appendingPathComponent("catalog.json") }

        func fileURL(forID id: String) -> URL { sourcesDirectory.appendingPathComponent("\(id).bin") }
        func fileURL(for source: BlocklistSource) -> URL { fileURL(forID: source.id) }
    }

    private let storage: Storage
    private var defaults: UserDefaults { storage.defaults }
    private var installedSHA: [String: String]

    init(storage: Storage = .shared) {
        self.storage = storage
        let defaults = storage.defaults
        let catalog = (try? Data(contentsOf: storage.catalogCacheURL)).flatMap { try? ListCatalog.decode($0) } ?? .bundled
        self.catalog = catalog
        installedSHA = defaults.dictionary(forKey: Key.installedSHA) as? [String: String] ?? [:]
        customSources = defaults.data(forKey: Key.custom)
            .flatMap { try? JSONDecoder().decode([BlocklistSource].self, from: $0) } ?? []
        let stored = defaults.stringArray(forKey: Key.enabled)
        enabledIDs = Set(stored ?? catalog.lists.filter(\.enabledByDefault).map(\.id))
        counts = defaults.dictionary(forKey: Key.counts) as? [String: Int] ?? [:]
        lastUpdated = defaults.object(forKey: Key.lastUpdated) as? Date
        totalDomains = defaults.integer(forKey: Key.totalDomains)
        customBlocked = defaults.stringArray(forKey: Key.customBlocked) ?? []
        allowlist = defaults.stringArray(forKey: Key.allowlist) ?? []
        essentialsEnabled = defaults.object(forKey: Key.essentialsEnabled) as? Bool ?? true
    }

    var builtInSources: [BlocklistSource] { catalog.lists.map(BlocklistSource.init) }

    var sources: [BlocklistSource] { builtInSources + customSources }

    /// True when no downloaded list or custom domain is selected, leaving at most Essentials.
    var hasNothingSelected: Bool {
        !sources.contains { enabledIDs.contains($0.id) } && customBlocked.isEmpty
    }

    static let essentialsURL = Bundle.main.url(forResource: "starter-blocklist", withExtension: "txt")

    static let essentialsDomainCount: Int = {
        guard let essentialsURL, let text = try? String(contentsOf: essentialsURL, encoding: .utf8) else { return 0 }
        return Set(BlocklistParser.domains(in: text)).count
    }()

    func setEssentialsEnabled(_ enabled: Bool) async {
        essentialsEnabled = enabled
        defaults.set(enabled, forKey: Key.essentialsEnabled)
        await rebuild()
    }

    func domainCount(for source: BlocklistSource) -> Int? {
        counts[source.id] ?? source.domainCount
    }

    var needsUpdate: Bool {
        guard let lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > Self.staleAfter
    }

    /// Make sure there's something to block before the first download finishes.
    func prepare() async {
        if !FileManager.default.fileExists(atPath: storage.blocklistURL.path) {
            await rebuild()
        }
    }

    func updateAll() async {
        guard !isUpdating else { return }
        isUpdating = true
        lastError = nil
        defer { isUpdating = false }

        await refreshCatalog()

        var failures: [String] = []
        for source in sources where enabledIDs.contains(source.id) {
            if let sha = source.sha256, installedSHA[source.id] == sha,
               FileManager.default.fileExists(atPath: storage.fileURL(for: source).path) {
                continue
            }
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

        if enabled, !FileManager.default.fileExists(atPath: storage.fileURL(for: source).path) {
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

    // MARK: - Custom lists

    /// Downloads the list to check it has domains, then subscribes to it.
    func addCustom(address: String, name: String) async throws {
        var address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.contains("://") { address = "https://" + address }
        guard let url = URL(string: address), url.scheme?.lowercased() == "https", let host = url.host() else {
            throw AddListError.invalidAddress
        }
        guard !sources.contains(where: { $0.url == url }) else { throw AddListError.duplicate }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let fileName = url.deletingPathExtension().lastPathComponent
        let defaultName = fileName.isEmpty || fileName == "/" ? host : fileName
        let source = BlocklistSource(id: "custom-\(UUID().uuidString)",
                                     name: trimmedName.isEmpty ? defaultName : trimmedName,
                                     detail: host + url.path(), url: url, isCustom: true)
        isUpdating = true
        defer { isUpdating = false }
        do {
            try await download(source)
        } catch URLError.cannotParseResponse {
            throw AddListError.noDomains
        }

        customSources.append(source)
        enabledIDs.insert(source.id)
        saveCustomSources()
        await rebuild()
    }

    func removeCustom(_ source: BlocklistSource) async {
        customSources.removeAll { $0.id == source.id }
        enabledIDs.remove(source.id)
        counts[source.id] = nil
        defaults.set(counts, forKey: Key.counts)
        try? FileManager.default.removeItem(at: storage.fileURL(for: source))
        saveCustomSources()
        await rebuild()
    }

    private func saveCustomSources() {
        defaults.set(try? JSONEncoder().encode(customSources), forKey: Key.custom)
        defaults.set(Array(enabledIDs), forKey: Key.enabled)
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

    /// Fetches the latest catalog. On failure the cached one stays in use.
    private func refreshCatalog() async {
        guard let data = try? await fetch(ListCatalog.remoteURL),
              let latest = try? ListCatalog.decode(data) else { return }
        catalog = latest
        try? data.write(to: storage.catalogCacheURL, options: .atomic)
        forgetRetiredLists()
    }

    /// Drops lists the catalog no longer offers, so their downloads don't linger.
    private func forgetRetiredLists() {
        let retired = enabledIDs.subtracting(sources.map(\.id))
        guard !retired.isEmpty else { return }
        for id in retired {
            enabledIDs.remove(id)
            counts[id] = nil
            try? FileManager.default.removeItem(at: storage.fileURL(forID: id))
        }
        defaults.set(counts, forKey: Key.counts)
        defaults.set(Array(enabledIDs), forKey: Key.enabled)
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ListDownloadError.httpStatus(http.statusCode)
        }
        guard data.count <= Self.maxDownloadSize else { throw ListDownloadError.tooLarge }
        return data
    }

    private func download(_ source: BlocklistSource) async throws {
        let data = try await fetch(source.url)
        let url = storage.fileURL(for: source)

        if let expected = source.sha256 {
            // Published lists are already in the tunnel's format; just verify and store.
            guard data.count % MemoryLayout<UInt64>.size == 0, data.sha256Hex == expected else {
                throw ListDownloadError.checksumMismatch
            }
            try FileManager.default.createDirectory(at: storage.sourcesDirectory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            counts[source.id] = data.count / MemoryLayout<UInt64>.size
            defaults.set(counts, forKey: Key.counts)
            installedSHA[source.id] = expected
            defaults.set(installedSHA, forKey: Key.installedSHA)
            return
        }

        let directory = storage.sourcesDirectory
        let count = try await Task.detached(priority: .userInitiated) {
            let text = String(decoding: data, as: UTF8.self)
            let hashes = BlocklistParser.domains(in: text).map(DomainHash.hash)
            guard !hashes.isEmpty else { throw URLError(.cannotParseResponse) }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try DomainMatcher.write(hashes, to: url)
            return Set(hashes).count
        }.value
        counts[source.id] = count
        defaults.set(counts, forKey: Key.counts)
    }

    /// Merges enabled sources, the bundled Essentials list and custom rules into
    /// the files the tunnel reads, then asks the tunnel to reload.
    ///
    /// Builds run one after another, and each reads the settings as they are when it
    /// starts, so an older build can never overwrite a newer choice. Calls that arrive
    /// while a build is running collapse into one follow-up build.
    func rebuild() async {
        rebuildGeneration += 1
        let generation = rebuildGeneration
        let previous = rebuildTask
        let task = Task {
            await previous?.value
            // A newer call is queued behind this one and will read even newer settings.
            guard generation == rebuildGeneration else { return }
            await install()
        }
        rebuildTask = task
        await task.value
    }

    private var rebuildGeneration = 0
    private var rebuildTask: Task<Void, Never>?

    private func install() async {
        let storage = storage
        let sourceURLs = sources.filter { enabledIDs.contains($0.id) }.map(storage.fileURL(for:))
        let custom = customBlocked
        let allowed = allowlist
        let seedURL = essentialsEnabled ? Self.essentialsURL : nil

        do {
            let total = try await Task.detached(priority: .userInitiated) { () throws -> Int in
                guard storage.isAvailable else { throw RulesInstallError.sharedStorageUnavailable }
                var hashes = Set<UInt64>()
                for url in sourceURLs {
                    hashes.formUnion(DomainMatcher.readHashes(from: url))
                }
                if let seedURL, let text = try? String(contentsOf: seedURL, encoding: .utf8) {
                    hashes.formUnion(BlocklistParser.domains(in: text).map(DomainHash.hash))
                }
                hashes.formUnion(custom.map(DomainHash.hash))
                try DomainMatcher.install(blocked: hashes, allowed: allowed.map(DomainHash.hash),
                                          blocklistURL: storage.blocklistURL, allowlistURL: storage.allowlistURL)
                return hashes.count
            }.value

            totalDomains = total
            defaults.set(total, forKey: Key.totalDomains)
            if RulesInstallError.allCases.contains(where: { $0.localizedDescription == lastError }) {
                lastError = nil
            }
            onRulesChanged?()
        } catch {
            // The tunnel keeps the last rules that were saved in full.
            lastError = (error as? RulesInstallError ?? .writeFailed).localizedDescription
        }
    }

}

enum AddListError: LocalizedError {
    case invalidAddress
    case duplicate
    case noDomains

    var errorDescription: String? {
        switch self {
        case .invalidAddress: "Enter an https:// link to a blocklist."
        case .duplicate: "You already have this list."
        case .noDomains: "No domains found at that link. AdVoid reads hosts files, plain domain lists, *.domain wildcards and ||domain^ rules."
        }
    }
}

enum RulesInstallError: LocalizedError, CaseIterable {
    case sharedStorageUnavailable
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .sharedStorageUnavailable: "AdVoid can't reach its shared storage, so blocking rules can't be updated. Reinstalling AdVoid should fix this."
        case .writeFailed: "Couldn't save your blocking rules, so the previous ones are still in use. Try again, or free up some storage."
        }
    }
}

enum ListDownloadError: LocalizedError {
    case httpStatus(Int)
    case tooLarge
    case checksumMismatch

    var errorDescription: String? {
        switch self {
        case .httpStatus(404): "Nothing was found at that link (error 404). Check the address."
        case .httpStatus(let code): "The server couldn't provide the list (error \(code))."
        case .tooLarge: "That list is larger than 50 MB, which is too big to use."
        case .checksumMismatch: "The downloaded list was damaged, so the previous copy was kept."
        }
    }
}

extension Data {
    var sha256Hex: String {
        SHA256.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

import Testing
import Foundation
@testable import AdVoid

/// Rule installation against scratch storage, so the simulator's real App Group is untouched.
@MainActor
@Suite struct RuleInstallTests {
    let storage: BlocklistManager.Storage
    let source = BlocklistSource(id: "big", name: "Big", detail: "", url: URL(string: "https://example.com/big")!,
                                 isCustom: true)

    init() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("rules-\(UUID())")
        storage = BlocklistManager.Storage(defaults: UserDefaults(suiteName: "rules-\(UUID())")!, container: root)
        try FileManager.default.createDirectory(at: storage.sourcesDirectory, withIntermediateDirectories: true)
        storage.defaults.set(try JSONEncoder().encode([source]), forKey: "customSources")
        storage.defaults.set([source.id], forKey: "enabledSources")
        // Large enough that a build is still running when the next change arrives.
        try DomainMatcher.write((0..<500_000).map { DomainHash.hash("host\($0).example.org") },
                                to: storage.fileURL(for: source))
    }

    private var installed: (blocked: DomainMatcher, allowed: DomainMatcher) {
        (DomainMatcher(contentsOf: storage.blocklistURL), DomainMatcher(contentsOf: storage.allowlistURL))
    }

    @Test func olderBuildNeverOverwritesNewerChoice() async throws {
        let manager = BlocklistManager(storage: storage)
        let older = Task { await manager.rebuild() }
        try await Task.sleep(for: .milliseconds(10))
        await manager.setEnabled(source, false)
        await older.value

        #expect(manager.enabledIDs.isEmpty)
        #expect(!installed.blocked.matches("host1.example.org"))
        #expect(manager.totalDomains == installed.blocked.count)
    }

    @Test func rapidRuleChangesEndWithTheLastOne() async {
        let manager = BlocklistManager(storage: storage)
        async let build: Void = manager.rebuild()
        async let allow: Void = manager.allow("flip.example.com")
        async let block: Void = manager.block("flip.example.com")
        _ = await (build, allow, block)
        await manager.rebuild()

        let lastBlocked = manager.customBlocked.contains("flip.example.com")
        #expect(installed.blocked.matches("flip.example.com") == lastBlocked)
        #expect(installed.allowed.matches("flip.example.com") == !lastBlocked)
    }

    @Test func failedWriteKeepsPreviousRulesAndReportsIt() async throws {
        let manager = BlocklistManager(storage: storage)
        await manager.rebuild()
        let before = manager.totalDomains
        var reloads = 0
        manager.onRulesChanged = { reloads += 1 }

        // A directory where the staged file goes makes the write fail.
        let blocker = storage.blocklistURL.appendingPathExtension("new")
        try FileManager.default.createDirectory(at: blocker, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: blocker.appendingPathComponent("x"), withIntermediateDirectories: true)
        await manager.setEnabled(source, false)

        #expect(manager.lastError == RulesInstallError.writeFailed.localizedDescription)
        #expect(manager.totalDomains == before)
        #expect(installed.blocked.matches("host1.example.org"))
        #expect(reloads == 0)

        try? FileManager.default.removeItem(at: blocker)
        await manager.rebuild()
        #expect(manager.lastError == nil)
        #expect(!installed.blocked.matches("host1.example.org"))
        #expect(reloads == 1)
    }

    @Test func missingSharedStorageIsReported() async {
        var storage = storage
        storage.isAvailable = false
        let manager = BlocklistManager(storage: storage)
        await manager.rebuild()

        #expect(manager.lastError == RulesInstallError.sharedStorageUnavailable.localizedDescription)
        #expect(!FileManager.default.fileExists(atPath: storage.blocklistURL.path))
    }
}

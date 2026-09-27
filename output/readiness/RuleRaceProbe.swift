import Foundation

enum AppGroup {
    static let root = FileManager.default.temporaryDirectory.appendingPathComponent("advoid-rule-audit-\(UUID().uuidString)")
    static let defaults = UserDefaults(suiteName: "advoid-readiness-\(UUID().uuidString)")!
    static var containerURL: URL { root }
    static var sourcesDirectory: URL { root.appendingPathComponent("sources") }
    static var blocklistURL: URL { root.appendingPathComponent("blocklist.bin") }
    static var allowlistURL: URL { root.appendingPathComponent("allowlist.bin") }
}

@main struct RuleRaceProbe {
    @MainActor static func main() async throws {
        try FileManager.default.createDirectory(at: AppGroup.sourcesDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: AppGroup.root) }
        let source = BlocklistSource(id: "audit", name: "Audit", detail: "", url: URL(string:"https://example.com/audit")!, isCustom:true)
        AppGroup.defaults.set(try JSONEncoder().encode([source]), forKey:"customSources")
        AppGroup.defaults.set(["audit"], forKey:"enabledSources")
        try DomainMatcher.write((0..<500_000).map { DomainHash.hash("host\($0).example.org") }, to: AppGroup.sourcesDirectory.appendingPathComponent("audit.bin"))
        let manager = BlocklistManager()
        let oldBuild = Task { await manager.rebuild() }
        try await Task.sleep(for:.milliseconds(10))
        await manager.setEnabled(source, false)
        print("After disabling: enabled=\(manager.enabledIDs), diskCount=\(DomainMatcher(contentsOf:AppGroup.blocklistURL).count)")
        await oldBuild.value
        let finalCount = DomainMatcher(contentsOf:AppGroup.blocklistURL).count
        print("After older rebuild finishes: enabled=\(manager.enabledIDs), diskCount=\(finalCount), displayed=\(manager.totalDomains)")
        print(finalCount > 0 ? "CONFIRMED: stale rebuild restores disabled source." : "Race did not reproduce in this run.")
    }
}

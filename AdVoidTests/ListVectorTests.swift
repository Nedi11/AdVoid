import Foundation
import Testing
@testable import AdVoid

/// Checks the app against lists/vectors.json, which the server-side list
/// builder (lists/lib.mjs) is tested against too. If these fail, the app and
/// the published lists disagree about which domains are blocked.
@Suite struct ListVectorTests {
    private struct Vectors: Decodable {
        struct Parse: Decodable { let line: String; let domains: [String] }
        struct Hash: Decodable { let domain: String; let fnv1a64: String }
        let parse: [Parse]
        let hash: [Hash]
    }

    private let vectors: Vectors = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("lists/vectors.json")
        return try! JSONDecoder().decode(Vectors.self, from: Data(contentsOf: url))
    }()

    @Test func parsesLikeTheListBuilder() {
        for vector in vectors.parse {
            #expect(BlocklistParser.domains(inLine: vector.line) == vector.domains, "\(vector.line)")
        }
    }

    @Test func hashesLikeTheListBuilder() {
        for vector in vectors.hash {
            let hex = String(DomainHash.hash(vector.domain), radix: 16)
            #expect(String(repeating: "0", count: 16 - hex.count) + hex == vector.fnv1a64, "\(vector.domain)")
        }
    }
}

@Suite struct ListCatalogTests {
    @Test func bundledCatalogDecodes() throws {
        let catalog = ListCatalog.bundled
        #expect(catalog.schemaVersion == ListCatalog.supportedSchema)
        #expect(catalog.lists.contains { $0.id == "hagezi-pro" && $0.enabledByDefault })
        for entry in catalog.lists {
            #expect(entry.file.host() == "lists.roxuh.com")
            #expect(entry.sha256.count == 64)
            #expect(entry.bytes == entry.domainCount * 8)
            #expect(!entry.license.name.isEmpty)
        }
    }

    @Test func rejectsUnknownSchema() {
        let json = #"{"schemaVersion":2,"generatedAt":"2026-01-01T00:00:00Z","publisher":"x","notice":"","lists":[]}"#
        #expect(throws: (any Error).self) { try ListCatalog.decode(Data(json.utf8)) }
    }

    @Test func hashesDataLikeTheListBuilder() {
        #expect(Data("abc".utf8).sha256Hex == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
}

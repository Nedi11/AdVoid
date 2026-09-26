import Foundation

/// The published description of AdVoid's built-in blocklists: where each compiled
/// file lives, its checksum, and who made it under which license.
/// Generated daily by lists/build.mjs and served from lists.roxuh.com.
struct ListCatalog: Codable, Equatable {
    struct Entry: Codable, Hashable, Identifiable {
        struct Source: Codable, Hashable {
            let url: URL
            let author: String
            let homepage: URL
        }

        struct License: Codable, Hashable {
            let spdx: String
            let name: String
            let url: URL
        }

        let id: String
        let name: String
        let description: String
        let enabledByDefault: Bool
        let file: URL
        let sha256: String
        let bytes: Int
        let domainCount: Int
        let updatedAt: Date
        let source: Source
        let license: License
    }

    static let remoteURL = URL(string: "https://lists.roxuh.com/v1/catalog.json")!
    static let supportedSchema = 1

    let schemaVersion: Int
    let generatedAt: Date
    let publisher: String
    let notice: String
    let lists: [Entry]

    static func decode(_ data: Data) throws -> ListCatalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(string, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) {
                return date
            }
            return try Date(string, strategy: .iso8601)
        }
        let catalog = try decoder.decode(ListCatalog.self, from: data)
        guard catalog.schemaVersion == supportedSchema else { throw URLError(.cannotDecodeContentData) }
        return catalog
    }

    /// The copy shipped inside the app, used until the first successful fetch.
    static var bundled: ListCatalog {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? decode(data) else {
            return ListCatalog(schemaVersion: supportedSchema, generatedAt: .distantPast,
                               publisher: "Roxuh", notice: "", lists: [])
        }
        return catalog
    }
}

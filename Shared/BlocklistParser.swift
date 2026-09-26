import Foundation

/// Extracts domains from the common blocklist formats:
/// hosts files (`0.0.0.0 ads.example.com`), plain domain lists, wildcard lists
/// (`*.ads.example.com`) and adblock-style DNS rules (`||ads.example.com^`).
enum BlocklistParser {
    private static let hostsIgnored: Set<String> = [
        "localhost", "localhost.localdomain", "local", "broadcasthost",
        "ip6-localhost", "ip6-loopback", "ip6-localnet", "ip6-mcastprefix",
        "ip6-allnodes", "ip6-allrouters", "ip6-allhosts", "0.0.0.0",
    ]

    static func domains(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateLines { line, _ in
            result.append(contentsOf: domains(inLine: line))
        }
        return result
    }

    static func domains(inLine rawLine: String) -> [String] {
        var line = Substring(rawLine)
        if let hash = line.firstIndex(of: "#") { line = line[..<hash] }
        line = line.trimmingCharacters(in: .whitespaces)[...]
        guard !line.isEmpty, !line.hasPrefix("!"), !line.hasPrefix("@@"), !line.hasPrefix("[") else { return [] }

        if line.hasPrefix("||") {
            // Only accept pure domain rules: ||domain^ with optional $important.
            var rule = line.dropFirst(2)
            if let dollar = rule.firstIndex(of: "$") {
                let options = rule[rule.index(after: dollar)...]
                guard options == "important" else { return [] }
                rule = rule[..<dollar]
            }
            guard rule.hasSuffix("^") else { return [] }
            return validated(String(rule.dropLast())).map { [$0] } ?? []
        }

        let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
        guard let first = fields.first else { return [] }

        if fields.count > 1, isIPAddress(first) {
            return fields.dropFirst().compactMap { field in
                let name = String(field).lowercased()
                return hostsIgnored.contains(name) ? nil : validated(name)
            }
        }

        guard fields.count == 1 else { return [] }
        var domain = first
        if domain.hasPrefix("*.") { domain = domain.dropFirst(2) }
        return validated(String(domain)).map { [$0] } ?? []
    }

    /// Returns the normalized domain if it looks like a real hostname.
    static func validated(_ candidate: String) -> String? {
        let domain = DomainHash.normalize(candidate)
        guard domain.count <= 253, domain.contains("."), !domain.hasPrefix("."), !domain.contains("..") else { return nil }
        let allowed = domain.utf8.allSatisfy { c in
            (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 45 || c == 46 || c == 95
        }
        guard allowed, !isIPAddress(Substring(domain)) else { return nil }
        return domain
    }

    private static func isIPAddress(_ s: Substring) -> Bool {
        if s.contains(":") { return true }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        return parts.count == 4 && parts.allSatisfy { UInt8($0) != nil }
    }
}

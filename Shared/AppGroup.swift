import Foundation

/// Locations and settings shared between the app and the packet tunnel extension.
enum AppGroup {
    static let identifier = "group.com.roxuh.advoid"
    static let tunnelBundleIdentifier = "com.roxuh.advoid.tunnel"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// False when the App Group entitlement is missing, in which case the app and tunnel
    /// can't see each other's files and rule changes must not be reported as saved.
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    /// Compiled, sorted domain hashes the tunnel blocks.
    static var blocklistURL: URL { containerURL.appendingPathComponent("blocklist.bin") }
    /// Compiled, sorted domain hashes the tunnel never blocks.
    static var allowlistURL: URL { containerURL.appendingPathComponent("allowlist.bin") }
    /// Per-source compiled hashes, so toggling a list doesn't need a re-download.
    static var sourcesDirectory: URL { containerURL.appendingPathComponent("sources", isDirectory: true) }
}

/// Messages the app sends to the running tunnel.
enum TunnelMessage: String {
    case reloadRules
    case resetStats
}

/// Addresses used inside the tunnel. Only the DNS address is routed into it,
/// so all other traffic keeps flowing over the normal interface untouched.
enum TunnelAddress {
    static let local = "10.13.37.2"
    static let dns = "10.13.37.1"
}

enum UpstreamDNS: String, CaseIterable, Identifiable {
    case cloudflare
    /// Cloudflare for Families: also blocks malware.
    case cloudflareSecurity
    /// Cloudflare for Families: also blocks malware and adult content.
    case cloudflareFamily
    case quad9
    case google

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cloudflare: "Cloudflare"
        case .cloudflareSecurity: "Cloudflare Security"
        case .cloudflareFamily: "Cloudflare Family"
        case .quad9: "Quad9"
        case .google: "Google"
        }
    }

    var address: String {
        switch self {
        case .cloudflare: "1.1.1.1"
        case .cloudflareSecurity: "1.1.1.2"
        case .cloudflareFamily: "1.1.1.3"
        case .quad9: "9.9.9.9"
        case .google: "8.8.8.8"
        }
    }

    /// DNS-over-HTTPS endpoint, by IP so reaching it never needs a lookup of its own.
    var dohURL: URL {
        URL(string: "https://\(address)/dns-query")!
    }

    private static let key = "upstreamDNS"
    private static let fallbackKey = "allowsPlainDNSFallback"

    /// Whether lookups may go out as plain DNS when DNS-over-HTTPS can't be reached. On unless the user turns it off.
    static var allowsPlainFallback: Bool {
        get { AppGroup.defaults.object(forKey: fallbackKey) as? Bool ?? true }
        set { AppGroup.defaults.set(newValue, forKey: fallbackKey) }
    }

    static var current: UpstreamDNS {
        get { AppGroup.defaults.string(forKey: key).flatMap(UpstreamDNS.init) ?? .cloudflare }
        set { AppGroup.defaults.set(newValue.rawValue, forKey: key) }
    }
}

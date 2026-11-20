import Foundation

/// Bundle identifiers, rather than App Store locale codes. English (US) is the source language.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ar, bn, ca, cs, da, de, el, en
    case enAU = "en-AU", enCA = "en-CA", enGB = "en-GB"
    case es, esMX = "es-MX", fi, fr, frCA = "fr-CA"
    case gu, hi, hr, hu, id, it, ja, kn, ko, ml, mr, ms
    case nlNL = "nl-NL", nb, or, pa, pl
    case ptBR = "pt-BR", ptPT = "pt-PT"
    case ro, ru, sk, sl, sv, ta, te, th, tr, uk, ur, vi
    case zhHans = "zh-Hans", zhHant = "zh-Hant"

    var id: Self { self }

    /// Use the entire identifier so regional variants have distinguishable native names.
    var nativeName: String {
        let identifier = self == .en ? "en-US" : rawValue
        let locale = Locale(identifier: identifier)
        return locale.localizedString(forIdentifier: identifier) ?? rawValue
    }

    var isRightToLeft: Bool { self == .ar || self == .ur }

    /// Preserve script and region. Only Apple's obsolete Norwegian code is renamed.
    static func canonicalIdentifier(_ identifier: String) -> String {
        let parts = identifier.replacingOccurrences(of: "_", with: "-").split(separator: "-")
        guard let first = parts.first else { return "" }
        let language = first.lowercased() == "no" ? "nb" : first.lowercased()
        let suffix = parts.dropFirst().prefix { $0.count != 1 }.map { part -> String in
            if part.count == 4 { return part.lowercased().capitalized }
            return part.uppercased()
        }
        return ([language] + suffix).joined(separator: "-")
    }

    /// Full-tag matches come first; language-only fallback must not collapse Chinese scripts.
    static func candidates(for identifier: String) -> [Self] {
        let tag = canonicalIdentifier(identifier)
        let base = tag.split(separator: "-").first.map(String.init) ?? ""
        guard base != "he", base != "iw", base != "system" else { return [] }
        if base == "zh" {
            let traditional = tag.contains("-Hant") || (!tag.contains("-Hans") &&
                ["TW", "HK", "MO"].contains(Locale(identifier: tag).region?.identifier ?? ""))
            return [traditional ? .zhHant : .zhHans]
        }
        var result = Self(rawValue: tag).map { [$0] } ?? []
        // Explicit scripts such as en-Latn-GB must still retain a supported region.
        if let region = Locale(identifier: tag).region?.identifier,
           let regional = Self(rawValue: "\(base)-\(region)"), !result.contains(regional) {
            result.append(regional)
        }
        let fallback: Self? = switch base {
        case "nl": .nlNL
        case "pt": .ptPT
        default: Self(rawValue: base)
        }
        if let fallback, !result.contains(fallback) { result.append(fallback) }
        return result
    }

    /// Do not offer a language until its actual bundle exists.
    static func available(in localizations: [String]) -> [Self] {
        let identifiers = Set(localizations.map(canonicalIdentifier))
        return allCases.filter { $0 != .system && identifiers.contains($0.rawValue) }
            .sorted { $0.nativeName.compare($1.nativeName, locale: Locale(identifier: "en")) == .orderedAscending }
    }

    static func resolve(preferences: [String], available: [String]) -> Self {
        let supported = Set(Self.available(in: available))
        for preference in preferences {
            if let match = candidates(for: preference).first(where: supported.contains) { return match }
        }
        return .en
    }

    /// Explicitly selected regions control formatting; otherwise retain the device's region.
    func formattingLocale(region: Locale.Region? = Locale.current.region) -> Locale {
        var components = Locale.Components(identifier: rawValue)
        if components.languageComponents.region == nil { components.languageComponents.region = region }
        return Locale(components: components)
    }
}

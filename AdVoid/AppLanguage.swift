import Foundation
import Observation

/// A language the app can show, or `system` to follow iOS.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, en, de, fr, es

    var id: Self { self }

    /// The language in its own words, so people can find theirs whatever the app is showing.
    var nativeName: String {
        let locale = Locale(identifier: rawValue)
        return locale.localizedString(forLanguageCode: rawValue)?.capitalized(with: locale) ?? rawValue
    }
}

/// The language AdVoid shows. Picking one in Settings applies right away.
///
/// The choice is saved where iOS keeps the per-app language from Settings › AdVoid › Language,
/// so both places always agree and the next launch starts in it, paywall and system text included.
@MainActor
@Observable
final class LanguageSettings {
    private static let appleLanguages = "AppleLanguages"

    var language: AppLanguage {
        didSet {
            if language == .system {
                UserDefaults.standard.removeObject(forKey: Self.appleLanguages)
            } else {
                UserDefaults.standard.set([language.rawValue], forKey: Self.appleLanguages)
            }
            apply()
        }
    }

    /// The localization in use, e.g. "de". Changes whenever the language does.
    private(set) var code = "en"

    /// For formatting dates and numbers in the chosen language, keeping the user's region.
    var locale: Locale {
        Locale(languageCode: .init(code), languageRegion: Locale.current.region)
    }

    init() {
        let saved = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "")?[Self.appleLanguages]
        let code = (saved as? [String])?.first.flatMap { Locale.Language(identifier: $0).languageCode?.identifier }
        language = code.flatMap(AppLanguage.init) ?? .system
        apply()
    }

    private func apply() {
        // With no choice of its own, the app follows the system list, which the process only reads at launch.
        let preferences = language == .system
            ? UserDefaults.standard.stringArray(forKey: Self.appleLanguages)
            : [language.rawValue]
        code = Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: preferences).first ?? "en"
        Bundle.appLanguage = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
    }
}

extension Bundle {
    /// The strings for the in-app language. `String(localized:)` sticks to the launch language
    /// unless it's given this bundle; SwiftUI text follows the environment locale by itself.
    nonisolated(unsafe) static var appLanguage = Bundle.main
}

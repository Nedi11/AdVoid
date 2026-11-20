import Foundation
import Observation

/// Picking a language updates SwiftUI and app-owned localized strings immediately.
@MainActor
@Observable
final class LanguageSettings {
    private static let appleLanguages = "AppleLanguages"
    private let defaults: UserDefaults
    private let domain: String
    private let localizations: [String]
    private let updateBundle: Bool
    private let systemPreferences: (() -> [String])?
    private var readingPreferences = false

    var language: AppLanguage {
        didSet {
            if !readingPreferences {
                if language == .system {
                    defaults.removeObject(forKey: Self.appleLanguages)
                } else {
                    defaults.set([language.rawValue], forKey: Self.appleLanguages)
                }
            }
            apply()
        }
    }

    private(set) var code = "en"
    var locale: Locale { (AppLanguage(rawValue: code) ?? .en).formattingLocale() }
    var isRightToLeft: Bool { (AppLanguage(rawValue: code) ?? .en).isRightToLeft }
    var availableLanguages: [AppLanguage] { AppLanguage.available(in: localizations) }

    init(defaults: UserDefaults = .standard,
         domain: String = Bundle.main.bundleIdentifier ?? "",
         localizations: [String] = Bundle.main.localizations,
         updateBundle: Bool = true,
         systemPreferences: (() -> [String])? = nil) {
        self.defaults = defaults
        self.domain = domain
        self.localizations = localizations
        self.updateBundle = updateBundle
        self.systemPreferences = systemPreferences
        language = .system
        refreshFromPreferences()
        #if DEBUG
        // Seed a genuine saved selection for simulator captures and UI tests.
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-demoLanguage"), index + 1 < arguments.count,
           let selected = AppLanguage(rawValue: arguments[index + 1]), selected != .system {
            defaults.set([selected.rawValue], forKey: Self.appleLanguages)
            refreshFromPreferences()
        }
        #endif
    }

    /// Re-read per-app Settings changes when returning to the foreground.
    func refreshFromPreferences() {
        let saved = (defaults.persistentDomain(forName: domain)?[Self.appleLanguages] as? [String])?.first
        readingPreferences = true
        language = saved.flatMap { AppLanguage.candidates(for: $0).first } ?? .system
        readingPreferences = false
    }

    private func apply() {
        let preferences = language == .system
            ? (systemPreferences?() ?? defaults.stringArray(forKey: Self.appleLanguages) ?? Locale.preferredLanguages)
            : [language.rawValue]
        code = AppLanguage.resolve(preferences: preferences, available: localizations).rawValue
        if updateBundle {
            Bundle.appLanguage = Bundle.main.path(forResource: code, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        }
    }
}

extension Bundle {
    /// Non-SwiftUI strings must explicitly use this bundle after runtime switching.
    nonisolated(unsafe) static var appLanguage = Bundle.main
}

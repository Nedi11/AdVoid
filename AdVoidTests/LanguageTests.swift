import Foundation
import Testing
@testable import AdVoid

@Suite(.serialized)
@MainActor
struct LanguageTests {
    private let all = AppLanguage.allCases.filter { $0 != .system }.map(\.rawValue)

    @Test func canonicalTagsAndLegacySelections() {
        #expect(AppLanguage.canonicalIdentifier("PT_br") == "pt-BR")
        #expect(AppLanguage.canonicalIdentifier("zh_hant_TW") == "zh-Hant-TW")
        #expect(AppLanguage.canonicalIdentifier("no_NO") == "nb-NO")
        #expect(AppLanguage.canonicalIdentifier("en-GB-u-hc-h23") == "en-GB")
        for tag in ["en", "de", "fr", "es", "en-AU", "en-CA", "en-GB", "es-MX", "fr-CA", "pt-BR", "pt-PT", "zh-Hans", "zh-Hant"] {
            #expect(AppLanguage.resolve(preferences: [tag], available: all).rawValue == tag)
        }
        #expect(AppLanguage.resolve(preferences: ["no-NO"], available: all) == .nb)
        #expect(AppLanguage.resolve(preferences: ["en-Latn-GB"], available: all) == .enGB)
    }

    @Test func preferenceOrderAndFallbacks() {
        #expect(AppLanguage.resolve(preferences: ["he-IL", "fr-CA", "de"], available: all) == .frCA)
        #expect(AppLanguage.resolve(preferences: ["he", "iw-IL"], available: all) == .en)
        #expect(AppLanguage.resolve(preferences: ["fr-CA", "de"], available: ["en", "fr", "de"]) == .fr)
        #expect(AppLanguage.resolve(preferences: ["ja", "de"], available: ["en", "de"]) == .de)
        #expect(AppLanguage.resolve(preferences: ["zh-TW"], available: all) == .zhHant)
        #expect(AppLanguage.resolve(preferences: ["zh-HK"], available: all) == .zhHant)
        #expect(AppLanguage.resolve(preferences: ["zh-Hans-TW"], available: all) == .zhHans)
        #expect(AppLanguage.resolve(preferences: ["zh-Hant", "de"], available: ["en", "zh-Hans", "de"]) == .de)
        #expect(AppLanguage.resolve(preferences: ["pt-BR"], available: ["en", "pt-PT"]) == .ptPT)
    }

    @Test func shippedLanguagesMatchPicker() {
        #expect(all.count == 49)
        #expect(Set(AppLanguage.available(in: Bundle.main.localizations).map(\.rawValue)) == Set(all))
        #expect(AppLanguage.available(in: ["Base", "he", "he-IL", "iw", "en", "de"]).count == 2)
        #expect(AppLanguage.enGB.nativeName != AppLanguage.en.nativeName)
        #expect(AppLanguage.frCA.nativeName != AppLanguage.fr.nativeName)
        #expect(AppLanguage.zhHant.nativeName != AppLanguage.zhHans.nativeName)
    }

    @Test func selectionSurvivesRelaunchAndSystemResetOnlyRemovesOverride() throws {
        let domain = "AdVoid.LanguageTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set(true, forKey: "hasSeenOnboarding")
        for choice in AppLanguage.allCases where choice != .system {
            let settings = LanguageSettings(defaults: defaults, domain: domain, localizations: all, updateBundle: false)
            settings.language = choice
            #expect(defaults.stringArray(forKey: "AppleLanguages") == [choice.rawValue])
            let relaunched = LanguageSettings(defaults: defaults, domain: domain, localizations: all, updateBundle: false)
            #expect(relaunched.language == choice)
            #expect(relaunched.code == choice.rawValue)
            #expect(relaunched.isRightToLeft == (choice == .ar || choice == .ur))
            relaunched.language = .system
            #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil)
            #expect(defaults.bool(forKey: "hasSeenOnboarding"))
        }
    }

    @Test func systemResetResumesSupportedPreferenceOrder() throws {
        let domain = "AdVoid.LanguageTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let settings = LanguageSettings(defaults: defaults, domain: domain, localizations: all, updateBundle: false,
                                        systemPreferences: { ["he-IL", "fr-CA", "de"] })
        #expect(settings.language == .system)
        #expect(settings.code == "fr-CA")
        settings.language = .ar
        #expect(settings.isRightToLeft)
        settings.language = .system
        #expect(settings.code == "fr-CA")
        #expect(!settings.isRightToLeft)
        #expect(defaults.persistentDomain(forName: domain)?["AppleLanguages"] == nil)
    }

    @Test func externalSettingsChangesAndImmediateBundleSwitching() throws {
        let domain = "AdVoid.LanguageTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: domain))
        let originalBundle = Bundle.appLanguage
        defer {
            defaults.removePersistentDomain(forName: domain)
            Bundle.appLanguage = originalBundle
        }
        let settings = LanguageSettings(defaults: defaults, domain: domain, localizations: all)
        for choice in [AppLanguage.ar, .ur, .zhHant, .ptBR, .enGB, .de, .en] {
            defaults.set([choice.rawValue], forKey: "AppleLanguages")
            settings.refreshFromPreferences()
            #expect(settings.language == choice)
            #expect(settings.code == choice.rawValue)
            #expect(settings.isRightToLeft == choice.isRightToLeft)
            #expect(Bundle.appLanguage.bundleURL.lastPathComponent == "\(choice.rawValue).lproj")
        }
        defaults.set(["no"], forKey: "AppleLanguages")
        settings.refreshFromPreferences()
        #expect(settings.language == .nb)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["no"])
        defaults.removeObject(forKey: "AppleLanguages")
        settings.refreshFromPreferences()
        #expect(settings.language == .system)
    }

    @Test func selectedRegionsAndScriptsControlFormatting() {
        #expect(AppLanguage.ptBR.formattingLocale(region: .init("AL")).region?.identifier == "BR")
        #expect(AppLanguage.enGB.formattingLocale(region: .init("US")).region?.identifier == "GB")
        #expect(AppLanguage.de.formattingLocale(region: .init("AL")).region?.identifier == "AL")
        let traditional = AppLanguage.zhHant.formattingLocale(region: .init("TW"))
        #expect(traditional.language.script?.identifier == "Hant")
        #expect(traditional.region?.identifier == "TW")
        #expect(1234.5.formatted(.number.locale(AppLanguage.ptBR.formattingLocale())).contains(",5"))
    }

    @Test func interpolatedMessagesKeepBothArgumentsInEveryLanguage() throws {
        let name = "list-marker.example"
        let reason = "error-marker-431"
        for language in AppLanguage.allCases where language != .system && language != .en {
            let path = try #require(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            let message = String(localized: "Couldn't download \(name): \(reason)", bundle: bundle,
                                 locale: language.formattingLocale())
            #expect(message.contains(name))
            #expect(message.contains(reason))
            #expect(!message.contains("%@"))
            #expect(!message.contains("$@"))
        }
    }

    @Test func eachBundleResolvesEveryAppString() throws {
        // Check real compiled resources, not catalog-entry counts.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("AdVoid/Localizable.xcstrings")
        let catalog = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])
        for language in AppLanguage.allCases where language != .system && language != .en {
            let path = try #require(Bundle.main.path(forResource: language.rawValue, ofType: "lproj"))
            let bundle = try #require(Bundle(path: path))
            for (key, entry) in strings where entry["shouldTranslate"] as? Bool != false {
                #expect(bundle.localizedString(forKey: key, value: "__MISSING__", table: nil) != "__MISSING__",
                        "Missing \(language.rawValue): \(key)")
            }
        }
    }
}

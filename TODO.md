# AdVoid localization TODO

## Completed preparation and App Store work

- [x] Localized the editable App Store version **1.2** for 49 locales, excluding Hebrew.
- [x] Uploaded and read back 147 screenshots and 49 search-result creative assets.
- [x] Added realistic Dynamic Island iPhone frames and compact headline typography.
- [x] Localized descriptions, keywords, subtitles, promotional copy and lifetime-purchase release notes.
- [x] Preserved the live 1.1 release; 1.2 remains editable and has not been submitted for review.
- [x] Prepared the complete in-app implementation instructions below. **The in-app implementation is still TODO.**

## Goal and current state

- [ ] Add the same language coverage inside the app, excluding Hebrew (`he` and all its regional variants).

Current source inspection: `AdVoid/Localizable.xcstrings` contains **170 keys**, with **165 localization entries each for German, French and Spanish**. Some keys deliberately have `shouldTranslate: false`, so raw counts are not a completeness test. English is the source language. `AppLanguage` currently exposes only System, English, German, French and Spanish.

Store copy in `output/app-store-calm/localizations.json` is a locale inventory and terminology reference, **not a translation of the app's 170 UI keys**. Use the existing app catalog as the source of truth. No app source strings have been translated into the additional languages yet.

## Implementation order

### 1. Inventory and export the real app strings

- [ ] Open `AdVoid.xcodeproj` on a Mac with the supported Xcode/iOS SDK. Build once to refresh extracted string-catalog entries.
- [ ] Review every entry in `AdVoid/Localizable.xcstrings`: active keys, stale keys, placeholders, plurals, extraction state, and intentionally untranslated strings.
- [ ] Audit `AdVoid/Views/` (Home, Stats, Activity, Settings, Onboarding), `AdVoid/TunnelController.swift`, `AdVoid/BlocklistManager.swift`, `AdVoid/StatsModel.swift`, `Shared/`, and `PacketTunnel/` for user-visible literals, errors and accessibility labels outside the catalog.
- [ ] Route user-facing non-SwiftUI text through the existing `String(localized: ..., bundle: .appLanguage)` pattern where appropriate. Never translate domain names, URLs, product IDs, blocklist names, API keys or internal log identifiers.
- [ ] Give ambiguous keys translator comments: DNS lookup versus a web visit, blocked domain versus blocked request, current versus lifetime count, allowlist versus blocklist, subscription versus lifetime purchase.
- [ ] Export localizations using Xcode's localization export workflow. Keep the catalog and exported translator context together during review; import validated translations back through Xcode rather than blind text substitution.

### 2. Translate the catalog, preserving behavior

- [ ] Add translations for every translatable active key in every bundle locale in the table below. Preserve existing German/French/Spanish translations and improve them only when needed.
- [ ] Preserve format specifiers and interpolation types (`%@`, `%lld`, positional arguments and interpolated values). Compare placeholder signatures with English before importing.
- [ ] Use string-catalog plural variations where quantities require different grammar. Include each language's required plural categories; do not assemble sentences by concatenating translated fragments.
- [ ] Keep `shouldTranslate: false` entries untranslated and brand/product names unchanged. A translated state's presence alone does not prove the text has been reviewed.
- [ ] Keep terminology consistent for protection, blocklists, custom rules, DNS, tracking, activity and statistics. Short control labels should remain usable at large text sizes.
- [ ] Have native speakers review the new UI translations, especially security claims, errors, onboarding and purchase text. The existing store translations are machine-generated and should also be reviewed when used as terminology references.

### 3. Fix language identity and persistence before adding picker entries

Primary file: `AdVoid/AppLanguage.swift`.

- [ ] Extend or replace the `AppLanguage` enum so it represents all target bundle identifiers plus `system`. Use explicit raw values for tags with hyphens; do not derive a locale by truncating its identifier.
- [ ] Fix initialization: it currently extracts only `Locale.Language(...).languageCode`, which loses the script/region in tags such as `zh-Hant`, `pt-BR`, `fr-CA` and `en-GB`. Preserve and canonicalize the full selected identifier, including script and meaningful region.
- [ ] Migrate existing `AppleLanguages` selections (`en`, `de`, `fr`, `es`) without resetting users' choices. Map Apple's legacy `no` preference to Norwegian Bokmål `nb` as appropriate.
- [ ] Ensure simplified and traditional Chinese are separate choices. Preserve the English, French, Spanish and Portuguese regional variants in the table.
- [ ] Resolve the selected language against `Bundle.main.localizations`; use explicit fallback rules and English when no supported localization is available. Keep System following the user's supported preference order.
- [ ] Update the `locale` construction: the existing `.init(code)` language-only approach must not treat a full script/region tag as a plain language code. Preserve the chosen language and script while applying a deliberate, tested region-formatting policy.
- [ ] Generate native picker names from the full locale identifier (`localizedString(forIdentifier:)` or a reviewed mapping), so regional variants have distinct names. Keep native names readable even when the current UI is another language.
- [ ] Keep the picker in `AdVoid/Views/SettingsView.swift` synchronized with the supported bundle localizations. Include System once; exclude Hebrew; use a predictable native-name order.

### 4. Runtime switching, RTL and accessibility

Primary integration point: `RootView` in `AdVoid/AdVoidApp.swift` already sets `.environment(\.locale, language.locale)` and rebuilds with `.id(language.code)`.

- [ ] Confirm language changes update SwiftUI text and `Bundle.appLanguage` lookups immediately, while preserving the selected tab, protection state, rules and purchase entitlement.
- [ ] Apply and test right-to-left layout direction for **Arabic and Urdu**, including immediate switching back to an LTR language. Do not depend on the locale environment alone without testing.
- [ ] Replace hard-coded left/right layout assumptions with leading/trailing where semantically appropriate. Keep numbers, DNS names and URLs in a readable direction inside RTL content. Mirror directional navigation symbols when appropriate; do not mirror logos or the app's data arbitrarily.
- [ ] Check Dynamic Type, multiline buttons, text truncation, VoiceOver labels/hints, charts, segmented controls, empty states and error banners in every writing system.
- [ ] Format dates, times, counts and percentages with locale-aware formatters. Rebuild cached strings or cached chart labels after switching languages.
- [ ] Test restart persistence and the interaction with iOS Settings → AdVoid → Language, including changes made outside the app. Verify System reset removes only the app's language override.

### 5. Purchase and system-owned surfaces

- [ ] Audit the RevenueCat `PaywallView` in `AdVoid/AdVoidApp.swift`. Its hosted paywall copy, package labels, trial wording, restore flow and error messages may need their own localization configuration in RevenueCat.
- [ ] Localize App Store Connect subscription and lifetime in-app-purchase display names/descriptions separately, where Apple supports the target locales. Do not assume app catalog translations update product metadata.
- [ ] Use StoreKit's localized prices and subscription periods rather than translated or hard-coded prices. Clearly distinguish auto-renewing subscriptions from the one-time lifetime product.
- [ ] Keep legal links correct. Audit any app-owned permission/Info.plist text and extension-owned errors; system VPN permission dialogs use Apple's supported system languages, not arbitrary app-authored replacements.

### 6. Project configuration and validation

- [ ] Update localization configuration in the source project generator `project.yml` if needed; regenerate with `xcodegen generate`. Do not make an unexplained manual-only change to the generated `.pbxproj`.
- [ ] Verify the built application's actual `.lproj` directories and `Bundle.main.localizations`. App Store locale codes and app bundle locale identifiers are not interchangeable; use the mapping below.
- [ ] Add a catalog validator that checks the expected locale set, required key coverage, missing or unreviewed string units, valid plural structures, placeholder signatures and deliberately untranslated keys. Make its report actionable by key and locale.
- [ ] Add focused tests for full-tag canonicalization, legacy selection migration, fallback order, script/regional variant persistence, System reset, formatting and runtime LTR↔RTL switching.
- [ ] Build and run the existing `AdVoidTests` suite on a supported iPhone Simulator on a Mac. Use `xcodebuild -showdestinations -project AdVoid.xcodeproj -scheme AdVoid` to select an installed destination before running tests.
- [ ] Smoke-test all languages for missing strings. Give extra visual coverage to Arabic/Urdu, Simplified/Traditional Chinese, Japanese/Korean/Thai, Indic scripts, long German/Finnish text and all regional variants.
- [ ] Test purchase/restore UI in sandbox and protection on a physical iPhone: the simulator cannot run AdVoid's packet-tunnel VPN.

### 7. Capture and release

- [ ] Capture fresh screenshots from the running localized app on a Mac/iPhone, using the repo's existing debug/demo launch flags and consistent sample activity. Do not synthesize translated app UI over English captures.
- [ ] Replace the current English UI captures for newly supported languages with those genuine localized captures. The existing `de`, `fr` and `es` captures can remain until the UI changes.
- [ ] Re-render the store artwork with `render_v3.py` and `render_media.py`, preserving the current Dynamic Island frame and compact typography; visually verify truncation and RTL before uploading.
- [ ] Run `scripts/sync-store.mjs` in read-only mode first. Use `--apply --artwork-only` for an artwork-only revision, followed by `scripts/verify-store.mjs`. Never put Apple `.p8` files or runtime secrets in Git.
- [ ] Increment the app build number, archive and validate the build, then upload it through the established Apple distribution workflow. Ensure every claimed in-app language is actually bundled.
- [ ] Verify the lifetime product is correctly associated with the release and that App Review notes explain its purchase flow. Prepare review submission separately; do not auto-submit as part of translation work.
- [ ] Update this checklist and mark implementation complete only after catalog validation, device/UI QA, purchase QA and distribution validation pass.

## App Store → in-app locale mapping

English `en` remains the source catalog language and represents English (U.S.). Existing `de`, `fr` and `es` bundles are retained. Regional variants must be independently selectable and persist correctly. Norwegian uses Bokmål `nb` inside the app.

| App Store locale | Language | App bundle / picker raw value |
| --- | --- | --- |
| `ar-SA` | Arabic | `ar` |
| `bn-BD` | Bengali | `bn` |
| `ca` | Catalan | `ca` |
| `cs` | Czech | `cs` |
| `da` | Danish | `da` |
| `de-DE` | German | `de` |
| `el` | Greek | `el` |
| `en-AU` | English (Australia) | `en-AU` |
| `en-CA` | English (Canada) | `en-CA` |
| `en-GB` | English (UK) | `en-GB` |
| `en-US` | English (US) | `en` |
| `es-ES` | Spanish (Spain) | `es` |
| `es-MX` | Spanish (Mexico) | `es-MX` |
| `fi` | Finnish | `fi` |
| `fr-CA` | French (Canada) | `fr-CA` |
| `fr-FR` | French | `fr` |
| `gu-IN` | Gujarati | `gu` |
| `hi` | Hindi | `hi` |
| `hr` | Croatian | `hr` |
| `hu` | Hungarian | `hu` |
| `id` | Indonesian | `id` |
| `it` | Italian | `it` |
| `ja` | Japanese | `ja` |
| `kn-IN` | Kannada | `kn` |
| `ko` | Korean | `ko` |
| `ml-IN` | Malayalam | `ml` |
| `mr-IN` | Marathi | `mr` |
| `ms` | Malay | `ms` |
| `nl-NL` | Dutch | `nl-NL` |
| `no` | Norwegian | `nb` |
| `or-IN` | Odia | `or` |
| `pa-IN` | Punjabi | `pa` |
| `pl` | Polish | `pl` |
| `pt-BR` | Portuguese (Brazil) | `pt-BR` |
| `pt-PT` | Portuguese (Portugal) | `pt-PT` |
| `ro` | Romanian | `ro` |
| `ru` | Russian | `ru` |
| `sk` | Slovak | `sk` |
| `sl-SI` | Slovenian | `sl` |
| `sv` | Swedish | `sv` |
| `ta-IN` | Tamil | `ta` |
| `te-IN` | Telugu | `te` |
| `th` | Thai | `th` |
| `tr` | Turkish | `tr` |
| `uk` | Ukrainian | `uk` |
| `ur-PK` | Urdu | `ur` |
| `vi` | Vietnamese | `vi` |
| `zh-Hans` | Chinese (Simplified) | `zh-Hans` |
| `zh-Hant` | Chinese (Traditional) | `zh-Hant` |

Acceptance: all 49 mapped locale choices resolve to shipped, validated strings; Hebrew is absent; no placeholder/plural errors; RTL and purchase flows pass QA; user selections survive relaunch and upgrades.

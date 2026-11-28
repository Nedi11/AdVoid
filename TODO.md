# AdVoid localization TODO

Updated 20 November 2026. The 49-language in-app implementation is complete; release QA items below remain explicitly open. Hebrew and its legacy/regional identifiers are excluded.

## Implemented

- [x] Fill all 170 translatable UI keys in all 48 non-source locales; retain the 5 deliberately untranslated entries. English remains the source. Regional English, French, Spanish and Portuguese bundles remain independently selectable.
- [x] Preserve existing German/French/Spanish translations except count labels, which now use complete label-and-value strings to avoid quantity-dependent noun agreement with preformatted numbers. No translated sentence is assembled from fragments.
- [x] Represent the full 49 bundle identifiers in `AppLanguage`; canonicalize scripts, regions, underscores, Unicode extensions and legacy Norwegian `no` → `nb`.
- [x] Resolve preferences in order against actual shipped bundles, preserve Chinese script distinctions and fall back to English. Retain the device's region for language-only choices; explicit regional choices control formatting.
- [x] Generate distinct native picker names, including English (United States), and show System plus only shipped languages in a scrolling language list.
- [x] Persist full language identifiers, support external iOS Settings changes on foregrounding, and remove only the app's `AppleLanguages` override for System.
- [x] Switch SwiftUI locale, app-owned string lookups and Arabic/Urdu layout direction immediately while preserving the selected tab and Settings navigation path.
- [x] Recompute app-owned model errors and chart labels in the active language. Keep domains and URL inputs left-to-right; retain brands, product names, hostnames, identifiers and technical syntax.
- [x] Use the selected locale for dates, counts and percentages.
- [x] Pass the app's selected locale to RevenueCat's own preferred-UI-locale override. Hosted paywall availability still depends on the separate RevenueCat configuration.
- [x] Regenerate `AdVoid.xcodeproj` from `project.yml`, include language and UI tests, and set version 1.2 build 20.
- [x] Add an offline catalog validator and CI check for expected locales, required-key coverage, untranslated keys, stale/unreviewed units, plural structure and positional/type-safe placeholders.
- [x] Record machine-translation provenance in `output/localization/translation-provenance.json`.

## Validation

- [x] Apple string-catalog compiler accepts the catalog.
- [x] Catalog validator passes: 175 keys, 170 translatable, all 49 languages, zero structural/placeholder errors.
- [x] Validator regression tests cover missing locales, wrong placeholder types, positional argument reordering, forbidden Hebrew, untranslated brands, review states and malformed plurals.
- [x] Unit tests check all 49 saved selections, relaunch, System reset/preference order, external changes, full tags and legacy migration, fallback order, formatting, RTL state and every real compiled bundle/key.
- [x] Final simulator checks: 43 unit tests and 2 accessibility/runtime UI tests passed; separate 24-language/all-tab UI smoke test passed with 120 screenshots. See `output/localization/verification.md`.
- [x] Generate the final Release archive, version 1.2 (20), and verify all 49 shipped language directories.
- [ ] Distribution export/upload deferred to the user: Xcode account credentials are missing and no distribution private key is accessible. The current archive and export options are in `output/builds/`; no final build was uploaded.

## Remaining human/device and release work

- [ ] Native speakers review the machine-assisted new translations, especially security claims, error text, DNS terminology and regional variants. Xcode's `translated` state denotes a populated translation, not completed human review.
- [ ] Review VoiceOver, maximum accessibility text sizes, and the complete UI in every language on device. Simulator screen coverage is representative, not a native-language review.
- [ ] Test protection on a physical iPhone; the simulator cannot run this packet tunnel.
- [ ] Test real sandbox purchase/restore flows and independently review hosted RevenueCat paywall translations and App Store product metadata. Catalog translations and the SDK locale override do not configure remote product/paywall copy.
- [ ] Capture/re-render/store-upload genuine localized marketing screenshots for newly added languages. UI-test evidence is not a replacement for the App Store artwork workflow.
- [ ] Complete App Store review preparation separately; uploading a build does not submit the release for review.

## Previous store preparation

The prior checklist records localization of editable App Store version 1.2 for 49 locales, with 147 screenshots and 49 search-result assets uploaded and read back. That store work was not repeated or independently verified by this implementation task. The live 1.1 release is separate.

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

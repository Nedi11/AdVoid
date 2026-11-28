# Localization verification — 20 November 2026

Version **1.2 (20)** implements all 49 requested in-app languages, excluding Hebrew. The source catalog has 175 entries: 170 translatable keys and 5 intentionally untranslated keys.

## Results

| Check | Result |
| --- | --- |
| Offline catalog validation | Pass: all expected locale/key pairs, zero structural or placeholder errors |
| Validator regression suite | 7 tests passed |
| Apple string-catalog compiler | Pass |
| Final iOS 26.5 simulator suite | 45 tests passed, zero failures: 43 unit tests and 2 UI tests |
| iOS 27.2 writing-system screen smoke test | Passed across 24 language/region choices and all 4 tabs; 120 screenshots captured |
| Runtime switching | English → Arabic → relaunch → English passed; tab positions reverse for RTL and return for LTR; Settings remains selected |
| Maximum accessibility text smoke test | Arabic, Finnish and Hindi Home/Settings captured and checked; text wraps and content scrolls |
| Full-tag persistence | All 49 choices survive a new settings instance; System reset preserves unrelated preferences |
| Real compiled resources | Every translatable key resolves in every non-source language bundle |
| Interpolated messages | Both inserted arguments survive localization in every non-source locale; multi-value translations use positional placeholders |
| Release archive | Succeeded, version 1.2 (20), exactly the expected 49 root `.lproj` directories |
| Final distribution export/upload | Deferred: Xcode reports missing account credentials and no accessible iOS Distribution private key; user will upload later |

The final clean 45-test result is `/tmp/AdVoid-language-final-checks.xcresult`. The successful writing-system UI test and its screenshot evidence are in `/tmp/AdVoid-language-verified.xcresult`; an earlier System-preference test in that run was corrected and is covered by the clean final result.

## Build and screenshot handoff

- Current archive: `output/builds/AdVoid-1.2-20.xcarchive`.
- Genuine simulator screen captures: `output/builds/language-screenshots/` (120 images and a manifest).
- Accessibility/runtime captures: `output/builds/accessibility-screenshots/` (8 images and a manifest).
- Build evidence and binary checksum: `build-verification.json`.
- Export options for resuming: `output/builds/app-store-export-options.plist` and `output/builds/app-store-upload-options.plist`.

Open the current archive in Xcode, restore the developer-account sign-in under Settings → Accounts, then Distribute App → App Store Connect. The archive is signed for development and must be re-signed for App Store distribution during export. Earlier exported IPAs under `output/builds/previous-export-before-final-fixes/` predate the final placeholder fixes and must not be uploaded.

Build outputs are deliberately ignored by Git; the source, tests, configuration and small verification reports are committed.

## Remaining QA

New translations are machine-assisted and require native-speaker review. Simulator checks do not validate the live packet tunnel on an iPhone or real sandbox purchase/restore flows. Hosted RevenueCat paywall text and App Store product translations require separate review. Fresh localized App Store marketing artwork and review submission remain separate release work; no release was submitted for review by this task.

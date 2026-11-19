# AdVoid calm App Store release assets

Approved direction: white background, strong black functional headlines, real existing app captures, a restrained phone frame, and one magnified UI fact. The shared `device.py` adds a black titanium iPhone frame with Dynamic Island, thin bezel, matched screen corner radius, camera lens and side buttons. Inspired by the current white Cal AI listing, not its older dark iPhone screenshot set.

49 App Store locales are included in `localizations.json`; Hebrew (`he`) is excluded. These are App Store translations, not new in-app languages. Existing German, French and Spanish UI captures are used where available; other artwork shows the real English UI with localized headlines, callouts and disclosures. Translations were prepared by a language model and have not had native-speaker review.

Version 1.2 adds a lifetime purchase option, so the metadata and English footer say AdVoid Pro is required rather than requiring a subscription specifically. Subscription plans still auto-renew. Release notes are localized from the existing 1.2 change note.

- `render_v3.py` renders three 1290×2796 PNGs per locale.
- `render_media.py` exports 1242×2688 and 1206×2622 iPhone variants and a 3840×2560 search-results creative for each locale.
- `build_localizations.py` builds the copy bundle; run `lifetime_copy.py` after it to keep the current purchase wording.
- Only English preview PNGs are tracked. All other language exports are reproducible and stay outside Git to keep the repository small.
- No iPad image is generated: the app targets iPhone only, and the old `source-captures/ipad/home.png` is actually a simulator home-screen capture, not AdVoid.

On Linux, rendering needs system Python, PyGObject, pycairo, the gi-cairo bridge, Pango and Noto fonts. The gi-cairo module can be supplied through `GI_CAIRO_PATH` if it was extracted locally rather than installed system-wide.

```bash
python3 build_localizations.py
python3 lifetime_copy.py
/usr/bin/python3 render_v3.py all
/usr/bin/python3 render_media.py all
```

From repository root, `node scripts/sync-store.mjs` preflights and shows the operation without writing. `--apply` updates the editable **1.2** version, app info localizations and media placements; it never submits for review. The script uses Storepilot's Apple client (`STOREPILOT_SOURCE` can override its source path), credentials from the private environment or `ASC_*`, and stores backups/reports outside Git. Each replacement group is restored on an observed placement failure. Uncertain network outcomes require a new read of Apple state before retrying.

The batch targets the existing app, version and editable App Info IDs explicitly. Update and verify these before reusing it for another release. New localized app names use AdVoid plus a local search term; existing localized names are preserved. The sync removes stale lower-resolution iPhone overrides so they inherit the new highest-resolution set, and obsolete optional iPad screenshot placements from 1.2 because the app targets iPhone only. Product-page header artwork is preserved.

`node scripts/verify-store.mjs` (from repository root) reads all 49 locales back from Apple and verifies copy, subtitles, screenshot order, content hashes, search-card count, and image readiness. Reports are stored privately outside Git.

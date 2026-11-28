# AdVoid screenshot styles

Both complete styles and their localized search covers are checked into Git. Each covers 49 App Store locales; Hebrew is excluded.

| Style | Screenshots | Search covers | Source |
| --- | --- | --- | --- |
| Calm | `app-store-calm/screenshots-v3/<locale>/` | `app-store-calm/search-cards/<locale>.png` | `app-store-calm/render_v3.py`, `render_media.py`, `device.py` |
| Charles / Domain underline | `charles-localized/<locale>/frames/` | `charles-localized/<locale>/search-cover.png` | `../scripts/build-charles-localizations.py`, `render-charles-localizations.py`, `render-charles-search-covers.py` |

Calm's primary set has three 1290 × 2796 PNGs per locale, plus smaller device exports. Charles has four 1320 × 2868 PNGs per locale. Both search-cover sets are 3840 × 2560. Shared Charles fonts and real UI captures are included in `charles-localized/fonts/` and `charles-localized/ui/`.

The primary sets total 343 screenshots and 98 search covers. See each style's README for rendering and experiment preparation. These are store assets, with machine-translated marketing copy; the captured in-app UI is preserved. Artwork stored in Git does not mean that an Apple experiment is running. Large ZIP bundles and regenerable preview/log files remain excluded.

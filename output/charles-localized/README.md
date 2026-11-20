# Calm vs Charles — release-gated experiment

Requested comparison, after version 1.2 is live:

| Page | Artwork | Traffic |
| --- | --- | --- |
| Original | Calm v3, already staged on version 1.2 | 50% |
| Single treatment | Charles / Domain underline | 50% |

All 49 listing locales are included. Hebrew is excluded. Metadata stays identical. Each style includes its own localized search cover, as requested. Calm has three screenshot frames; Charles has four, so this measures the complete creative set, including its sequence length and search cover.

`manifest.json` maps each locale to both asset directories. Charles PNGs are 1320 × 2868. The existing Calm PNGs are 1290 × 2796, also accepted for the primary iPhone screenshot group. Captured in-app UI remains English, as these assets localize the store listing only. Translations need native review.

Rebuild the localized HTML with `python3 scripts/build-charles-localizations.py`. Render each locale using the installed Charles skill's `scripts/shots.py render <locale>/set.html --scale 3`.

## Release gate

Run `node scripts/check-experiment-readiness.mjs` on the configured Storepilot host. This is read-only. It must not launch an experiment against version 1.1. It is not a background watcher and does not launch automatically.

1. Release version 1.2 through the normal app review/release process.
2. Verify all 49 live original locales contain the Calm artwork, by ordered asset content hashes.
3. Select which Apple draft to use. Existing draft `y` is preserved; it has four treatment localizations and is not empty.
4. Create/repurpose one treatment named Charles editorial. Upload the four localized screenshots in manifest order for all 49 locales. Keep listing text equal to the original; include the matching Charles search cover.
5. Set total treatment traffic to 50%, leaving 50% for the original. Do not create two treatments for this comparison.
6. Submit the new screenshot assets for Apple's review, if required. Confirm approval and all image processing states.
7. Start the test only after the original and treatment hashes, locales and traffic are verified. Confirm Apple's returned state is RUNNING before reporting a launch.

Current status: artwork preparation; no experiment has been started, no draft has been overwritten, and no app version has been released by this work.

Validation: `scripts/verify-charles-localizations.py` uses Playwright to check every localized headline after fonts load: minimum 40 CSS px, bounded width and height, RTL shaping through Chromium. The skill renderer also checks missing fonts/images, output dimensions and seam clearance. Visual review covers Arabic, German, Japanese and Kannada previews plus the approved English reference; it is not a native linguistic review of all 49 languages.

For a batch render on this host, run `/home/user/.cache/charles-screenshots-venv/bin/python scripts/render-charles-localizations.py`. The renderer expects the installed Charles skill and its Python environment. `review.md` records the skill bar and review limitations.

Search covers: Charles covers are `<locale>/search-cover.png` (3840 × 2560); Calm covers are `output/app-store-calm/search-cards/<locale>.png`. Rebuild with `scripts/render-charles-search-covers.py`. Treatment support for the search-cover placement must be verified against Apple's current placement specs before upload; do not silently replace the original cover if Apple does not permit treatment-specific covers.

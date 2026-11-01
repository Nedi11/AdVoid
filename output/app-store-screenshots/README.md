# AdVoid App Store screenshots

Open `compare.html` to compare all three sequences.

- `3-screenshots-condensed/` — 3 images combining the main benefits. Regenerate with `python render_set3.py` (needs Pillow, numpy).
- `4-screenshots-balanced/` — 4 images, including a dedicated Safari image.
- `5-screenshots-detailed/` — 5 images, one feature per image.
- `archives/` — one ZIP download per set.
- `source-captures/` — app screenshots used as references, with sample data.
- `design-notes/` — content plans and generation prompts.
- `earlier-drafts/` — the initial standalone variants and reference images.

Each final PNG is 1260 × 2736. Files within each set are numbered in listing order.

## Selected set: device exports

- `3-screenshots-condensed/iphone-1242x2688/` — final iPhone exports for the 6.5" display slot.
- `3-screenshots-condensed/iphone-1206x2622/` — final iPhone exports for the 6.1"/6.3" display slot.
- `3-screenshots-condensed/ipad-2048x2732/` — wider artwork retaining iPhone mockups; not native iPad UI captures.
- `archives/advoid-set-3-iphone-1242x2688.zip`
- `archives/advoid-set-3-iphone-1206x2622.zip`
- `archives/advoid-set-3-ipad-2048x2732.zip`

Earlier root-level PNGs remain as design masters. Use the device-specific exports for the requested pixel sizes.

## Localized sets (2026-11-01)

`3-screenshots-condensed/de/`, `fr/` and `es/` hold the same three images in German, French and
Spanish, in all the sizes above, with a ZIP per size in `archives/`. The phones show the app itself
running in that language, captured into `source-captures/<lang>/` from the iPhone 18 Pro Simulator
with Debug launch flags:

    -skipPaywall -hasSeenOnboarding YES -hasTappedPowerButton YES -demoProtected
    -demoTab home|stats|activity|settings -AppleLanguages "(de)" -AppleLocale de_DE

(launch once with `-demoStats` first so every language shows the same numbers). The copy is in
`design-notes/localized-copy.json`. Regenerate with `python render_set3.py de` (or `fr`, `es`).

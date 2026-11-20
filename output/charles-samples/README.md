# AdVoid English samples using charles-store-screenshots

Skill source: https://github.com/LemonFace0309/charles-skills/tree/main/skills/design/charles-store-screenshots

`en-editorial/` is a four-frame sample using its connected-strip workflow, two-frame hook, named signature move, local font loading, real UI crops, phone treatment, exact-size rendering, search-size QA and written review. No AI art/API generation was needed.

- `en-editorial/frames/`: four full-resolution 1320×2868 PNGs.
- `en-editorial/samples-preview.png`: compact four-frame PNG preview.
- `en-editorial/search.png`: first three frames on white and black, produced by the skill.
- `board.html`: self-contained review board produced by the skill's board command.
- `en-editorial/set.html`: editable strip source with lane/hook/move/levers and frame plan.
- `en-editorial/brief.md` and `review.md`: source facts and the skill's review checklist.
- Inter Tight is included locally under its accompanying SIL Open Font License.

Use a Python environment with Playwright, Pillow and requests, and install a Playwright Chromium browser. With the skill installed:

    python <skill>/scripts/shots.py render en-editorial/set.html --scale 3
    python <skill>/scripts/shots.py board en-editorial --out board.html --embed

These are fresh English samples, not replacements for the existing uploaded 49-locale artwork.

# AdVoid App Store creative assets

Specs from Apple's [creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) (iOS 27+).

| File | Placement | Size | Notes |
|------|-----------|------|-------|
| `header.mp4` | Product page header (video) | 3840 × 1646, 21:9 | H.264, 30 fps, 10 s, seamless loop, no audio |
| `header.png` | Product page header (image) | 3840 × 1646, 21:9 | First frame of the video; no alpha |
| `search-result.png` | Search results | 3840 × 2560, 3:2 | Uses the real Home screen capture; no alpha |

Apple publishes no safe zones, so the header keeps everything important in the
center and the edges are decorative. Check the crop in App Store Connect's preview
on iPhone and iPad before submitting.

Regenerate (needs Pillow, numpy, ffmpeg):

    python render_header.py still
    python render_header.py video
    python render_search.py

"""Renders the AdVoid search results asset (3:2, 3840x2560) -> search-result.png

States the purpose in one line and shows the real Home screen, per Apple's
"state the obvious" and "showcase the firsthand experience" guidance.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from render_header import EMERALD, FOREST, MINT, font, radial

HERE = Path(__file__).parent
SCREEN = HERE.parent / "app-store-screenshots/source-captures/home.png"
ICON = HERE.parents[1] / "AdVoid/Assets.xcassets/AppIcon.appiconset/icon.png"
W, H = 3840, 2560


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return m


def phone(screen_w):
    shot = Image.open(SCREEN).convert("RGB")
    shot = shot.resize((screen_w, int(shot.height * screen_w / shot.width)), Image.LANCZOS)
    bezel = int(screen_w * 0.035)
    fw, fh = shot.width + 2 * bezel, shot.height + 2 * bezel
    r_out = int(screen_w * 0.155)
    body = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, fw - 1, fh - 1), radius=r_out, fill=(28, 30, 30, 255), outline=(96, 112, 104, 255), width=4)
    d.rounded_rectangle((5, 5, fw - 6, fh - 6), radius=r_out - 5, fill=(8, 8, 9, 255))
    body.paste(shot, (bezel, bezel), rounded_mask(shot.size, r_out - bezel))
    # Dynamic Island
    iw, ih = int(screen_w * 0.30), int(screen_w * 0.088)
    ix, iy = fw // 2 - iw // 2, bezel + int(screen_w * 0.03)
    d.rounded_rectangle((ix, iy, ix + iw, iy + ih), radius=ih // 2, fill=(0, 0, 0, 255))
    return body


def main():
    a = np.zeros((H, W, 3)) + FOREST
    a += radial(W, H, W * 0.73, H * 0.45, 1700, (22, 120, 70), 2.0)
    a += radial(W, H, W * 0.73, H * 0.42, 800, (30, 150, 85), 2.4)
    img = Image.fromarray(np.clip(a, 0, 255).astype("uint8")).convert("RGBA")

    # phone, running off the bottom edge
    ph = phone(1240)
    px, py = int(W * 0.73 - ph.width / 2), 250
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((px + 10, py + 50, px + ph.width - 10, py + ph.height + 50),
                                              radius=190, fill=(0, 10, 5, 170))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(60)))
    img.alpha_composite(ph, (px, py))

    d = ImageDraw.Draw(img)
    left = 300
    # icon + wordmark
    icon = Image.open(ICON).convert("RGBA").resize((200, 200), Image.LANCZOS)
    img.paste(icon, (left, 560), rounded_mask(icon.size, 45))
    d.text((left + 250, 660), "AdVoid", font=font(120, "Bold"), fill="white", anchor="lm")

    head = font(250, "Heavy")
    y = 930
    for line in ("Block ads", "and trackers."):
        d.text((left - 8, y), line, font=head, fill="white")
        y += 280
    sub = font(112, "Medium")
    y += 90
    for line in ("Works across your apps.", "Stays on your iPhone."):
        d.text((left, y), line, font=sub, fill=MINT + (230,))
        y += 140

    img.convert("RGB").save(HERE / "search-result.png", optimize=True)


if __name__ == "__main__":
    main()

"""Renders the three-image App Store set from the real app captures.

    python render_set3.py

Writes 3-screenshots-condensed/0N-*.png (1260x2736 masters) plus the
iphone-1242x2688/ (6.5"), iphone-1206x2622/ (6.1"/6.3") and ipad-2048x2732/ exports. Every element is drawn here,
so text and edges stay sharp at any size. Copy comes from
design-notes/sets-content.json (the n=3 set); screens from source-captures/.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
OUT = HERE / "3-screenshots-condensed"
CAPTURES = HERE / "source-captures"
SS = 3  # ImageDraw doesn't antialias shapes; the phone frame is drawn at SS x and scaled down

SIZES = [("", 1260, 2736), ("iphone-1242x2688", 1242, 2688), ("iphone-1206x2622", 1206, 2622),
         ("ipad-2048x2732", 2048, 2732)]

DARK = dict(bg_top=(4, 40, 29), bg_bottom=(2, 22, 15), glow=(38, 190, 92), ink=(255, 255, 255),
            sub=(214, 240, 224), foot=(232, 246, 237))
LIGHT = dict(bg_top=(240, 249, 243), bg_bottom=(232, 245, 236), glow=(204, 238, 214), ink=(8, 40, 29),
             sub=(44, 84, 67), foot=(56, 96, 80))


def font(size, weight=400, opsz=None):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", int(round(size)))
    # axes: width, optical size, grade, weight
    f.set_variation_by_axes([100, opsz or min(96, max(17, size / 3)), 400, weight])
    return f


def stats_capture():
    """The Stats capture predates the Safari removal; redraw its fourth tile as the app shows it now
    (StatsView: "Blocked today"). Font sizes and the label grey were matched against the other tiles."""
    img = Image.open(CAPTURES / "stats.png").convert("RGB")
    d = ImageDraw.Draw(img)
    d.rectangle((645, 800, 1130, 950), fill=(255, 255, 255))
    d.text((657, 868), "122", font=font(65, 700, 22), fill=(0, 0, 0), anchor="ls")
    d.text((656, 932), "Blocked today", font=font(38, 450, 13), fill=(127, 127, 127), anchor="ls")
    return img


def screen(name):
    return stats_capture() if name == "stats" else Image.open(CAPTURES / f"{name}.png").convert("RGB")


def phone(shot, width):
    """An iPhone 16 Pro style frame around a 1206x2622 capture, `width` px wide including the frame."""
    s = SS
    sw, sh = shot.size
    bezel = 0.042 * sw                  # black border around the screen
    rim = 0.012 * sw                    # titanium edge
    fw, fh = sw + 2 * (bezel + rim), sh + 2 * (bezel + rim)
    k = width / fw                      # final px per capture px
    big = Image.new("RGBA", (int(fw * k * s) + 2 * int(0.02 * width * s), int(fh * k * s)), (0, 0, 0, 0))
    ox = int(0.02 * width * s)          # room for the side buttons
    W, H = int(fw * k * s), int(fh * k * s)
    u = k * s                           # capture px -> supersampled px
    d = ImageDraw.Draw(big)
    r_screen = 0.137 * sw
    # side buttons
    btn = (58, 58, 62, 255)
    bw = 0.012 * W
    for right, y0, y1 in [(False, 0.185, 0.215), (False, 0.245, 0.305), (False, 0.325, 0.385), (True, 0.27, 0.37)]:
        bx = ox + W - bw * 0.4 if right else ox - bw * 0.6
        d.rounded_rectangle((bx, y0 * H, bx + bw, y1 * H), radius=bw / 2, fill=btn)
    # body: rim then bezel
    d.rounded_rectangle((ox, 0, ox + W - 1, H - 1), radius=(r_screen + bezel + rim) * u, fill=(92, 92, 98, 255))
    d.rounded_rectangle((ox + rim * u * 0.5, rim * u * 0.5, ox + W - 1 - rim * u * 0.5, H - 1 - rim * u * 0.5),
                        radius=(r_screen + bezel + rim * 0.5) * u, fill=(44, 44, 48, 255))
    d.rounded_rectangle((ox + rim * u, rim * u, ox + W - 1 - rim * u, H - 1 - rim * u),
                        radius=(r_screen + bezel) * u, fill=(10, 10, 11, 255))
    # screen
    sx, sy = ox + (rim + bezel) * u, (rim + bezel) * u
    scr = shot.resize((int(sw * u), int(sh * u)), Image.LANCZOS)
    mask = Image.new("L", scr.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, scr.width - 1, scr.height - 1), radius=r_screen * u, fill=255)
    big.paste(scr, (int(sx), int(sy)), mask)
    # Dynamic Island (126 x 37 pt at 11 pt from the top on a 402 pt wide screen)
    iw, ih, it = 0.313 * sw, 0.0423 * sh, 0.0126 * sh
    cx = sx + sw * u / 2
    d.rounded_rectangle((cx - iw * u / 2, sy + it * u, cx + iw * u / 2, sy + (it + ih) * u), radius=ih * u / 2,
                        fill=(0, 0, 0, 255))
    small = big.convert("RGBa").resize((big.width // s, big.height // s), Image.LANCZOS).convert("RGBA")
    return small, ox // s


def shadow(sprite, blur, alpha, offset):
    a = sprite.getchannel("A").point(lambda v: v * alpha)
    pad = int(blur * 3)
    sh = Image.new("L", (sprite.width + 2 * pad, sprite.height + 2 * pad), 0)
    sh.paste(a, (pad, pad))
    return sh.filter(ImageFilter.GaussianBlur(blur)), pad - offset[0], pad - offset[1]


def place(canvas, sprite, x, y, dark):
    """Composite a phone with a soft drop shadow, top-left at (x, y)."""
    w = sprite.width
    m, px, py = shadow(sprite, w * 0.035, 0.55 if dark else 0.28, (0, -int(w * 0.03)))
    color = (0, 10, 6) if dark else (20, 70, 45)
    canvas.paste(Image.new("RGB", m.size, color), (int(x - px), int(y - py)), m)
    canvas.paste(sprite, (int(x), int(y)), sprite)


def halo(canvas, sprite, x, y):
    """The bright green light around the phone on the dark slide."""
    w = sprite.width
    for blur, alpha in [(w * 0.09, 1.0), (w * 0.03, 0.8)]:
        m, px, py = shadow(sprite, blur, alpha, (0, 0))
        canvas.paste(Image.new("RGB", m.size, (52, 214, 104)), (int(x - px), int(y - py)), m)


def background(W, H, pal):
    t = np.linspace(0, 1, H)[:, None, None]
    a = np.array(pal["bg_top"], float) * (1 - t) + np.array(pal["bg_bottom"], float) * t
    return np.repeat(a, W, axis=1)


def add_glow(a, cx, cy, rx, ry, color, strength, power=2.0):
    H, W = a.shape[:2]
    y, x = np.ogrid[:H, :W]
    d = np.sqrt(((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2)
    g = (np.clip(1 - d, 0, 1) ** power * strength)[..., None]
    return a * (1 - g) + np.array(color, float) * g


def fit(text, max_w, size, weight, min_size=10):
    """Largest size <= `size` at which every line of `text` fits in `max_w`."""
    while size > min_size:
        f = font(size, weight)
        if max(f.getlength(line) for line in text.split("\n")) <= max_w:
            return f
        size -= 1
    return font(min_size, weight)


def draw_lines(d, text, f, x, y, fill, leading, align):
    for line in text.split("\n"):
        lx = x - f.getlength(line) / 2 if align == "center" else x
        d.text((lx, y), line, font=f, fill=fill, anchor="ls")
        y += leading
    return y


def render(item, W, H):
    ipad = W / H > 0.6
    pal = DARK if item["dark"] else LIGHT
    align = "center" if ipad else "left"
    margin = 0.075 * W
    tx = W / 2 if ipad else margin
    text_w = (0.78 if ipad else 0.85) * W

    # copy
    f_mark = font(W * (0.032 if ipad else 0.052), 700)
    f_title = fit(item["title"], text_w, W * (0.085 if ipad else 0.125), 800)
    f_sub = fit(item["sub"], text_w, W * (0.027 if ipad else 0.0435), 400)
    f_foot = font(W * (0.022 if ipad else 0.037), 400)

    top = H * (0.04 if ipad else 0.035)
    mark_base = top + f_mark.size * 0.8
    title_base = mark_base + f_title.size * (1.35 if ipad else 1.45)
    title_lead = f_title.size * 1.0
    n_title = item["title"].count("\n") + 1
    sub_base = title_base + title_lead * (n_title - 1) + f_sub.size * 2.0
    sub_lead = f_sub.size * 1.3
    n_sub = item["sub"].count("\n") + 1
    text_bottom = sub_base + sub_lead * (n_sub - 1)
    foot_base = H * 0.965

    # phones fill the space between the copy and the footer
    shots = [screen(n) for n in item["screen"]]
    ratio = 2622 / 1206 * 1.004
    avail_top = text_bottom + H * 0.04
    avail_bottom = foot_base - f_foot.size * 1.9
    avail_h = avail_bottom - avail_top
    if len(shots) == 1:
        pw = min(avail_h / ratio, W * (0.70 if not ipad else 0.46))
        layout = [(W / 2 - pw / 2, avail_top + (avail_h - pw * ratio) / 2, pw)]
    else:
        pw = min(avail_h / (ratio * 1.1), W * (0.54 if not ipad else 0.38))
        span = pw * 1.82
        x0 = W / 2 - span / 2
        y0 = avail_top + (avail_h - pw * ratio * 1.1) / 2
        layout = [(x0, y0, pw * 0.94),
                  (x0 + span - pw, y0 + pw * ratio * 0.1, pw)]

    a = background(W, H, pal)
    cx = sum(x + w / 2 for x, _, w in layout) / len(layout)
    cy = sum(y + w * ratio / 2 for _, y, w in layout) / len(layout)
    if item["dark"]:
        a = add_glow(a, cx, cy, W * (0.75 if not ipad else 0.5), H * 0.42, pal["glow"], 0.85, 2.2)
        a = add_glow(a, cx, cy, W * 0.45, H * 0.3, (60, 220, 115), 0.5, 2.5)
    else:
        a = add_glow(a, cx + W * 0.1, cy, W * (0.66 if not ipad else 0.44), H * 0.33, pal["glow"], 1.0, 0.35)
    canvas = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))

    for (x, y, w), shot in zip(layout, shots):
        sprite, ox = phone(shot, w)
        if item["dark"]:
            halo(canvas, sprite, x - ox, y)
        place(canvas, sprite, x - ox, y, item["dark"])

    d = ImageDraw.Draw(canvas)
    draw_lines(d, "AdVoid", f_mark, tx, mark_base, pal["ink"], 0, align)
    draw_lines(d, item["title"], f_title, tx - (0 if ipad else f_title.size * 0.04), title_base, pal["ink"],
               title_lead, align)
    draw_lines(d, item["sub"], f_sub, tx, sub_base, pal["sub"], sub_lead, align)
    draw_lines(d, item["foot"], f_foot, W / 2, foot_base, pal["foot"], 0, "center")
    return canvas


def main():
    sets = json.loads((HERE / "design-notes/sets-content.json").read_text())
    items = next(s for s in sets if s["n"] == 3)["items"]
    for folder, W, H in SIZES:
        (OUT / folder).mkdir(exist_ok=True)
        for i, item in enumerate(items, 1):
            path = OUT / folder / f"{i:02d}-{item['slug']}.png"
            render(item, W, H).save(path, optimize=True)
            print(path.relative_to(HERE))


if __name__ == "__main__":
    main()

"""Renders the consumer-focused AdVoid product page header (21:9, 3840x1646).

    python render_header_clean.py still   -> header-clean.png (poster: the blast mid-way)
    python render_header_clean.py video   -> header-clean.mp4 (10 s seamless loop, 30 fps, H.264)
    python render_header_clean.py preview -> header-clean-preview.png (quarter size contact frames)

One phone shows a news page. Loud ads pile onto it and spill out around it while the
scene goes dull, then the AdVoid shield appears and a green shockwave bursts every ad
away, leaving a clean page on a bright green background. Two such cycles per LOOP;
each cycle starts and ends clean, so the last frame flows into the first.
"""
import math, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
ICON = HERE.parents[1] / "AdVoid/Assets.xcassets/AppIcon.appiconset/icon.png"
W, H = 3840, 1646
FPS, LOOP = 30, 10.0
CX, CY = W // 2, H // 2

FOREST = (4, 36, 27)
EMERALD = (50, 209, 109)
INK = (28, 32, 38)
GRAY = (206, 210, 216)
LIGHT = (238, 240, 243)

SW, SH = 600, 1300            # phone screen, in center-phone pixels
BEZEL = 22
SS = 3                        # sprites are drawn at SS x and scaled down for antialiasing
M = 32                        # page side margin
TOP = 168                     # content starts below status bar and nav bar

CYCLE = 5.0                   # two cycles per LOOP
SHIELD_AT = 2.0               # shield appears
BLAST_AT = 2.3                # shockwave leaves the shield
RING_SPEED = 2600             # px per second
SHIELD_OUT = 2.95
PHONE_SCALE = 1.12


def font(size, weight="Regular"):
    f = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", int(size))
    f.set_variation_by_name(weight)
    return f


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def back_out(x):
    x = min(max(x, 0.0), 1.0)
    c = 1.7
    return 1 + (c + 1) * (x - 1) ** 3 + c * (x - 1) ** 2


def downsample(img):
    """Scale a sprite drawn at SS x back down, in premultiplied alpha so edges don't darken."""
    return img.convert("RGBa").resize((img.width // SS, img.height // SS), Image.LANCZOS).convert("RGBA")


def gradient(w, h, c0, c1, diagonal=True):
    y, x = np.mgrid[:h, :w]
    t = (x / max(w, 1) + y / max(h, 1)) / 2 if diagonal else y / max(h, 1)
    a = np.array(c0, float) * (1 - t[..., None]) + np.array(c1, float) * t[..., None]
    return Image.fromarray(a.astype("uint8")).convert("RGBA")


def rounded_paste(dst, src, xy, radius):
    mask = Image.new("L", src.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, src.width - 1, src.height - 1), radius=radius, fill=255)
    dst.paste(src, xy, mask)


def sprite(h, draw):
    """A full-width block of the page: draw(img, d, s, w, h) at SS scale."""
    s = SS
    img = Image.new("RGBA", (SW * s, h * s), (0, 0, 0, 0))
    draw(img, ImageDraw.Draw(img), s, SW * s, h * s)
    return downsample(img)


# ---------------------------------------------------------------- page content

def bars(d, s, x, y, widths, h=18, gap=16, color=GRAY):
    for i, w in enumerate(widths):
        yy = y + i * (h + gap) * s
        d.rounded_rectangle((x, yy, x + w * s, yy + h * s), radius=h * s // 2, fill=color)


def picture(w, h, palette, seed):
    """A soft illustrated photo placeholder: sky gradient, sun, hills."""
    rng = np.random.default_rng(seed)
    img = gradient(w, h, palette[0], palette[1], diagonal=False)
    d = ImageDraw.Draw(img)
    r = h * 0.12
    sx, sy = w * rng.uniform(0.6, 0.8), h * 0.3
    d.ellipse((sx - r, sy - r, sx + r, sy + r), fill=palette[2])
    for k, col in enumerate((palette[3], palette[4])):
        pts = [(0, h)]
        base = h * (0.62 + 0.14 * k)
        ph = rng.uniform(0, 6)
        for i in range(0, 41):
            px = w * i / 40
            pts.append((px, base - h * 0.1 * math.sin(px / w * 5 + ph)))
        pts.append((w, h))
        d.polygon(pts, fill=col)
    return img


PALETTES = [
    [(190, 222, 245), (232, 242, 250), (255, 214, 140), (150, 196, 170), (110, 160, 135)],
    [(250, 220, 200), (255, 240, 228), (255, 190, 120), (214, 170, 150), (180, 130, 120)],
    [(205, 215, 240), (235, 238, 250), (255, 236, 170), (160, 175, 210), (120, 135, 180)],
    [(214, 238, 224), (240, 248, 242), (255, 225, 150), (150, 200, 160), (95, 150, 115)],
]


def title_block(seed):
    rng = np.random.default_rng(seed)
    def draw(img, d, s, w, h):
        bars(d, s, M * s, 18 * s, [int(rng.uniform(470, 530)), int(rng.uniform(260, 380))], h=30, gap=14, color=INK)
        bars(d, s, M * s, 116 * s, [150], h=14, color=(160, 166, 174))
    return sprite(156, draw)


def para_block(seed, lines=4):
    rng = np.random.default_rng(seed)
    def draw(img, d, s, w, h):
        ws = [int(rng.uniform(480, 536)) for _ in range(lines - 1)] + [int(rng.uniform(220, 380))]
        bars(d, s, M * s, 14 * s, ws, h=16, gap=18)
    return sprite(14 + lines * 34 + 16, draw)


def hero_block(seed, h=310):
    def draw(img, d, s, w, hh):
        pic = picture(w - 2 * M * s, hh - 28 * s, PALETTES[seed % len(PALETTES)], seed)
        rounded_paste(img, pic, (M * s, 14 * s), 26 * s)
    return sprite(h, draw)


def post_block(seed):
    rng = np.random.default_rng(seed)
    def draw(img, d, s, w, h):
        av = 64 * s
        d.ellipse((M * s, 18 * s, M * s + av, 18 * s + av), fill=tuple(int(c) for c in rng.uniform(150, 220, 3)))
        bars(d, s, M * s + av + 18 * s, 26 * s, [int(rng.uniform(140, 220)), 100], h=16, gap=14,
             color=(120, 126, 134))
        pic = picture(w - 2 * M * s, 330 * s, PALETTES[seed % len(PALETTES)], seed)
        rounded_paste(img, pic, (M * s, 102 * s), 22 * s)
        y = 452 * s
        for i in range(3):
            x = M * s + i * 70 * s
            d.ellipse((x, y, x + 34 * s, y + 34 * s), outline=(150, 156, 164), width=4 * s)
    return sprite(510, draw)


def row_block(seed):
    rng = np.random.default_rng(seed)
    def draw(img, d, s, w, h):
        th = 112 * s
        pic = picture(th, th, PALETTES[seed % len(PALETTES)], seed)
        rounded_paste(img, pic, (M * s, 14 * s), 18 * s)
        x = M * s + th + 24 * s
        bars(d, s, x, 26 * s, [int(rng.uniform(240, 330))], h=22, color=INK)
        bars(d, s, x, 66 * s, [int(rng.uniform(260, 330)), int(rng.uniform(120, 200))], h=14, gap=12)
    return sprite(140, draw)


def divider_block():
    def draw(img, d, s, w, h):
        d.rectangle((M * s, h // 2 - s, w - M * s, h // 2 + s), fill=(228, 230, 234))
    return sprite(20, draw)


# ---------------------------------------------------------------- the ads

AD_COLORS = [
    ((255, 94, 58), (255, 42, 132)),     # orange -> pink
    ((124, 58, 255), (40, 120, 255)),    # violet -> blue
    ((255, 196, 0), (255, 110, 20)),     # yellow -> orange
    ((0, 196, 180), (30, 110, 255)),     # teal -> blue
]


def ad_badge(d, s, x, y, scale=1.0):
    bw, bh = int(54 * s * scale), int(34 * s * scale)
    d.rounded_rectangle((x, y, x + bw, y + bh), radius=int(8 * s * scale), fill=(255, 214, 0))
    d.text((x + bw / 2, y + bh / 2), "Ad", font=font(22 * s * scale, "Bold"), fill=(50, 38, 0), anchor="mm")


def close_x(d, s, cx, cy, r, bg=(0, 0, 0, 90)):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=bg)
    k = r * 0.42
    for a, b in (((cx - k, cy - k), (cx + k, cy + k)), ((cx - k, cy + k), (cx + k, cy - k))):
        d.line((a, b), fill="white", width=int(r * 0.22))


def cta(d, s, x, y, w, h, text, fg):
    d.rounded_rectangle((x, y, x + w, y + h), radius=h // 2, fill="white")
    d.text((x + w / 2, y + h / 2), text, font=font(h * 0.46, "Bold"), fill=fg, anchor="mm")


def ad_banner(k):
    c0, c1 = AD_COLORS[k % len(AD_COLORS)]
    def draw(img, d, s, w, h):
        bw, bh = w - 2 * M * s, h - 24 * s
        rounded_paste(img, gradient(bw, bh, c0, c1), (M * s, 12 * s), 20 * s)
        d = ImageDraw.Draw(img)
        ix = M * s + 20 * s
        d.rounded_rectangle((ix, 30 * s, ix + 96 * s, 126 * s), radius=22 * s, fill=(255, 255, 255, 235))
        d.text((ix + 48 * s, 78 * s), "★", font=font(56 * s, "Bold"), fill=c0, anchor="mm")
        bars(d, s, ix + 118 * s, 44 * s, [170, 120], h=18, gap=16, color=(255, 255, 255, 210))
        cta(d, s, w - M * s - 168 * s, 54 * s, 140 * s, 54 * s, "Install", c1)
        ad_badge(d, s, M * s + 10 * s, 20 * s, 0.8)
    return sprite(150, draw)


def ad_box(k):
    c0, c1 = AD_COLORS[k % len(AD_COLORS)]
    def draw(img, d, s, w, h):
        bw, bh = w - 2 * M * s, h - 28 * s
        rounded_paste(img, gradient(bw, bh, c0, c1), (M * s, 14 * s), 26 * s)
        d = ImageDraw.Draw(img)
        # big burst shape so it reads as a flashy promo
        cx, cy, r = w * 0.5, 150 * s, 92 * s
        pts = [(cx + (r if i % 2 == 0 else r * 0.62) * math.cos(i * math.pi / 8),
                cy + (r if i % 2 == 0 else r * 0.62) * math.sin(i * math.pi / 8)) for i in range(16)]
        d.polygon(pts, fill=(255, 236, 80))
        d.text((cx, cy), "%", font=font(92 * s, "Heavy"), fill=c1, anchor="mm")
        bars(d, s, int(w * 0.5 - 170 * s), 268 * s, [340], h=22, color=(255, 255, 255, 230))
        cta(d, s, int(w * 0.5 - 130 * s), 318 * s, 260 * s, 62 * s, "Shop now", c1)
        ad_badge(d, s, M * s + 16 * s, 30 * s)
        close_x(d, s, w - M * s - 34 * s, 46 * s, 20 * s)
    return sprite(420, draw)


def ad_post(k):
    c0, c1 = AD_COLORS[k % len(AD_COLORS)]
    def draw(img, d, s, w, h):
        av = 64 * s
        rounded_paste(img, gradient(av, av, c0, c1), (M * s, 18 * s), av // 2)
        d = ImageDraw.Draw(img)
        bars(d, s, M * s + av + 18 * s, 26 * s, [180], h=16, color=(120, 126, 134))
        d.text((M * s + av + 18 * s, 64 * s), "Sponsored", font=font(22 * s, "Semibold"), fill=(150, 156, 164), anchor="lm")
        pw, ph = w - 2 * M * s, 300 * s
        rounded_paste(img, gradient(pw, ph, c0, c1), (M * s, 102 * s), 22 * s)
        d = ImageDraw.Draw(img)
        cx, cy = w * 0.5, 102 * s + ph * 0.45
        d.rounded_rectangle((cx - 80 * s, cy - 80 * s, cx + 80 * s, cy + 80 * s), radius=36 * s, fill=(255, 255, 255, 230))
        d.text((cx, cy), "▶", font=font(80 * s, "Bold"), fill=c1, anchor="mm")
        ad_badge(d, s, M * s + 16 * s, 118 * s)
        by = 102 * s + ph + 16 * s
        d.rounded_rectangle((M * s, by, w - M * s, by + 64 * s), radius=16 * s, fill=(40, 120, 255))
        d.text((w / 2, by + 32 * s), "Play free", font=font(28 * s, "Bold"), fill="white", anchor="mm")
    return sprite(510, draw)


def popup(k):
    """Interstitial: a card over a dimmed page."""
    c0, c1 = AD_COLORS[k % len(AD_COLORS)]
    s = SS
    w, h = 480 * s, 600 * s
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    rounded_paste(img, gradient(w, h, c0, c1), (0, 0), 40 * s)
    d = ImageDraw.Draw(img)
    cx = w / 2
    d.ellipse((cx - 110 * s, 90 * s, cx + 110 * s, 310 * s), fill=(255, 236, 80))
    d.text((cx, 200 * s), "!", font=font(150 * s, "Heavy"), fill=c1, anchor="mm")
    bars(d, s, int(cx - 160 * s), 350 * s, [320, 220], h=26, gap=18, color=(255, 255, 255, 235))
    d.rounded_rectangle((cx - 170 * s, 470 * s, cx + 170 * s, 546 * s), radius=38 * s, fill="white")
    d.text((cx, 508 * s), "Claim now", font=font(34 * s, "Bold"), fill=c1, anchor="mm")
    ad_badge(d, s, 26 * s, 26 * s)
    close_x(d, s, w - 46 * s, 46 * s, 24 * s)
    return downsample(img)


def sticky(k):
    c0, c1 = AD_COLORS[k % len(AD_COLORS)]
    s = SS
    w, h = SW * s, 128 * s
    img = gradient(w, h, c0, c1)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((24 * s, 30 * s, 92 * s, 98 * s), radius=16 * s, fill=(255, 255, 255, 235))
    d.text((58 * s, 64 * s), "$", font=font(44 * s, "Heavy"), fill=c1, anchor="mm")
    bars(d, s, 112 * s, 40 * s, [200, 140], h=16, gap=14, color=(255, 255, 255, 220))
    cta(d, s, w - 190 * s, 36 * s, 150 * s, 56 * s, "Get it", c1)
    ad_badge(d, s, 112 * s, 4 * s, 0.7)
    close_x(d, s, w - 22 * s, 22 * s, 14 * s)
    return downsample(img)


# ---------------------------------------------------------------- pages

def chrome(kind):
    """Status bar and the app's own nav bar, drawn on the white page."""
    s = SS
    img = Image.new("RGBA", (SW * s, TOP * s), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((70 * s, 38 * s), "9:41", font=font(30 * s, "Semibold"), fill=INK, anchor="mm")
    bx = SW * s - 92 * s
    d.rounded_rectangle((bx, 28 * s, bx + 50 * s, 50 * s), radius=7 * s, outline=INK, width=3 * s)
    d.rounded_rectangle((bx + 5 * s, 33 * s, bx + 38 * s, 45 * s), radius=4 * s, fill=INK)
    for i in range(4):
        x = bx - 70 * s + i * 12 * s
        d.rounded_rectangle((x, (46 - 6 * i) * s, x + 8 * s, 50 * s), radius=2 * s, fill=INK)
    y = 112 * s
    if kind == "news":
        d.text((SW * s / 2, y), "The Morning", font=font(40 * s, "Heavy"), fill=INK, anchor="mm")
        for i in range(3):
            d.rounded_rectangle((M * s, y - 14 * s + i * 12 * s, M * s + 34 * s, y - 9 * s + i * 12 * s), radius=2 * s, fill=INK)
    elif kind == "social":
        d.text((M * s, y), "Friends", font=font(42 * s, "Bold"), fill=INK, anchor="lm")
        for i in range(2):
            x = SW * s - M * s - 40 * s - i * 64 * s
            d.ellipse((x, y - 20 * s, x + 40 * s, y + 20 * s), outline=INK, width=4 * s)
    else:
        d.text((M * s, y), "Recipes", font=font(42 * s, "Bold"), fill=INK, anchor="lm")
        x = SW * s - M * s - 40 * s
        d.ellipse((x, y - 20 * s, x + 32 * s, y + 12 * s), outline=INK, width=4 * s)
        d.line((x + 28 * s, y + 8 * s, x + 42 * s, y + 22 * s), fill=INK, width=5 * s)
    d.rectangle((0, TOP * s - 2 * s, SW * s, TOP * s), fill=(232, 234, 238))
    return downsample(img)



def news_page(ads):
    """Article blocks with ad slots between them: (sprite, ad pop-in time or None)."""
    return [(ad_banner(ads), 0.25), (title_block(1), None), (hero_block(1), None),
            (ad_post(ads + 1), 0.7), (para_block(2), None), (ad_box(ads + 2), 1.0),
            (para_block(3, 5), None), (hero_block(4, 280), None),
            (para_block(5), None), (para_block(6), None)]


def blast_time(x, y):
    """When the shockwave reaches canvas point (x, y)."""
    return BLAST_AT + math.hypot(x - CX, y - CY) / RING_SPEED


def presence(u, t_in, t_out):
    """Ad state: (height factor, sprite scale, alpha, burst progress or None)."""
    if u < t_in:
        return 0.0, 0.6, 0.0, None
    grow = ease((u - t_in) / 0.3)
    pop = back_out((u - t_in) / 0.35)
    if u < t_out:
        return grow, 0.6 + 0.4 * pop, min(1, (u - t_in) / 0.12), None
    q = (u - t_out) / 0.16
    return 1 - ease((u - t_out - 0.05) / 0.35), 1 + 0.25 * ease(q), max(0, 1 - q), u - t_out


class Particles:
    """Confetti in an ad's colors, flying out from where it burst."""
    def __init__(self, colors, seed, n=22, spread=1.0):
        rng = np.random.default_rng(seed)
        self.ang = rng.uniform(0, 2 * math.pi, n)
        self.speed = rng.uniform(250, 700, n) * spread
        self.size = rng.uniform(8, 20, n) * spread
        self.col = [colors[i % len(colors)] for i in range(n)]

    def draw(self, d, x, y, dt, w=0, h=0):
        if not 0 <= dt < 0.8:
            return
        q = dt / 0.8
        for a, sp, sz, c in zip(self.ang, self.speed, self.size, self.col):
            dist = sp * 0.8 * (1 - (1 - q) ** 2.5)
            px = x + math.cos(a) * (dist + w * 0.35)
            py = y + math.sin(a) * (dist + h * 0.35) + 260 * q * q
            r = sz * (1 - q * 0.6)
            d.rounded_rectangle((px - r, py - r, px + r, py + r), radius=r * 0.3, fill=c + (int(255 * (1 - q) ** 1.2),))


def flashed(sp, amount):
    """Wash the sprite toward white (the moment the shockwave hits)."""
    if amount <= 0:
        return sp
    wash = Image.new("RGBA", sp.size, (255, 255, 255, 0))
    wash.putalpha(sp.getchannel("A").point(lambda v: int(v * amount)))
    out = sp.copy()
    out.alpha_composite(wash)
    return out


def scaled(sp, sc, alpha=1.0, rot=0.0):
    if abs(sc - 1) > 0.002:
        sp = sp.convert("RGBa").resize((max(1, int(sp.width * sc)), max(1, int(sp.height * sc))),
                                       Image.BICUBIC).convert("RGBA")
    if rot:
        sp = sp.rotate(rot, Image.BICUBIC, expand=True)
    if alpha < 0.999:
        sp = sp.copy()
        sp.putalpha(sp.getchannel("A").point(lambda v: int(v * alpha)))
    return sp


def render_page(c, u):
    """The phone screen at u seconds into the cycle."""
    img = Image.new("RGBA", (SW, SH), (255, 255, 255, 255))
    fx = ImageDraw.Draw(img)
    screen_x0 = CX - SW * PHONE_SCALE / 2
    screen_y0 = CY - SH * PHONE_SCALE / 2
    y = TOP
    bursts = []
    for i, (sp, t_in) in enumerate(c["page"]):
        if t_in is None:
            img.alpha_composite(sp, (0, int(y)))
            y += sp.height
        else:
            h = sp.height
            t_out = blast_time(CX, screen_y0 + (y + h / 2) * PHONE_SCALE)
            hf, sc, a, burst = presence(u, t_in, t_out)
            if a > 0:
                s2 = scaled(flashed(sp, 0.8 * (1 - (burst or 0) / 0.3) if burst is not None else 0), sc, a)
                img.alpha_composite(s2, ((SW - s2.width) // 2, int(y + (h * hf - s2.height) / 2)))
            if burst is not None:
                bursts.append((c["parts"][i], y + h * hf / 2, burst, h))
            y += h * hf
        if y > SH:
            break
    img.alpha_composite(c["chrome"], (0, 0))

    # sticky banner rises from the bottom; popup lands on top of everything
    st = c["sticky"]
    hf, sc, a, burst = presence(u, 0.5, blast_time(CX, screen_y0 + (SH - 60) * PHONE_SCALE))
    if a > 0:
        s2 = scaled(flashed(st, 0.8 if burst is not None else 0), 1.0, a)
        img.alpha_composite(s2, (0, int(SH - st.height * hf)))
    if burst is not None:
        bursts.append((c["parts"]["sticky"], SH - 64, burst, 128))

    pp = c["popup"]
    hf, sc, a, burst = presence(u, 1.3, blast_time(CX, CY))
    if a > 0:
        img.alpha_composite(Image.new("RGBA", (SW, SH), (0, 0, 0, int(130 * a * (hf if burst is not None else 1)))))
        s2 = scaled(flashed(pp, 0.8 if burst is not None else 0), sc, a)
        img.alpha_composite(s2, ((SW - s2.width) // 2, int(SH * 0.5 - s2.height / 2)))
    if burst is not None:
        bursts.append((c["parts"]["popup"], SH * 0.5, burst, 600))

    for parts, py, dt, h in bursts:
        parts.draw(fx, SW / 2, py, dt, SW * 0.6, h * 0.6)
    return img


# Ad cards that spill out around the phone: (maker, color index, x, y, scale, rotation, pop-in time)
OUTSIDE = [
    (ad_box, 0, 560, 400, 0.85, 5, 0.35),
    (popup, 1, 1200, 560, 0.78, -6, 1.15),
    (ad_banner, 2, 620, 900, 1.0, -3, 0.6),
    (ad_post, 3, 1130, 1230, 0.72, 4, 0.9),
    (sticky, 0, 470, 1300, 0.9, -4, 1.45),
    (ad_post, 1, 2720, 430, 0.75, -4, 0.5),
    (ad_box, 2, 3330, 520, 0.8, 6, 1.05),
    (popup, 3, 2740, 1130, 0.72, 5, 1.4),
    (ad_banner, 0, 3270, 1000, 0.95, 3, 0.8),
    (sticky, 1, 3330, 1340, 0.9, -5, 1.6),
]


def cycle_assets(n):
    """Each cycle gets its own article and its own ad colors and layout (mirrored)."""
    shift = 2 * n
    outside = []
    for i, (mk, k, x, y, sc, rot, t_in) in enumerate(OUTSIDE):
        if n:
            x, rot = W - x, -rot
        sp = scaled(mk(k + shift), sc * 1.15)
        outside.append(dict(sp=sp, x=x, y=y, rot=rot, t_in=t_in + 0.07 * n,
                            parts=Particles(AD_COLORS[(k + shift) % 4], 50 * n + i, 30, 1.3),
                            wob=np.random.default_rng(90 + i + 20 * n).uniform(0, 6)))
    page_blocks = news_page(1 + 2 * n)
    parts = {i: Particles(AD_COLORS[(i + n) % 4], 300 + 10 * n + i) for i in range(len(page_blocks))}
    parts["sticky"] = Particles(AD_COLORS[(2 + n) % 4], 400 + n)
    parts["popup"] = Particles(AD_COLORS[(3 + n) % 4], 500 + n, 30)
    return dict(page=page_blocks, outside=outside, parts=parts,
                popup=popup(3 + shift), sticky=sticky(1 + shift), chrome=chrome("news"))


def orb(radius):
    """The green power button from the Home screen, with the shield, and its glow."""
    pad = int(radius * 1.6)
    size = 2 * (radius + pad)
    c = size // 2
    y, x = np.ogrid[:size, :size]
    d = np.sqrt((x - c) ** 2 + (y - c) ** 2)
    out = np.zeros((size, size, 4))
    out[..., :3] = EMERALD
    out[..., 3] = np.clip(1 - d / (radius + pad), 0, 1) ** 1.8 * 170
    t = np.clip((y - (c - radius)) / (2 * radius), 0, 1)
    grad = np.array((98, 226, 136)) * (1 - t[..., None]) + np.array((36, 178, 92)) * t[..., None]
    inside = d <= radius
    out[..., :3] = np.where(inside[..., None], grad, out[..., :3])
    out[..., 3] = np.where(inside, 255, out[..., 3])
    img = Image.fromarray(np.clip(out, 0, 255).astype("uint8"), "RGBA")
    icon = np.asarray(Image.open(ICON).convert("RGB")).astype(int)
    m = Image.fromarray((icon.min(2) > 200).astype("uint8") * 255)
    m = m.crop(m.getbbox())
    sh_h = int(radius * 0.95)
    m = m.resize((int(sh_h * m.width / m.height), sh_h), Image.LANCZOS)
    img.paste(Image.new("RGBA", m.size, "white"), (c - m.width // 2, c - m.height // 2), m)
    return img


# ---------------------------------------------------------------- scene

def background(dull):
    y, x = np.ogrid[:H, :W]
    base = np.array((26, 28, 32) if dull else FOREST, float)
    glow = [((1700, (40, 40, 44), 2.2), (900, (30, 30, 34), 2.6)), ((1700, (22, 130, 74), 2.0), (900, (40, 170, 96), 2.4))][not dull]
    a = np.zeros((H, W, 3)) + base
    for r, col, pw in glow:
        d = np.sqrt(((x - CX) / 1.4) ** 2 + (y - CY) ** 2) / r
        a += (np.clip(1 - d, 0, 1) ** pw)[..., None] * np.array(col, float)
    xx = np.linspace(-1, 1, W)[None, :, None]
    a *= 1 - 0.35 * np.abs(xx) ** 3
    return Image.fromarray(np.clip(a, 0, 255).astype("uint8")).convert("RGBA")


def phone_frame():
    """Bezel, island and drop shadow around a screen, scaled to PHONE_SCALE."""
    s = SS
    fw, fh = SW + 2 * BEZEL, SH + 2 * BEZEL
    pad = 120
    img = Image.new("RGBA", ((fw + 2 * pad) * s, (fh + 2 * pad) * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    o = pad * s
    d.rounded_rectangle((o, o, o + fw * s, o + fh * s), radius=96 * s, fill=(18, 20, 22, 255),
                        outline=(70, 76, 80, 255), width=4 * s)
    frame = downsample(img)
    shadow = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((pad, pad + 30, pad + fw, pad + fh + 30), radius=96, fill=(0, 6, 4, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    shadow.alpha_composite(frame)
    screen_mask = Image.new("L", (SW * s, SH * s), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle((0, 0, SW * s - 1, SH * s - 1), radius=76 * s, fill=255)
    island = Image.new("RGBA", (SW * s, SH * s), (0, 0, 0, 0))
    ImageDraw.Draw(island).rounded_rectangle(((SW / 2 - 92) * s, 18 * s, (SW / 2 + 92) * s, 70 * s), radius=26 * s, fill="black")
    return shadow, screen_mask.resize((SW, SH), Image.LANCZOS), downsample(island), pad


START = 2.62    # poster: the shockwave half way out, ads bursting all around

_cache = {}


def assets():
    if not _cache:
        _cache["clean"] = background(False)
        _cache["dull"] = background(True)
        _cache["frame"] = phone_frame()
        _cache["orb"] = orb(190)
        _cache["cycles"] = [cycle_assets(0), cycle_assets(1)]
    return _cache


def dullness(u):
    """0 = calm green, 1 = cluttered gray; rises with the ads, drops with the shockwave."""
    return ease((u - 0.2) / 1.6) * (1 - ease((u - BLAST_AT) / 0.7))


def frame(t):
    A = assets()
    t %= LOOP
    n = int(t // CYCLE)
    u = t - n * CYCLE
    c = A["cycles"][n]
    img = Image.blend(A["clean"], A["dull"], dullness(u))
    fx = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fxd = ImageDraw.Draw(fx)

    # ads spilling around the phone
    for o in c["outside"]:
        hf, sc, a, burst = presence(u, o["t_in"], blast_time(o["x"], o["y"]))
        if burst is not None:
            o["parts"].draw(fxd, o["x"], o["y"], burst, o["sp"].width * 0.5, o["sp"].height * 0.5)
        if a <= 0:
            continue
        rot = o["rot"] + 1.5 * math.sin(u * 3.1 + o["wob"])
        sp = scaled(flashed(o["sp"], 0.8 if burst is not None else 0), sc, a, rot)
        bob = 10 * math.sin(u * 2.3 + o["wob"])
        img.alpha_composite(sp, (int(o["x"] - sp.width / 2), int(o["y"] + bob - sp.height / 2)))

    # the phone
    shadow, mask, island, pad = A["frame"]
    scr = render_page(c, u)
    scr.alpha_composite(island)
    ph = shadow.copy()
    ph.paste(scr, (pad + BEZEL, pad + BEZEL), mask)
    ph = ph.convert("RGBa").resize((int(ph.width * PHONE_SCALE), int(ph.height * PHONE_SCALE)), Image.LANCZOS).convert("RGBA")
    img.alpha_composite(ph, (CX - ph.width // 2, CY - ph.height // 2))
    img.alpha_composite(fx)

    # shockwave: a bright ring plus a soft wash behind it
    if BLAST_AT <= u < BLAST_AT + 1.2:
        q = (u - BLAST_AT) / 1.2
        r = (u - BLAST_AT) * RING_SPEED
        ring = Image.new("RGBA", (W // 4, H // 4), (0, 0, 0, 0))
        rd = ImageDraw.Draw(ring)
        a = int(255 * (1 - q) ** 1.3)
        rr = r / 4
        for wdt, aa in ((60, 0.3), (22, 0.7), (8, 1.0)):
            rd.ellipse((CX / 4 - rr, CY / 4 - rr, CX / 4 + rr, CY / 4 + rr), outline=(120, 255, 170, int(a * aa)), width=wdt)
        ring = ring.filter(ImageFilter.GaussianBlur(3)).resize((W, H), Image.BILINEAR)
        img.alpha_composite(ring)

    # the shield pops in over the phone, fires, then shrinks away
    if SHIELD_AT <= u < SHIELD_OUT + 0.4:
        sc = back_out((u - SHIELD_AT) / 0.35) * (1 - ease((u - SHIELD_OUT) / 0.4))
        kick = 1 + 0.12 * math.exp(-((u - BLAST_AT) / 0.08) ** 2)
        o = scaled(A["orb"], max(0.02, sc * kick))
        img.alpha_composite(o, (CX - o.width // 2, CY - o.height // 2))
    return img.convert("RGB")


def main():
    mode = next((a for a in sys.argv[1:] if not a.startswith("--")), "still")
    name = "header-clean"
    if mode == "still":
        frame(START).save(HERE / f"{name}.png", optimize=True)
    elif mode == "preview":
        times = [0.3, 1.0, 1.9, 2.25, 2.45, 2.62, 2.75, 3.2, 4.99, 5.01]
        shots = [frame(t).resize((W // 4, H // 4), Image.LANCZOS) for t in times]
        sheet = Image.new("RGB", (W // 4 * 2, H // 4 * 5))
        for i, s in enumerate(shots):
            sheet.paste(s, ((i % 2) * W // 4, (i // 2) * H // 4))
        sheet.save(HERE / f"{name}-preview.png")
    elif mode == "video":
        out = HERE / f"{name}.mp4"
        ff = subprocess.Popen([
            "ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
            "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
            "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "14",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", str(out)], stdin=subprocess.PIPE)
        n = int(FPS * LOOP)
        for f in range(n):
            ff.stdin.write(frame(START + f / FPS).tobytes())
            if f % 30 == 0:
                print(f"frame {f}/{n}", flush=True)
        ff.stdin.close()
        ff.wait()


if __name__ == "__main__":
    main()

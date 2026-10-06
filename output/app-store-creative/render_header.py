"""Renders the AdVoid product page header (21:9, 3840x1646).

    python render_header.py still   -> header.png (first frame, also the video's poster)
    python render_header.py video   -> header.mp4 (10 s seamless loop, 30 fps, H.264)
    python render_header.py preview -> header-preview.png (quarter size contact frames)

Add --dense for the fuller variant (header-dense.png / header-dense.mp4): three depth
layers of pills, faint sponsored cards behind them, and sparks on each absorption.

Ad-domain pills drift in from both edges and are absorbed by the AdVoid shield.
Every motion is periodic in LOOP seconds, so the last frame flows into the first.
"""
import math, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).parent
ICON = HERE.parents[1] / "AdVoid/Assets.xcassets/AppIcon.appiconset/icon.png"
W, H = 3840, 1646
FPS, LOOP = 30, 10.0
CX, CY = W // 2, int(H * 0.47)

FOREST = (4, 36, 27)
EMERALD = (50, 209, 109)
MINT = (220, 246, 230)
RED = (255, 69, 58)

DOMAINS = [
    "securepubads.g.doubleclick.net", "app-measurement.com", "graph.facebook.com",
    "ads.tiktok.com", "googleads.g.doubleclick.net", "api2.branch.io",
    "sdk.iad-01.braze.com", "api.mixpanel.com", "aax.amazon-adsystem.com",
    "t.appsflyer.com", "ads.linkedin.com", "analytics.yahoo.com",
    "adservice.google.com", "pixel.facebook.com", "ads-api.twitter.com", "bat.bing.com",
    # extra names so the dense variant never shows a domain twice
    "ads.yahoo.com", "events.reddit.com", "tr.snapchat.com", "ct.pinterest.com",
    "stats.g.doubleclick.net", "ssl.google-analytics.com", "cdn.segment.com", "api.amplitude.com",
    "sdk.adjust.com", "app.adjust.com", "an.facebook.com", "ads.unity3d.com",
    "googleadservices.com", "pagead2.googlesyndication.com", "ads.mopub.com", "ironsrc.mobi",
    "applovin.com", "inmobi.com", "vungle.com", "chartboost.com",
    "adnxs.com", "criteo.com", "taboola.com", "outbrain.com",
    "scorecardresearch.com", "quantserve.com", "moatads.com", "rubiconproject.com",
]


def font(size, weight="Regular", mono=False):
    f = ImageFont.truetype(f"/System/Library/Fonts/{'SFNSMono' if mono else 'SFNS'}.ttf", int(size))
    if not mono:
        f.set_variation_by_name(weight)
    return f


def radial(w, h, cx, cy, r, color, power=2.0):
    y, x = np.ogrid[:h, :w]
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
    a = np.clip(1 - d, 0, 1) ** power
    return a[..., None] * np.array(color, float)


def background():
    a = np.zeros((H, W, 3)) + FOREST
    a += radial(W, H, CX, CY, 1500, (22, 120, 70), 2.2)
    a += radial(W, H, CX, CY, 700, (30, 150, 85), 2.5)
    # vignette toward the far left and right
    x = np.linspace(-1, 1, W)[None, :, None]
    a *= 1 - 0.35 * np.abs(x) ** 3
    img = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))
    # faint dot grid for texture
    dots = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(dots)
    for gy in range(24, H, 56):
        for gx in range(24, W, 56):
            d.ellipse((gx - 2, gy - 2, gx + 2, gy + 2), fill=255)
    return Image.composite(Image.new("RGB", (W, H), (60, 140, 100)), img, dots.point(lambda v: v * 0.10))


def shield_sprite(size):
    """White shield with the check cut out, taken from the app icon."""
    icon = np.asarray(Image.open(ICON).convert("RGB")).astype(int)
    mask = (icon.min(2) > 200).astype("uint8") * 255
    m = Image.fromarray(mask).crop(Image.fromarray(mask).getbbox())
    m = m.resize((int(size * m.width / m.height), size), Image.LANCZOS)
    s = Image.new("RGBA", m.size, (255, 255, 255, 0))
    s.putalpha(m)
    return s


def orb(radius):
    """The green power button from the Home screen, with its glow."""
    pad = int(radius * 1.6)
    size = 2 * (radius + pad)
    c = size // 2
    glow = radial(size, size, c, c, radius + pad, (1, 1, 1), 1.8)[..., 0]
    out = np.zeros((size, size, 4))
    out[..., :3] = EMERALD
    out[..., 3] = glow * 150
    y, x = np.ogrid[:size, :size]
    inside = np.sqrt((x - c) ** 2 + (y - c) ** 2) <= radius
    t = np.clip((y - (c - radius)) / (2 * radius), 0, 1)
    top, bot = np.array((98, 226, 136)), np.array((36, 178, 92))
    grad = top * (1 - t[..., None]) + bot * t[..., None]
    out[..., :3] = np.where(inside[..., None], grad, out[..., :3])
    out[..., 3] = np.where(inside, 255, out[..., 3])
    img = Image.fromarray(np.clip(out, 0, 255).astype("uint8"), "RGBA")
    # soften the edge
    alpha = img.getchannel("A")
    edge = Image.new("L", img.size, 0)
    ImageDraw.Draw(edge).ellipse((c - radius, c - radius, c + radius, c + radius), fill=255)
    img.putalpha(Image.fromarray(np.maximum(np.asarray(alpha), np.asarray(edge.filter(ImageFilter.GaussianBlur(1.5))))))
    sh = shield_sprite(int(radius * 0.92))
    img.alpha_composite(sh, (c - sh.width // 2, c - sh.height // 2 + int(radius * 0.02)))
    return img


SS = 4  # ImageDraw doesn't antialias shapes, so sprites are drawn at SS x and scaled down


def downsample(img):
    """Scale a sprite drawn at SS x back down, in premultiplied alpha so edges don't darken."""
    return img.convert("RGBa").resize((img.width // SS, img.height // SS), Image.LANCZOS).convert("RGBA")


def pill(text, scale):
    return downsample(_pill(text, scale * SS))


def _pill(text, scale):
    """A blocked lookup, styled after the Activity tab's rows."""
    f = font(46 * scale, mono=True)
    tw = f.getbbox(text)[2]
    h = int(108 * scale)
    w = int(tw + h * 1.35 + 40 * scale)
    img = Image.new("RGBA", (w + 8, h + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((4, 4, w + 3, h + 3), radius=h // 2, fill=(255, 255, 255, 24),
                        outline=(160, 235, 190, 70), width=max(2, int(2 * scale)))
    r = h * 0.26
    cx, cy = 4 + h * 0.55, 4 + h / 2
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=RED + (235,))
    k = r * 0.42
    lw = max(3, int(6 * scale))
    d.line((cx - k, cy - k, cx + k, cy + k), fill="white", width=lw)
    d.line((cx - k, cy + k, cx + k, cy - k), fill="white", width=lw)
    d.text((4 + h * 1.0, cy), text, font=f, fill=MINT + (225,), anchor="lm")
    return img


ORB_R = 300
RING_IN = ORB_R + 40          # where a pill is swallowed
TRAVEL = 5.2                  # seconds from the edge to the orb
ABSORB = 0.45                 # seconds to shrink away
FX_R = 760                    # reach of rings and sparks from the orb center
AMBER = (255, 204, 0)


def ad_card(kind, scale):
    return downsample(_ad_card(kind, scale * SS))


def _ad_card(kind, scale):
    """A generic sponsored unit: a banner or a boxed app ad."""
    s = scale
    if kind == "banner":
        w, h = int(600 * s), int(160 * s)
    else:
        w, h = int(360 * s), int(300 * s)
    img = Image.new("RGBA", (w + 8, h + 8), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = int(26 * s)
    d.rounded_rectangle((4, 4, w + 3, h + 3), radius=r, fill=(255, 255, 255, 26),
                        outline=(255, 255, 255, 60), width=max(2, int(2 * s)))
    bar = (255, 255, 255, 46)
    if kind == "banner":
        m = int(22 * s)
        sq = h - 2 * m
        d.rounded_rectangle((4 + m, 4 + m, 4 + m + sq, 4 + m + sq), radius=int(16 * s), fill=(120, 200, 160, 70))
        x = 4 + 2 * m + sq
        d.rounded_rectangle((x, 4 + m + int(14 * s), x + int(260 * s), 4 + m + int(40 * s)), radius=int(12 * s), fill=bar)
        d.rounded_rectangle((x, 4 + m + int(62 * s), x + int(190 * s), 4 + m + int(84 * s)), radius=int(11 * s), fill=bar)
    else:
        m = int(20 * s)
        d.rounded_rectangle((4 + m, 4 + m, w + 3 - m, 4 + int(170 * s)), radius=int(16 * s), fill=(120, 200, 160, 70))
        d.text((4 + m, 4 + int(200 * s)), "Sponsored", font=font(30 * s, "Semibold"), fill=(255, 255, 255, 120))
        d.rounded_rectangle((4 + m, 4 + int(246 * s), w + 3 - m, 4 + int(280 * s)), radius=int(17 * s), fill=bar)
    bw, bh = int(64 * s), int(40 * s)
    bx, by = w + 3 - bw - int(14 * s), 4 + int(14 * s)
    d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=int(10 * s), fill=AMBER + (200,))
    d.text((bx + bw / 2, by + bh / 2), "Ad", font=font(26 * s, "Bold"), fill=(40, 30, 0, 230), anchor="mm")
    return img


def soften(sprite, alpha, blur):
    sprite.putalpha(sprite.getchannel("A").point(lambda v: v * alpha))
    if not blur:
        return sprite
    # pad so the blur isn't clipped, and blur premultiplied so edges don't pull in black
    pad = int(math.ceil(blur * 3))
    big = Image.new("RGBA", (sprite.width + 2 * pad, sprite.height + 2 * pad), (0, 0, 0, 0))
    big.paste(sprite, (pad, pad))
    return big.convert("RGBa").filter(ImageFilter.GaussianBlur(blur)).convert("RGBA")


class Mover:
    def __init__(self, sprite, left, start, depth, lane, curve, travel=TRAVEL, ring=True, sparks=False, seed=0, gap=0.15, fade=1.0, spread=0.0, hold=1.0):
        self.sprite, self.left, self.start, self.depth = sprite, left, start, depth
        self.lane, self.curve, self.travel = lane, curve, travel
        self.ring, self.sparks = ring, sparks
        self.gap, self.fade, self.spread, self.hold = gap, fade, spread, hold
        rng = np.random.default_rng(1000 + seed)
        self.spark_dirs = rng.uniform(0, 2 * math.pi, 9)
        self.spark_speed = rng.uniform(140, 320, 9)

    def state(self, t):
        u = ((t - self.start) % LOOP)
        if u > self.travel + ABSORB:
            return None
        w = self.sprite.width
        x0 = -w * 0.6 if self.left else W + w * 0.6
        y0 = CY + self.lane
        dirx = 1 if self.left else -1
        # land on the ring at a height that follows the lane, so arrivals don't stack
        ye = CY + max(-1, min(1, self.lane / (H * 0.44))) * RING_IN * self.spread
        reach = math.sqrt(max(0, RING_IN ** 2 - (ye - CY) ** 2))
        xe = CX - dirx * (reach + w * self.gap)
        p = min(u / self.travel, 1)
        e = p ** 2.1            # accelerates as it gets pulled in
        x = x0 + (xe - x0) * e
        # hold > 1 keeps a pill at its own height until the last stretch
        y = y0 + (ye - y0) * e ** self.hold + self.curve * math.sin(math.pi * e)
        scale, alpha = 1.0, min(1, u / 0.6)
        if u > self.travel:
            q = (u - self.travel) / ABSORB
            scale = 1 - 0.85 * q
            alpha *= (1 - q) ** self.fade
            x += (CX - x) * q
            y += (CY - y) * q
        return x, y, scale, alpha

    def absorbed_at(self):
        return (self.start + self.travel) % LOOP


def calm_movers(n=16):
    out = []
    for i in range(n):
        rng = np.random.default_rng(7 + i)
        depth = 0.72 + 0.4 * rng.random()
        lane = (rng.random() * 2 - 1) * H * 0.40
        curve = (rng.random() * 2 - 1) * H * 0.10
        sprite = pill(DOMAINS[i % len(DOMAINS)], depth)
        if depth < 0.85:   # farther pills sit softer and dimmer
            sprite = soften(sprite, 0.7, 1.2)
        out.append(Mover(sprite, i % 2 == 0, i * LOOP / n, depth, lane, curve))
    return out


def dense_movers():
    rng = np.random.default_rng(42)
    out = []
    # (count, depth range, alpha, blur, travel, ring, sparks)
    layers = [
        (24, (0.50, 0.62), 0.45, 2.2, 7.4, False, False),
        (16, (0.78, 0.95), 0.85, 0.0, 5.6, False, True),
        (8, (1.05, 1.25), 1.00, 0.0, 4.4, True, True),
    ]
    k = 0
    for li, (n, (d0, d1), alpha, blur, travel, ring, sparks) in enumerate(layers):
        offset = rng.random() * LOOP
        phase = rng.random()
        for i in range(n):
            depth = rng.uniform(d0, d1)
            # golden-ratio heights spread each layer evenly from top to bottom over time
            lane = (((i * 0.618034 + phase) % 1) * 0.92 - 0.46) * H
            if li == 0:     # the faint back layer keeps to the top and bottom bands
                g = (i * 0.618034 + phase) % 1
                lane = (1 if i % 4 < 2 else -1) * (0.26 + 0.21 * g) * H
            sprite = pill(DOMAINS[k % len(DOMAINS)], depth)
            if alpha < 1 or blur:
                sprite = soften(sprite, alpha, blur)
            out.append(Mover(sprite, (i + li) % 2 == 0, (offset + i * LOOP / n) % LOOP, depth,
                             lane, rng.uniform(-0.06, 0.06) * H,
                             travel, ring, sparks, seed=k, gap=0.6, fade=1.8, spread=0.85, hold=3.0))
            k += 1
    offset = rng.random() * LOOP
    phase = rng.random()
    for i in range(8):
        sprite = soften(ad_card("banner" if i % 2 else "box", rng.uniform(0.8, 1.0)), 0.85, 0.6)
        out.append(Mover(sprite, i % 2 == 1, (offset + i * LOOP / 8) % LOOP, 0.7,
                         (((i * 0.618034 + phase) % 1) * 0.8 - 0.4) * H, rng.uniform(-0.05, 0.05) * H,
                         7.8, True, False, seed=100 + i, gap=0.6, fade=1.8, spread=0.7, hold=3.0))
    return out


DENSE = "--dense" in sys.argv
_cache = {}


def poster_time(movers):
    """The moment where readable pills cover the most of the canvas with the least overlap.

    The video starts here, so the still and the frame shown before playback look full.
    """
    def score(t):
        boxes, cells = [], set()
        for m in movers:
            s = m.state(t) if m.depth > 0.7 else None
            if not s or s[3] < 0.6:
                continue
            x, y, sc, a = s
            w, h = m.sprite.width * sc, m.sprite.height * sc
            l, r = max(0, x - w / 2), min(W, x + w / 2)
            if r - l < w * 0.6:     # mostly off screen
                continue
            boxes.append((l, y - h / 2, r, y + h / 2))
            for cx in range(int(l // (W / 8)), int(min(r, W - 1) // (W / 8)) + 1):
                row = int(min(max(y, 0), H - 1) // (H / 4))
                cells.add((cx, row))
                if row in (0, 3):   # the outer bands are the ones that look bare
                    cells.add((cx, row, 'edge'))
        overlap = 0
        for i, b in enumerate(boxes):
            for c in boxes[i + 1:]:
                overlap += max(0, min(b[2], c[2]) - max(b[0], c[0])) * max(0, min(b[3], c[3]) - max(b[1], c[1]))
        return len(cells) - overlap / 20000
    return max((f / FPS for f in range(int(FPS * LOOP))), key=score)


def assets():
    if not _cache:
        _cache["bg"] = background()
        _cache["orb"] = orb(ORB_R)
        _cache["movers"] = dense_movers() if DENSE else calm_movers()
        _cache["start"] = poster_time(_cache["movers"]) if DENSE else 0.0
    return _cache


def frame(t):
    A = assets()
    img = A["bg"].copy().convert("RGBA")
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # rings and sparks stay within FX_R of the orb; draw them supersampled there
    fx = Image.new("RGBA", (2 * FX_R * SS, 2 * FX_R * SS), (0, 0, 0, 0))
    fxd = ImageDraw.Draw(fx)

    def ellipse(x, y, r, **kw):
        if "width" in kw:
            kw["width"] *= SS
        x, y, r = (x - CX + FX_R) * SS, (y - CY + FX_R) * SS, r * SS
        fxd.ellipse((x - r, y - r, x + r, y + r), **kw)

    # shockwave rings, one per absorbed pill
    hits = []
    for p in A["movers"]:
        dt = (t - p.absorbed_at() - ABSORB * 0.5) % LOOP
        if p.ring and dt < 1.1:
            q = dt / 1.1
            r = ORB_R + 30 + 260 * (1 - (1 - q) ** 2)
            a = int(150 * (1 - q) ** 1.5)
            ellipse(CX, CY, r, outline=EMERALD + (a,), width=6)
            hits.append(1 - q)
        # sparks fly off where the pill entered the ring
        if p.sparks and dt < 0.9:
            q = dt / 0.9
            ex = CX + (-1 if p.left else 1) * RING_IN * 1.05
            for ang, sp in zip(p.spark_dirs, p.spark_speed):
                d = sp * (1 - (1 - q) ** 2)
                sx, sy = ex + math.cos(ang) * d, CY + math.sin(ang) * d
                rr = 7 * (1 - q) + 2
                ellipse(sx, sy, rr, fill=(140, 255, 180, int(230 * (1 - q))))
    # steady halo ring
    ellipse(CX, CY, RING_IN + 60, outline=EMERALD + (40,), width=3)
    layer.alpha_composite(downsample(fx), (CX - FX_R, CY - FX_R))

    for p in sorted(A["movers"], key=lambda p: p.depth):
        s = p.state(t)
        if not s:
            continue
        x, y, scale, alpha = s
        sp = p.sprite
        if scale < 0.999:
            sp = sp.convert("RGBa").resize((max(1, int(sp.width * scale)), max(1, int(sp.height * scale))),
                                            Image.BICUBIC).convert("RGBA")
        if alpha < 0.999:
            sp = sp.copy()
            sp.putalpha(sp.getchannel("A").point(lambda v: int(v * alpha)))
        layer.alpha_composite(sp, (int(x - sp.width / 2), int(y - sp.height / 2)))

    img.alpha_composite(layer)
    # the orb swells slightly with each hit
    o = A["orb"]
    boost = 1 + 0.025 * (max(hits) if hits else 0)
    if boost > 1.001:
        o = o.convert("RGBa").resize((int(o.width * boost), int(o.height * boost)), Image.BICUBIC).convert("RGBA")
    img.alpha_composite(o, (CX - o.width // 2, CY - o.height // 2))
    return img.convert("RGB")


def main():
    mode = next((a for a in sys.argv[1:] if not a.startswith("--")), "still")
    name = "header-dense" if DENSE else "header"
    START = assets()["start"]
    if mode == "still":
        frame(START).save(HERE / f"{name}.png", optimize=True)
    elif mode == "preview":
        shots = [frame(t).resize((W // 4, H // 4), Image.LANCZOS) for t in (0, 2.5, 5, 7.5)]
        sheet = Image.new("RGB", (W // 4, H // 4 * 4))
        for i, s in enumerate(shots):
            sheet.paste(s, (0, i * H // 4))
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

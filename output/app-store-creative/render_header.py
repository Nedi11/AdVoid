"""Renders the AdVoid product page header (21:9, 3840x1646).

    python render_header.py still   -> header.png (first frame, also the video's poster)
    python render_header.py video   -> header.mp4 (10 s seamless loop, 30 fps, H.264)
    python render_header.py preview -> header-preview.png (quarter size contact frames)

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


def pill(text, scale):
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


class Pill:
    def __init__(self, i, n):
        rng = np.random.default_rng(7 + i)
        self.left = i % 2 == 0
        self.start = i * LOOP / n
        self.depth = 0.72 + 0.4 * rng.random()
        self.lane = (rng.random() * 2 - 1) * H * 0.40
        self.curve = (rng.random() * 2 - 1) * H * 0.10
        self.sprite = pill(DOMAINS[i % len(DOMAINS)], self.depth)
        if self.depth < 0.85:   # farther pills sit softer and dimmer
            a = self.sprite.getchannel("A").point(lambda v: v * 0.7)
            self.sprite.putalpha(a)
            self.sprite = self.sprite.filter(ImageFilter.GaussianBlur(1.2))

    def state(self, t):
        u = ((t - self.start) % LOOP)
        if u > TRAVEL + ABSORB:
            return None
        w = self.sprite.width
        x0 = -w * 0.6 if self.left else W + w * 0.6
        y0 = CY + self.lane
        dirx = 1 if self.left else -1
        xe = CX - dirx * (RING_IN + w * 0.15)
        p = min(u / TRAVEL, 1)
        e = p ** 2.1            # accelerates as it gets pulled in
        x = x0 + (xe - x0) * e
        y = y0 + (CY - y0) * e + self.curve * math.sin(math.pi * e)
        scale, alpha = 1.0, min(1, u / 0.6)
        if u > TRAVEL:
            q = (u - TRAVEL) / ABSORB
            scale = 1 - 0.85 * q
            alpha *= 1 - q
            x += (CX - x) * q
            y += (CY - y) * q
        return x, y, scale, alpha

    def absorbed_at(self):
        return (self.start + TRAVEL) % LOOP


N_PILLS = 16
_cache = {}


def assets():
    if not _cache:
        _cache["bg"] = background()
        _cache["orb"] = orb(ORB_R)
        _cache["pills"] = [Pill(i, N_PILLS) for i in range(N_PILLS)]
    return _cache


def frame(t):
    A = assets()
    img = A["bg"].copy().convert("RGBA")
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    # shockwave rings, one per absorbed pill
    rings = ImageDraw.Draw(layer)
    hits = []
    for p in A["pills"]:
        dt = (t - p.absorbed_at() - ABSORB * 0.5) % LOOP
        if dt < 1.1:
            q = dt / 1.1
            r = ORB_R + 30 + 260 * (1 - (1 - q) ** 2)
            a = int(150 * (1 - q) ** 1.5)
            rings.ellipse((CX - r, CY - r, CX + r, CY + r), outline=EMERALD + (a,), width=6)
            hits.append(1 - q)
    # steady halo ring
    rings.ellipse((CX - RING_IN - 60, CY - RING_IN - 60, CX + RING_IN + 60, CY + RING_IN + 60),
                  outline=EMERALD + (40,), width=3)

    for p in sorted(A["pills"], key=lambda p: p.depth):
        s = p.state(t)
        if not s:
            continue
        x, y, scale, alpha = s
        sp = p.sprite
        if scale < 0.999:
            sp = sp.resize((max(1, int(sp.width * scale)), max(1, int(sp.height * scale))), Image.BICUBIC)
        if alpha < 0.999:
            sp = sp.copy()
            sp.putalpha(sp.getchannel("A").point(lambda v: int(v * alpha)))
        layer.alpha_composite(sp, (int(x - sp.width / 2), int(y - sp.height / 2)))

    img.alpha_composite(layer)
    # the orb swells slightly with each hit
    o = A["orb"]
    boost = 1 + 0.025 * (max(hits) if hits else 0)
    if boost > 1.001:
        o = o.resize((int(o.width * boost), int(o.height * boost)), Image.BICUBIC)
    img.alpha_composite(o, (CX - o.width // 2, CY - o.height // 2))
    return img.convert("RGB")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "still"
    if mode == "still":
        frame(0.0).save(HERE / "header.png", optimize=True)
    elif mode == "preview":
        shots = [frame(t).resize((W // 4, H // 4), Image.LANCZOS) for t in (0, 2.5, 5, 7.5)]
        sheet = Image.new("RGB", (W // 4, H // 4 * 4))
        for i, s in enumerate(shots):
            sheet.paste(s, (0, i * H // 4))
        sheet.save(HERE / "header-preview.png")
    elif mode == "video":
        out = HERE / "header.mp4"
        ff = subprocess.Popen([
            "ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
            "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
            "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "14",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", str(out)], stdin=subprocess.PIPE)
        n = int(FPS * LOOP)
        for f in range(n):
            ff.stdin.write(frame(f / FPS).tobytes())
            if f % 30 == 0:
                print(f"frame {f}/{n}", flush=True)
        ff.stdin.close()
        ff.wait()


if __name__ == "__main__":
    main()

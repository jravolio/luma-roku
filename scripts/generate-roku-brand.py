#!/usr/bin/env python3
"""Render Luma's channel icons and splash: "Luma" in Fraunces Italic, closed by a
warm crescent whose hollow holds the final "a".

Requires Pillow: python3 scripts/generate-roku-brand.py   # writes roku/images/
               python3 scripts/generate-roku-brand.py --readme   # docs/assets/luma-banner.png
"""
import math
from pathlib import Path
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WORDMARK = ROOT / "scripts/brand-fonts/Fraunces-Italic-Variable.ttf"
TAGLINE = ROOT / "roku/fonts/Inter-Medium.ttf"
TOP, BOTTOM = (18, 18, 22), (7, 7, 9)
WARM_LIGHT, WARM_EDGE = (255, 241, 214), (255, 138, 82)
WHITE = (245, 245, 247)


def wordmark_font(px):
    # Soft, wonky italic; the sturdy text optical size survives the small Roku tile.
    font = ImageFont.truetype(str(WORDMARK), px)
    axes = {"Softness": 100, "Wonky": 1, "Optical Size": 9, "Weight": 560}
    names = [a["name"].decode() if isinstance(a["name"], bytes) else a["name"] for a in font.get_variation_axes()]
    font.set_variation_by_axes([axes[n] for n in names])
    return font


def vertical_bg(size):
    W, H = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = y / (H - 1)
        draw.line([(0, y), (W, y)], fill=tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    return image


def warm_gradient(size, angle=65):
    w, h = size
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    proj = [x * dx + y * dy for x, y in ((0, 0), (w, 0), (0, h), (w, h))]
    lo, hi = min(proj), max(proj)
    image = Image.new("RGB", size)
    px = image.load()
    for y in range(h):
        for x in range(w):
            t = ((x * dx + y * dy) - lo) / (hi - lo)
            px[x, y] = tuple(round(WARM_LIGHT[i] + (WARM_EDGE[i] - WARM_LIGHT[i]) * t) for i in range(3))
    return image


def crescent(diameter):
    """Hollow facing left, slightly raised, like a waning moon."""
    disc = Image.new("L", (diameter, diameter), 0)
    ImageDraw.Draw(disc).ellipse([0, 0, diameter - 1, diameter - 1], fill=255)
    cut = Image.new("L", (diameter, diameter), 0)
    cx, cy, r = diameter * 0.14, diameter * 0.40, diameter * 0.44
    ImageDraw.Draw(cut).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return ImageChops.subtract(disc, cut)


def wordmark(px):
    """RGBA wordmark with its bloom, and the ink bounding box."""
    font = wordmark_font(px)
    W, H = px * 4, px * 2
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    baseline, x = int(H * 0.68), int(px * 0.3)
    ImageDraw.Draw(layer).text((x, baseline), "Luma", font=font, fill=WHITE, anchor="ls")
    x_height = -font.getbbox("x", anchor="ls")[1]
    diameter = int(x_height * 1.55)
    # The hollow's inner edge clears the a's tail by a hairline.
    mx = int(x + font.getlength("Luma") - diameter * 0.26)
    my = int(baseline - x_height / 2 - diameter / 2)
    mask = crescent(diameter)
    bloom = Image.new("L", (W, H), 0)
    bloom.paste(mask, (mx, my))
    bloom = bloom.filter(ImageFilter.GaussianBlur(diameter * 0.45)).point(lambda v: int(v * 0.32))
    glow = Image.new("RGBA", (W, H), WARM_EDGE + (0,))
    glow.putalpha(bloom)
    layer = Image.alpha_composite(glow, layer)
    moon = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    moon.paste(warm_gradient((diameter, diameter)), (0, 0), mask)
    layer.alpha_composite(moon, (mx, my))
    ink = layer.split()[3].point(lambda v: 255 if v > 90 else 0).getbbox()
    return layer, ink


def render(size, px, tagline=None, tag_px=0, scale=2):
    W, H = size[0] * scale, size[1] * scale
    canvas = vertical_bg((W, H)).convert("RGBA")
    layer, (x0, y0, x1, y1) = wordmark(px * scale)
    lift = (tag_px * scale * 1.6) if tagline else 0
    ox, oy = int(W / 2 - (x0 + x1) / 2), int(H / 2 - lift - (y0 + y1) / 2)
    canvas.alpha_composite(layer, (ox, oy))
    if tagline:
        font = ImageFont.truetype(str(TAGLINE), tag_px * scale)
        box = font.getbbox(tagline)
        ImageDraw.Draw(canvas).text((W / 2 - (box[2] - box[0]) / 2 - box[0], oy + y1 + tag_px * scale * 1.4), tagline, font=font, fill=(142, 142, 147))
    return canvas.convert("RGB").resize(size, Image.LANCZOS)


def banner(size=(1280, 400), radius=40):
    """The README header: the splash, wide and with rounded corners, so it reads
    the same on GitHub's light and dark themes."""
    image = render(size, 150, tagline="A Jellyfin client for Roku, in the style of Apple TV", tag_px=24).convert("RGBA")
    mask = Image.new("L", (size[0] * 4, size[1] * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] * 4 - 1, size[1] * 4 - 1], radius * 4, fill=255)
    image.putalpha(mask.resize(size, Image.LANCZOS))
    return image


if __name__ == "__main__":
    if sys.argv[1:] == ["--readme"]:
        banner().save(ROOT / "docs/assets/luma-banner.png", optimize=True)
        sys.exit()
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "roku/images"
    render((540, 405), 118).save(out / "channel-icon-fhd.png", optimize=True)
    render((290, 218), 63).save(out / "channel-icon-hd.png", optimize=True)
    render((1920, 1080), 190, tagline="Seu cinema. Em casa.", tag_px=32).save(out / "splash.png", optimize=True)

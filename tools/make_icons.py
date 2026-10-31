"""Draws the app icon (magnifier over a magnet) in every accent colour.

Run: python3 tools/make_icons.py
Writes assets/icon.png (default) and assets/icons/AppIcon-<Name>.png.
"""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 1024
# Keep in sync with lib/appearance.dart
PALETTE = [
    ('Teal',   (46, 230, 166)),
    ('Tan',    (229, 162, 118)),
    ('Blue',   (63, 142, 252)),
    ('Indigo', (116, 128, 248)),
    ('Purple', (200, 71, 232)),
    ('Pink',   (234, 76, 107)),
    ('Red',    (236, 85, 80)),
    ('Orange', (240, 154, 74)),
    ('Yellow', (247, 214, 75)),
    ('Green',  (107, 207, 107)),
    ('Mint',   (98, 214, 196)),
    ('Cyan',   (90, 205, 224)),
    ('Sky',    (109, 207, 246)),
]
TIP = (232, 238, 242)

def background():
    im = Image.new('RGB', (S, S)); d = ImageDraw.Draw(im)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=(int(12 + 14 * t), int(16 + 18 * t), int(24 + 22 * t)))
    return im

def magnet(color, cx, cy, ro, ri, leg, scale=1.0, about=(0, 0)):
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    ax, ay = about
    cx, cy = ax + (cx - ax) * scale, ay + (cy - ay) * scale
    ro, ri, leg = ro * scale, ri * scale, leg * scale
    d.pieslice([cx - ro, cy - ro, cx + ro, cy + ro], 180, 360, fill=color)
    d.rectangle([cx - ro, cy, cx - ri, cy + leg], fill=color)
    d.rectangle([cx + ri, cy, cx + ro, cy + leg], fill=color)
    hole = Image.new('L', (S, S), 0); h = ImageDraw.Draw(hole)
    h.pieslice([cx - ri, cy - ri, cx + ri, cy + ri], 180, 360, fill=255)
    h.rectangle([cx - ri, cy, cx + ri, cy + leg + 2], fill=255)
    layer.putalpha(ImageChops.subtract(layer.getchannel('A'), hole))
    d = ImageDraw.Draw(layer)
    top = cy + leg * 0.55
    d.rectangle([cx - ro, top, cx - ri, cy + leg], fill=TIP)
    d.rectangle([cx + ri, top, cx + ro, cy + leg], fill=TIP)
    return layer

def icon(accent):
    # Magnet is red, except where the accent itself is red-ish.
    mag_col = (63, 142, 252) if accent in [(234, 76, 107), (236, 85, 80)] else (255, 92, 92)
    img = background()
    m = (390, 470, 150, 78, 140)
    lx, ly, lr = 640, 450, 265
    out = magnet(mag_col, *m); img.paste(out, (0, 0), out)
    lens = Image.new('L', (S, S), 0); ImageDraw.Draw(lens).ellipse([lx - lr, ly - lr, lx + lr, ly + lr], fill=255)
    tint = tuple(int(c * 0.25 + 20) for c in accent)
    inner = Image.blend(background(), Image.new('RGB', (S, S), tint), 0.45)
    big = magnet(mag_col, *m, scale=1.45, about=(lx - lr + 15, m[1] + 20)); inner.paste(big, (0, 0), big)
    glint = tuple(min(255, int(c * 0.4 + 160)) for c in accent)
    ImageDraw.Draw(inner).arc([lx - lr + 50, ly - lr + 50, lx + lr - 50, ly + lr - 50], 200, 250, fill=glint, width=16)
    img.paste(inner, (0, 0), lens)
    glow = Image.new('L', (S, S), 0); ImageDraw.Draw(glow).ellipse([lx - lr, ly - lr, lx + lr, ly + lr], outline=255, width=60)
    img.paste(accent, (0, 0), glow.filter(ImageFilter.GaussianBlur(35)).point(lambda v: int(v * 0.4)))
    d = ImageDraw.Draw(img)
    d.ellipse([lx - lr, ly - lr, lx + lr, ly + lr], outline=accent, width=52)
    a = math.radians(45)
    x0, y0 = lx + (lr + 12) * math.cos(a), ly + (lr + 12) * math.sin(a)
    x1, y1 = lx + (lr + 190) * math.cos(a), ly + (lr + 190) * math.sin(a)
    d.line([(x0, y0), (x1, y1)], fill=accent, width=92)
    d.ellipse([x1 - 46, y1 - 46, x1 + 46, y1 + 46], fill=accent)
    return img

if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(os.path.join(root, 'assets', 'icons'), exist_ok=True)
    for i, (name, col) in enumerate(PALETTE):
        im = icon(col)
        if i == 0:
            im.save(os.path.join(root, 'assets', 'icon.png'), optimize=True)
        else:
            im.save(os.path.join(root, 'assets', 'icons', f'AppIcon-{name}.png'), optimize=True)
    print('wrote', len(PALETTE), 'icons')

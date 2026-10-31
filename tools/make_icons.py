"""App icon: two overlapping magnifying glasses with a magnet, drawn in a dim
and a bright shade of one accent colour on a dark tile.

Run: python3 tools/make_icons.py
Writes assets/icon.png (default colour) and assets/icons/AppIcon-<Name>.png.
"""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 1024
SS = 2  # supersample for smooth edges
# Keep in sync with lib/appearance.dart
PALETTE = [
    ('Teal',   (46, 230, 166)),
    ('Tan',    (210, 160, 110)),
    ('Blue',   (10, 132, 255)),
    ('Indigo', (94, 92, 230)),
    ('Purple', (191, 90, 242)),
    ('Pink',   (255, 55, 95)),
    ('Red',    (255, 69, 58)),
    ('DarkRed', (176, 18, 32)),
    ('Orange', (255, 159, 10)),
    ('Yellow', (255, 214, 10)),
    ('Green',  (48, 209, 88)),
    ('Mint',   (99, 230, 226)),
    ('Cyan',   (64, 200, 224)),
    ('Sky',    (100, 210, 255)),
]
BG_TOP, BG_BOTTOM = (44, 44, 46), (22, 22, 24)

def mix(a, b, t):
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))

def tile(n):
    im = Image.new('RGB', (n, n)); d = ImageDraw.Draw(im)
    for y in range(n):
        d.line([(0, y), (n, y)], fill=mix(BG_TOP, BG_BOTTOM, y / n))
    return im

def glass(n, cx, cy, r, ring, handle_angle, handle_len, handle_w):
    """Mask for a magnifying glass: ring + handle."""
    m = Image.new('L', (n, n), 0); d = ImageDraw.Draw(m)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    d.ellipse([cx - r + ring, cy - r + ring, cx + r - ring, cy + r - ring], fill=0)
    a = math.radians(handle_angle)
    x0, y0 = cx + (r - ring * 0.3) * math.cos(a), cy + (r - ring * 0.3) * math.sin(a)
    x1, y1 = cx + (r + handle_len) * math.cos(a), cy + (r + handle_len) * math.sin(a)
    d.line([(x0, y0), (x1, y1)], fill=255, width=handle_w)
    d.ellipse([x1 - handle_w / 2, y1 - handle_w / 2, x1 + handle_w / 2, y1 + handle_w / 2], fill=255)
    return m

def lens(n, cx, cy, r):
    m = Image.new('L', (n, n), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m

def magnet(n, cx, cy, ro, ri, leg):
    """Horseshoe magnet opening downward: (body mask, tips mask)."""
    body = Image.new('L', (n, n), 0); d = ImageDraw.Draw(body)
    d.pieslice([cx - ro, cy - ro, cx + ro, cy + ro], 180, 360, fill=255)
    d.rectangle([cx - ro, cy, cx - ri, cy + leg], fill=255)
    d.rectangle([cx + ri, cy, cx + ro, cy + leg], fill=255)
    d.pieslice([cx - ri, cy - ri, cx + ri, cy + ri], 180, 360, fill=0)
    d.rectangle([cx - ri, cy - 1, cx + ri, cy + leg], fill=0)
    tips = Image.new('L', (n, n), 0); t = ImageDraw.Draw(tips)
    top = cy + leg * 0.5
    t.rectangle([cx - ro, top, cx - ri, cy + leg], fill=255)
    t.rectangle([cx + ri, top, cx + ro, cy + leg], fill=255)
    return ImageChops.subtract(body, tips), tips

def icon(accent):
    n = S * SS
    k = SS
    img = tile(n)
    dim = mix(BG_BOTTOM, accent, 0.38)      # muted shade, like a tinted shadow
    bright = accent
    # Back glass (dim), upper-left, handle to lower-left
    back = glass(n, 395 * k, 385 * k, 200 * k, 58 * k, 140, 140 * k, 90 * k)
    # Front glass (bright), lower-right, handle to lower-right
    fcx, fcy, fr = 590 * k, 570 * k, 235 * k
    ring = 62 * k
    front = glass(n, fcx, fcy, fr, ring, 45, 140 * k, 100 * k)
    inner = lens(n, fcx, fcy, fr - ring)
    img.paste(dim, (0, 0), back)
    # Tinted glass inside the front lens; back ring shows through faintly
    img.paste(mix(BG_BOTTOM, accent, 0.10), (0, 0), inner)
    img.paste(mix(BG_BOTTOM, accent, 0.24), (0, 0), ImageChops.multiply(back, inner))
    # Magnet centred in the front lens: bright body, dim tips
    body, tips = magnet(n, fcx, fcy - 25 * k, 112 * k, 54 * k, 118 * k)
    img.paste(bright, (0, 0), body)
    img.paste(dim, (0, 0), tips)
    img.paste(bright, (0, 0), front)
    return img.resize((S, S), Image.LANCZOS)

if __name__ == '__main__':
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(os.path.join(root, 'assets', 'icons'), exist_ok=True)
    for i, (name, col) in enumerate(PALETTE):
        im = icon(col)
        # Every colour, including the default, is also an alternate icon, so
        # switching back to the default never relies on iOS's reset call.
        if i == 0:
            im.save(os.path.join(root, 'assets', 'icon.png'), optimize=True)
        im.save(os.path.join(root, 'assets', 'icons', f'AppIcon-{name}.png'), optimize=True)
    print('wrote', len(PALETTE), 'icons')

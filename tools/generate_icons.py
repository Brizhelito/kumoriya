from PIL import Image, ImageDraw
import os

SRC = r'C:\Users\Reny\Documents\Kumoriya\logo.ico'
RES = r'C:\Users\Reny\Documents\Kumoriya\apps\kumoriya_app\android\app\src\main\res'
BG_COLOR = (250, 250, 255, 255)  # #fafaff - matches ic_launcher_background.xml

src = Image.open(SRC).convert('RGBA')

# (folder, legacy_size, foreground_size)
densities = [
    ('mipmap-ldpi',    36,   81),
    ('mipmap-mdpi',    48,  108),
    ('mipmap-hdpi',    72,  162),
    ('mipmap-xhdpi',   96,  216),
    ('mipmap-xxhdpi', 144,  324),
    ('mipmap-xxxhdpi',192,  432),
]

def make_legacy_square(src_img, size, bg):
    base = Image.new('RGBA', (size, size), bg)
    icon = src_img.resize((size, size), Image.LANCZOS)
    base.alpha_composite(icon)
    return base.convert('RGB')

def make_legacy_round(src_img, size, bg):
    base = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bg_circle = Image.new('RGBA', (size, size), bg)
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse([0, 0, size - 1, size - 1], fill=255)
    bg_circle.putalpha(mask)
    icon = src_img.resize((size, size), Image.LANCZOS)
    base.alpha_composite(bg_circle)
    base.alpha_composite(icon)
    final = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final.paste(base, mask=mask)
    return final

def make_foreground(src_img, size):
    # Center artwork at 60% of canvas so it stays inside adaptive safe zone
    artwork_size = int(size * 0.60)
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    icon = src_img.resize((artwork_size, artwork_size), Image.LANCZOS)
    x = (size - artwork_size) // 2
    y = (size - artwork_size) // 2
    canvas.paste(icon, (x, y), icon)
    return canvas

def make_monochrome(src_img, size):
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    icon = src_img.resize((size, size), Image.LANCZOS)
    _, _, _, a = icon.split()
    gray = icon.convert('L')
    mono = Image.merge('RGBA', (gray, gray, gray, a))
    canvas.alpha_composite(mono)
    return canvas

webp_opts = {'format': 'WEBP', 'quality': 90}

for folder, legacy_size, fg_size in densities:
    dst = os.path.join(RES, folder)
    os.makedirs(dst, exist_ok=True)

    make_legacy_square(src, legacy_size, BG_COLOR).save(
        os.path.join(dst, 'ic_launcher.webp'), **webp_opts)

    make_legacy_round(src, legacy_size, BG_COLOR).save(
        os.path.join(dst, 'ic_launcher_round.webp'), **webp_opts)

    make_foreground(src, fg_size).save(
        os.path.join(dst, 'ic_launcher_foreground.webp'), **webp_opts)

    make_monochrome(src, fg_size).save(
        os.path.join(dst, 'ic_launcher_monochrome.webp'), **webp_opts)

    print(f'{folder}: legacy={legacy_size}px, fg={fg_size}px - OK')

print('All Android icons generated!')

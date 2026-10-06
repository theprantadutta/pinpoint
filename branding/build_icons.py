"""Builds the icon files that flutter_launcher_icons cannot make on its own.

    dart run flutter_launcher_icons        # iOS, Android adaptive, web, macOS
    python branding/build_icons.py         # everything below, then commit both

Everything is drawn from the one pin mark in adaptive-foreground-ink-1024.png,
so a change to the pin only has to be made there.

Writes:
  branding/app-icon-sticker-1024.png  macOS master: the brand sticker (yellow,
                                      ink outline, hard ink shadow) on Apple's
                                      824px grid. macOS does not mask icons, so
                                      the shape has to be in the artwork.
  branding/app-icon-legacy-1024.png   Android 7 (API 24-25) master, same sticker
                                      with a tighter margin; those launchers do
                                      not mask either.
  android .../ic_launcher_round.png   API 25 round icon.
  android .../ic_stat_pinpoint.png    status-bar icon: white pin, 2dp padding.
  windows .../app_icon.ico            16-256px in one file, so small sizes are
                                      drawn, not squashed from 256.
  web/favicon.png                     32px, no outline (it turns to mush).
  ../pinpoint-backend/.../public/     the support and marketing pages' icons,
                                      when the backend repo sits next to this one.

Needs Pillow.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
BRANDING = ROOT / "branding"
BACKEND_PUBLIC = (
    ROOT.parent / "pinpoint-backend" / "src" / "Pinpoint.Api" / "wwwroot" / "public"
)

YELLOW = (0xF6, 0xE2, 0x7A, 255)
INK = (0x14, 0x14, 0x14, 255)
WHITE = (255, 255, 255, 255)

SUPERSAMPLE = 4


def pin_mask() -> Image.Image:
    """The pin's alpha channel, cropped to the pin."""
    src = Image.open(BRANDING / "adaptive-foreground-ink-1024.png").convert("RGBA")
    alpha = src.getchannel("A")
    return alpha.crop(alpha.getbbox())


PIN = pin_mask()


def paste_pin(canvas: Image.Image, colour, height: float, centre: tuple[float, float]):
    scale = height / PIN.height
    size = (max(1, round(PIN.width * scale)), max(1, round(PIN.height * scale)))
    mask = PIN.resize(size, Image.LANCZOS)
    x = round(centre[0] - size[0] / 2)
    y = round(centre[1] - size[1] / 2)
    canvas.paste(Image.new("RGBA", size, colour), (x, y), mask)


def sticker(size: int, margin: float, pin_height: float = 0.5) -> Image.Image:
    """The brand sticker: yellow rounded square, ink outline, hard ink shadow.

    margin, like every other measure here, is a fraction of the canvas; the
    corner radius, outline and shadow are fractions of the sticker itself, so
    the proportions hold from 16px to 1024px.
    """
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    body = s * (1 - 2 * margin)
    shadow = body * 0.03
    stroke = max(SUPERSAMPLE, body * 0.022)
    radius = body * 0.225
    # Centre the sticker AND its shadow, so the pair sits optically centred.
    left = (s - body - shadow) / 2
    top = left
    box = (left, top, left + body, top + body)

    draw.rounded_rectangle(
        (box[0] + shadow, box[1] + shadow, box[2] + shadow, box[3] + shadow),
        radius=radius,
        fill=INK,
    )
    draw.rounded_rectangle(box, radius=radius, fill=YELLOW, outline=INK, width=round(stroke))
    paste_pin(img, INK, body * pin_height, (left + body / 2, top + body / 2))
    return img.resize((size, size), Image.LANCZOS)


def flat_square(size: int, radius: float, pin_height: float) -> Image.Image:
    """Yellow rounded square, ink pin, nothing else. For tiny sizes."""
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle((0, 0, s - 1, s - 1), radius=s * radius, fill=YELLOW)
    paste_pin(img, INK, s * pin_height, (s / 2, s / 2))
    return img.resize((size, size), Image.LANCZOS)


def full_bleed(size: int) -> Image.Image:
    """Square yellow tile for platforms that apply their own mask (iOS)."""
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), YELLOW)
    paste_pin(img, INK, s * 0.39, (s / 2, s / 2))
    return img.resize((size, size), Image.LANCZOS).convert("RGB")


def round_icon(size: int) -> Image.Image:
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    inset = s * 0.02
    ImageDraw.Draw(img).ellipse(
        (inset, inset, s - inset, s - inset), fill=YELLOW, outline=INK, width=round(s * 0.02)
    )
    paste_pin(img, INK, s * 0.46, (s / 2, s / 2))
    return img.resize((size, size), Image.LANCZOS)


def status_bar_icon(px_per_dp: float) -> Image.Image:
    """24dp canvas, pin inside the 20dp live area, white on transparent."""
    size = round(24 * px_per_dp)
    s = size * SUPERSAMPLE
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    paste_pin(img, WHITE, 20 * px_per_dp * SUPERSAMPLE, (s / 2, s / 2))
    return img.resize((size, size), Image.LANCZOS)


DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


# Native splash glyph height, in px at the 4x density flutter_native_splash
# treats its images as: 520px renders at 130dp, the weight of the launcher
# tile's pin seen full screen.
SPLASH_PIN_PX = 520


def splash_glyph(colour) -> Image.Image:
    """The pin alone on transparent, for the pre-Android-12 and iOS splash."""
    scale = SPLASH_PIN_PX / PIN.height
    size = (round(PIN.width * scale), SPLASH_PIN_PX)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    paste_pin(canvas, colour, SPLASH_PIN_PX, (size[0] / 2, size[1] / 2))
    return canvas


def android12_glyph(colour) -> Image.Image:
    """Android 12+ splash icon: 1152px square, every pixel inside the centred
    768px circle, because the system crops to it rather than scaling. Drawn
    at the same 130dp as splash_glyph (1152px is 288dp)."""
    canvas = Image.new("RGBA", (1152, 1152), (0, 0, 0, 0))
    paste_pin(canvas, colour, SPLASH_PIN_PX, (576, 576))
    return canvas


def splash():
    """Masters for flutter_native_splash.yaml."""
    splash_glyph(INK).save(BRANDING / "splash-glyph-ink.png")
    splash_glyph(YELLOW).save(BRANDING / "splash-glyph-yellow.png")
    android12_glyph(INK).save(BRANDING / "android12-glyph-ink.png")


def main():
    res = ROOT / "android" / "app" / "src" / "main" / "res"

    splash()

    sticker(1024, margin=100 / 1024).save(BRANDING / "app-icon-sticker-1024.png")
    sticker(1024, margin=0.04).save(BRANDING / "app-icon-legacy-1024.png")

    for name, scale in DENSITIES.items():
        round_icon(round(48 * scale)).save(res / f"mipmap-{name}" / "ic_launcher_round.png")
        status_bar_icon(scale).save(res / f"drawable-{name}" / "ic_stat_pinpoint.png")

    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    # Small sizes drop the outline and shadow, which blur into a smudge.
    frames = [flat_square(n, 0.22, 0.62) if n <= 32 else sticker(n, 0.04) for n in ico_sizes]
    frames[-1].save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        sizes=[(n, n) for n in ico_sizes],
        append_images=frames[:-1],
    )

    flat_square(32, 0.22, 0.62).save(ROOT / "web" / "favicon.png")

    if BACKEND_PUBLIC.is_dir():
        icons = BACKEND_PUBLIC / "icons"
        favicon_sizes = [16, 32, 48]
        favicons = [flat_square(n, 0.22, 0.62) for n in favicon_sizes]
        favicons[-1].save(
            icons / "favicon.ico",
            sizes=[(n, n) for n in favicon_sizes],
            append_images=favicons[:-1],
        )
        full_bleed(180).save(icons / "apple-touch-icon.png")
        sticker(192, 0.04).save(icons / "icon-192.png")
        sticker(512, 0.04).save(icons / "icon-512.png")
        sticker(800, 0.04).save(BACKEND_PUBLIC / "images" / "pinpoint-logo.png")


if __name__ == "__main__":
    main()

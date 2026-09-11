#!/usr/bin/env python3
"""Generates every app icon from tool/icon_source.png.

    python3 tool/generate_app_icon.py

Writes, all derived from the one source drawing:
  * Android legacy launcher icons (mipmap-*/ic_launcher.png)
  * Android adaptive icon foregrounds (mipmap-*/ic_launcher_foreground.png)
    plus the background colour and the anydpi-v26 descriptor
  * The notification small icon (drawable-*/ic_stat_reminder.png), which
    Android draws as a mask, so it must be white on transparent
  * Every iOS icon size listed in the asset catalogue, flattened onto an
    opaque background since iOS rejects icons with alpha
"""

import json
import os

from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "tool", "icon_source.png")

BRAND = (20, 121, 90)  # kSeedColor in lib/theme.dart

ANDROID_RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_ICONS = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)

# Density buckets and their scale factor relative to mdpi.
DENSITIES = {
    "mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4,
}


def load_mask() -> Image.Image:
    """The drawing as an alpha mask: ink opaque, paper transparent."""
    src = Image.open(SOURCE).convert("L")
    # The art is dark on white, so inverted luminance is exactly the coverage,
    # anti-aliased edges included.
    mask = Image.eval(src, lambda v: 255 - v)
    return mask.crop(mask.getbbox())


def tinted(mask: Image.Image, size: int, colour, coverage: float,
           background=None) -> Image.Image:
    """The mask drawn in `colour`, centred on a `size` square.

    `coverage` is how much of the square's width the drawing spans.
    """
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if background is not None:
        canvas.paste(Image.new("RGBA", (size, size), background + (255,)))

    target = max(1, int(size * coverage))
    w, h = mask.size
    scale = min(target / w, target / h)
    art = mask.resize(
        (max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS
    )

    layer = Image.new("RGBA", art.size, colour + (255,))
    layer.putalpha(art)
    canvas.alpha_composite(
        layer, ((size - art.size[0]) // 2, (size - art.size[1]) // 2)
    )
    return canvas


def thicken(mask: Image.Image, radius: int) -> Image.Image:
    """Fattens the strokes, so thin line art survives at status-bar size."""
    return mask.filter(ImageFilter.MaxFilter(radius))


def write(image: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path)


def main() -> None:
    mask = load_mask()

    for bucket, scale in DENSITIES.items():
        # Legacy launcher icon: 48dp, full-bleed brand background.
        write(
            tinted(mask, round(48 * scale), (255, 255, 255), 0.66,
                   background=BRAND),
            os.path.join(ANDROID_RES, f"mipmap-{bucket}", "ic_launcher.png"),
        )
        # Adaptive foreground: a 108dp canvas whose outer third can be cropped
        # by the launcher's mask, so the drawing stays well inside it.
        write(
            tinted(mask, round(108 * scale), (255, 255, 255), 0.42),
            os.path.join(
                ANDROID_RES, f"mipmap-{bucket}", "ic_launcher_foreground.png"
            ),
        )
        # Notification icon: 24dp, white on transparent, strokes thickened
        # because the source lines vanish at this size.
        small = round(24 * scale)
        write(
            tinted(thicken(mask, 5), small, (255, 255, 255), 0.92),
            os.path.join(
                ANDROID_RES, f"drawable-{bucket}", "ic_stat_reminder.png"
            ),
        )

    write_android_xml()

    catalogue = json.load(open(os.path.join(IOS_ICONS, "Contents.json")))
    for entry in catalogue["images"]:
        side, _, _ = entry["size"].partition("x")
        px = round(float(side) * float(entry["scale"].rstrip("x")))
        icon = tinted(mask, px, (255, 255, 255), 0.66, background=BRAND)
        # iOS icons must be fully opaque.
        write(icon.convert("RGB"), os.path.join(IOS_ICONS, entry["filename"]))

    print("icons written")


def write_android_xml() -> None:
    values = os.path.join(ANDROID_RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "ic_launcher_background.xml"), "w") as out:
        out.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#%02X%02X%02X</color>\n'
            "</resources>\n" % BRAND
        )

    anydpi = os.path.join(ANDROID_RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    descriptor = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "</adaptive-icon>\n"
    )
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w") as out:
            out.write(descriptor)


if __name__ == "__main__":
    main()

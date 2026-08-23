#!/usr/bin/env python3
"""
RepGate brand asset generator.

Concept: a gate arch (the app-lock barrier) framing ascending chevrons
(the reps that open it). Brand colours are taken from lib/utils/app_theme.dart
so the icon matches the in-app palette exactly.

Everything is drawn at 4x and downsampled with LANCZOS, which gives clean
anti-aliased edges without shipping a rasteriser dependency in the app.

Usage:  python3 tool/generate_icons.py
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFilter

# ---------------------------------------------------------------- brand tokens
LIME = (181, 224, 72)        # AppColors.limeBright  #B5E048
LIME_DEEP = (138, 176, 46)   # shadowed edge of the lime
INK_TOP = (28, 33, 20)       # top of the background gradient
INK_BOTTOM = (8, 10, 6)      # bottom of the background gradient
WHITE = (255, 255, 255)

SS = 4  # supersample factor


def _vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    """A vertical gradient built one row at a time (cheap at these sizes)."""
    grad = Image.new("RGB", (1, size))
    px = grad.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        px[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return grad.resize((size, size), Image.NEAREST)


def _rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=int(size * radius_ratio),
        fill=255,
    )
    return mask


def _draw_gate_and_chevrons(draw: ImageDraw.ImageDraw, size: int) -> None:
    """Gate arch + three ascending chevrons, centred in a `size` box."""
    u = size / 100.0  # 1 unit == 1% of the canvas

    # ---- Gate: an arch with two legs, drawn as a thick rounded outline.
    stroke = int(9 * u)
    left, right = 22 * u, 78 * u
    arch_top, arch_bottom = 22 * u, 52 * u
    leg_bottom = 80 * u

    # Arch (top half of an ellipse). PIL grows the arc stroke inward from the
    # bounding box, so the stroke centreline sits half a stroke inside each edge.
    draw.arc(
        (left, arch_top, right, arch_bottom + (arch_bottom - arch_top)),
        start=180,
        end=360,
        fill=LIME,
        width=stroke,
    )

    # Legs must sit on that same centreline, otherwise they detach from the arch.
    cap = stroke / 2
    leg_centres = (left + cap, right - cap)
    for cx in leg_centres:
        draw.line((cx, arch_bottom, cx, leg_bottom), fill=LIME, width=stroke)
        # Round cap at the foot, and one at the join to hide the seam.
        draw.ellipse((cx - cap, leg_bottom - cap, cx + cap, leg_bottom + cap), fill=LIME)
        draw.ellipse((cx - cap, arch_bottom - cap, cx + cap, arch_bottom + cap), fill=LIME)

    # ---- Chevrons: three ascending strokes = reps earning the unlock.
    chev_w = int(6.5 * u)
    apex_x = 50 * u
    spread = 13 * u
    for i, (apex_y, colour) in enumerate(
        ((44 * u, WHITE), (57 * u, LIME), (70 * u, LIME_DEEP))
    ):
        draw.line(
            (apex_x - spread, apex_y + spread * 0.62, apex_x, apex_y),
            fill=colour,
            width=chev_w,
        )
        draw.line(
            (apex_x, apex_y, apex_x + spread, apex_y + spread * 0.62),
            fill=colour,
            width=chev_w,
        )
        # Round the joints so the chevron reads cleanly when scaled down.
        r = chev_w / 2
        for cx, cy in (
            (apex_x, apex_y),
            (apex_x - spread, apex_y + spread * 0.62),
            (apex_x + spread, apex_y + spread * 0.62),
        ):
            draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=colour)


def build_icon(size: int, *, rounded: bool, transparent: bool = False) -> Image.Image:
    """Render one icon at `size` px."""
    s = size * SS

    if transparent:
        canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    else:
        bg = _vertical_gradient(s, INK_TOP, INK_BOTTOM).convert("RGBA")
        canvas = bg
        # A soft lime glow behind the mark gives the icon depth on dark launchers.
        glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(glow).ellipse(
            (s * 0.18, s * 0.14, s * 0.82, s * 0.78), fill=(*LIME, 46)
        )
        canvas = Image.alpha_composite(
            canvas, glow.filter(ImageFilter.GaussianBlur(s * 0.06))
        )

    art = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    _draw_gate_and_chevrons(ImageDraw.Draw(art), s)
    canvas = Image.alpha_composite(canvas.convert("RGBA"), art)

    if not transparent:
        # Launcher icons are masked by the OS, but baking the radius in keeps
        # legacy (pre-adaptive) launchers from showing hard square corners.
        mask = _rounded_mask(s, 0.5 if rounded else 0.22)
        out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        out.paste(canvas, (0, 0), mask)
        canvas = out

    return canvas.resize((size, size), Image.LANCZOS)


def build_foreground(size: int) -> Image.Image:
    """Adaptive-icon foreground: art only, inset into the 66% safe zone."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.66)
    art = build_icon(inner, rounded=False, transparent=True)
    off = (size - inner) // 2
    layer.paste(art, (off, off), art)
    return layer


def build_wordmark(width: int = 1600) -> Image.Image:
    """Horizontal lockup for the README / store listing."""
    height = width // 4
    img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    mark = build_icon(int(height * 0.88), rounded=False)
    img.paste(mark, (int(height * 0.10), int(height * 0.06)), mark)

    draw = ImageDraw.Draw(img)
    # No bundled font is guaranteed, so the wordmark is drawn from primitives:
    # a lime "Rep" block and an outlined "Gate" block keep it font-independent.
    x = int(height * 1.15)
    bar_h = int(height * 0.10)
    draw.rounded_rectangle(
        (x, height * 0.34, x + width * 0.30, height * 0.34 + bar_h),
        radius=bar_h // 2,
        fill=LIME,
    )
    draw.rounded_rectangle(
        (x, height * 0.52, x + width * 0.22, height * 0.52 + bar_h),
        radius=bar_h // 2,
        fill=(255, 255, 255, 210),
    )
    return img


ANDROID_DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def main() -> None:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, "android", "app", "src", "main", "res")

    for density, px in ANDROID_DENSITIES.items():
        folder = os.path.join(res, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        build_icon(px, rounded=False).save(os.path.join(folder, "ic_launcher.png"))
        build_icon(px, rounded=True).save(os.path.join(folder, "ic_launcher_round.png"))
        build_foreground(int(px * 1.5)).save(
            os.path.join(folder, "ic_launcher_foreground.png")
        )
        print(f"  mipmap-{density}: {px}px")

    assets = os.path.join(root, "assets", "images")
    os.makedirs(assets, exist_ok=True)
    build_icon(1024, rounded=False).save(os.path.join(assets, "repgate_logo.png"))
    build_icon(512, rounded=False, transparent=True).save(
        os.path.join(assets, "repgate_mark.png")
    )
    build_wordmark().save(os.path.join(assets, "repgate_wordmark.png"))
    print("  assets/images: repgate_logo.png, repgate_mark.png, repgate_wordmark.png")


if __name__ == "__main__":
    main()

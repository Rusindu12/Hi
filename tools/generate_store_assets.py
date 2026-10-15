#!/usr/bin/env python3
"""Generates every raster store/pre-icon asset for SriEdu.

Pure standard library: a tiny PNG encoder (zlib + struct) plus a scanline
rasteriser, so the icons are reproducible on any machine with no pip installs and
no image-editing app. Sizes follow Google Play's asset guidelines exactly.

Outputs
  android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
  android/app/src/main/res/mipmap-{...}/ic_launcher_round.png
  store_assets/play_icon_512.png                     (Play listing icon)
  store_assets/feature_graphic_1024x500.png          (Play feature graphic)
  store_assets/adaptive_foreground_432.png           (Play adaptive-icon source)
  store_assets/promo_icon_preview.png                (contact sheet for review)

Run:  python3 tools/generate_store_assets.py
"""

from __future__ import annotations

import math
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
STORE = ROOT / "store_assets"
MIPMAPS = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

TEAL = (0x0F, 0x7B, 0x8A)
TEAL_LIGHT = (0x14, 0x91, 0x9B)
BLUE = (0x25, 0x63, 0xEB)
AMBER = (0xFB, 0xBF, 0x24)
WHITE = (0xFF, 0xFF, 0xFF)
PAPER = (0xE6, 0xF5, 0xF7)
CANVAS = (0xF5, 0xF8, 0xFB)


# ---------------------------------------------------------------------------
# Minimal RGBA canvas
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self, width: int, height: int, background: tuple[int, int, int] | None = None):
        self.w = width
        self.h = height
        # flat bytearray: 4 bytes per pixel, row-major
        if background is None:
            self.px = bytearray(width * height * 4)
        else:
            row = bytes(background) + b"\xff"
            self.px = bytearray(row * (width * height))

    def blend(self, x: int, y: int, color: tuple[int, int, int], alpha: float) -> None:
        if alpha <= 0 or x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        if alpha > 1:
            alpha = 1.0
        i = (y * self.w + x) * 4
        px = self.px
        inv = 1.0 - alpha
        px[i] = int(color[0] * alpha + px[i] * inv)
        px[i + 1] = int(color[1] * alpha + px[i + 1] * inv)
        px[i + 2] = int(color[2] * alpha + px[i + 2] * inv)
        px[i + 3] = max(px[i + 3], int(255 * alpha))

    def fill_polygon(self, points: list[tuple[float, float]], color: tuple[int, int, int], alpha: float = 1.0) -> None:
        """Scanline fill with 1x sampling; callers supersample for smoothness."""
        if len(points) < 3:
            return
        ys = [p[1] for p in points]
        y0 = max(0, int(math.floor(min(ys))))
        y1 = min(self.h - 1, int(math.ceil(max(ys))))
        n = len(points)
        for y in range(y0, y1 + 1):
            yc = y + 0.5
            xs: list[float] = []
            for i in range(n):
                xa, ya = points[i]
                xb, yb = points[(i + 1) % n]
                if ya == yb:
                    continue
                if (ya <= yc < yb) or (yb <= yc < ya):
                    t = (yc - ya) / (yb - ya)
                    xs.append(xa + t * (xb - xa))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                x_start = max(0, int(math.ceil(xs[i] - 0.5)))
                x_end = min(self.w - 1, int(math.floor(xs[i + 1] - 0.5)))
                for x in range(x_start, x_end + 1):
                    self.blend(x, y, color, alpha)

    def fill_circle(self, cx: float, cy: float, r: float, color: tuple[int, int, int], alpha: float = 1.0) -> None:
        y0 = max(0, int(cy - r))
        y1 = min(self.h - 1, int(cy + r))
        for y in range(y0, y1 + 1):
            dy = y + 0.5 - cy
            if abs(dy) > r:
                continue
            half = math.sqrt(max(0.0, r * r - dy * dy))
            x0 = max(0, int(cx - half))
            x1 = min(self.w - 1, int(cx + half))
            for x in range(x0, x1 + 1):
                self.blend(x, y, color, alpha)

    def fill_rect(self, x0: float, y0: float, x1: float, y1: float, color: tuple[int, int, int], alpha: float = 1.0) -> None:
        for y in range(max(0, int(y0)), min(self.h, int(math.ceil(y1)))):
            for x in range(max(0, int(x0)), min(self.w, int(math.ceil(x1)))):
                self.blend(x, y, color, alpha)

    def linear_gradient(self, c0: tuple[int, int, int], c1: tuple[int, int, int], diagonal: bool = True) -> None:
        for y in range(self.h):
            for x in range(self.w):
                t = ((x / max(1, self.w - 1)) + (y / max(1, self.h - 1))) / 2 if diagonal else x / max(1, self.w - 1)
                color = (
                    int(c0[0] + (c1[0] - c0[0]) * t),
                    int(c0[1] + (c1[1] - c0[1]) * t),
                    int(c0[2] + (c1[2] - c0[2]) * t),
                )
                self.blend(x, y, color, 1.0)

    def downscale(self, factor: int) -> "Canvas":
        out = Canvas(self.w // factor, self.h // factor)
        f2 = factor * factor
        for y in range(out.h):
            for x in range(out.w):
                r = g = b = a = 0
                for dy in range(factor):
                    for dx in range(factor):
                        i = ((y * factor + dy) * self.w + (x * factor + dx)) * 4
                        r += self.px[i]
                        g += self.px[i + 1]
                        b += self.px[i + 2]
                        a += self.px[i + 3]
                j = (y * out.w + x) * 4
                out.px[j] = r // f2
                out.px[j + 1] = g // f2
                out.px[j + 2] = b // f2
                out.px[j + 3] = a // f2
        return out

    def to_png(self) -> bytes:
        raw = bytearray()
        stride = self.w * 4
        for y in range(self.h):
            raw.append(0)  # filter type 0 (None)
            raw += self.px[y * stride : (y + 1) * stride]

        def chunk(tag: bytes, data: bytes) -> bytes:
            payload = tag + data
            return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)

        header = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        return (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b"")
        )


# ---------------------------------------------------------------------------
# Artwork
# ---------------------------------------------------------------------------
def rounded_square_mask(size: int, radius_ratio: float = 0.22) -> Canvas:
    """A canvas with only the rounded-square area opaque (legacy launcher icon)."""
    ss = 3
    big = Canvas(size * ss, size * ss)
    r = size * ss * radius_ratio
    # Fill the rounded square by combining two rects and four circles.
    big.fill_rect(r, 0, size * ss - r, size * ss, WHITE, 1.0)
    big.fill_rect(0, r, size * ss, size * ss - r, WHITE, 1.0)
    for cx, cy in (
        (r, r),
        (size * ss - r, r),
        (r, size * ss - r),
        (size * ss - r, size * ss - r),
    ):
        big.fill_circle(cx, cy, r, WHITE, 1.0)
    return big.downscale(ss)


def book_mark(c: Canvas, size: int, scale: float = 1.0, center: bool = True) -> None:
    """Draws the open-book + bookmark motif, sized relative to `size`."""
    s = size * scale
    ox = (size - s) / 2 if center else 0.0
    oy = (size - s) / 2 if center else 0.0

    def pt(x: float, y: float) -> tuple[float, float]:
        return (ox + x * s, oy + y * s)

    # Left page, right page, spine, bookmark.
    c.fill_polygon([pt(0.22, 0.33), pt(0.47, 0.29), pt(0.47, 0.71), pt(0.22, 0.75)], WHITE)
    c.fill_polygon([pt(0.78, 0.33), pt(0.53, 0.29), pt(0.53, 0.71), pt(0.78, 0.75)], PAPER)
    c.fill_polygon([pt(0.50, 0.30), pt(0.505, 0.295), pt(0.505, 0.715), pt(0.50, 0.71)], (0x0B, 0x64, 0x70))
    c.fill_polygon([pt(0.63, 0.30), pt(0.70, 0.21), pt(0.70, 0.33), pt(0.63, 0.36)], AMBER)


def icon(size: int, rounded: bool, supersample: int = 3) -> Canvas:
    """Full launcher icon: gradient background + book."""
    ss_size = size * supersample
    c = Canvas(ss_size, ss_size)
    c.linear_gradient(TEAL_LIGHT, BLUE)
    book_mark(c, ss_size, scale=1.0)
    big = c.downscale(supersample)

    if not rounded:
        return big
    # Apply the rounded mask.
    mask = rounded_square_mask(size)
    out = Canvas(size, size)
    for y in range(size):
        for x in range(size):
            i = (y * size + x) * 4
            a = mask.px[i + 3] / 255.0
            out.px[i] = big.px[i]
            out.px[i + 1] = big.px[i + 1]
            out.px[i + 2] = big.px[i + 2]
            out.px[i + 3] = int(big.px[i + 3] * a)
    return out


def adaptive_foreground(size: int = 432) -> Canvas:
    """Play Store adaptive-icon foreground: artwork inside the 66% safe zone."""
    ss = 2
    c = Canvas(size * ss, size * ss)
    book_mark(c, size * ss, scale=0.66)
    return c.downscale(ss)


def feature_graphic(width: int = 1024, height: int = 500) -> Canvas:
    """Play feature graphic.

    Text is intentionally omitted: rendering Sinhala/Tamil glyphs needs a font
    shaper, and a Latin-only graphic would look wrong next to a Sinhala title.
    The right third is left visually calm for the title you add in any editor,
    and the guidance is repeated in docs/PLAY_LISTING.md.
    """
    c = Canvas(width, height)
    c.linear_gradient(TEAL, BLUE)
    # Soft "page" panel on the left, book motif, and a streak flame.
    c.fill_polygon(
        [(0.06 * width, 0.22 * height), (0.40 * width, 0.18 * height),
         (0.40 * width, 0.80 * height), (0.06 * width, 0.84 * height)],
        (0xFF, 0xFF, 0xFF),
        0.14,
    )
    book_mark(c, int(height * 0.9), scale=0.72, center=False)
    # Flame, top-right of the motif block.
    fx, fy = int(width * 0.46), int(height * 0.30)
    c.fill_polygon(
        [(fx, fy - 70), (fx + 42, fy + 26), (fx, fy + 58), (fx - 42, fy + 26)],
        AMBER,
    )
    c.fill_circle(fx, fy + 22, 22, (0xF9, 0x73, 0x16))
    # Calm text zone on the right.
    for i, y in enumerate(range(int(height * 0.34), int(height * 0.62), 16)):
        c.fill_rect(width * 0.56, y, width * 0.92 - i * 8, y + 7, WHITE, 0.18)
    return c


def contact_sheet(images: list[tuple[str, Canvas]]) -> Canvas:
    """Small review sheet so the icons can be eyeballed in one file."""
    padding = 20
    label_h = 0
    width = padding + sum(img.w + padding for _, img in images)
    height = padding * 2 + max(img.h for _, img in images) + label_h
    sheet = Canvas(width, height, CANVAS)
    x = padding
    for _, img in images:
        for y in range(img.h):
            for ix in range(img.w):
                i = (y * img.w + ix) * 4
                sheet.blend(x + ix, padding + y, (img.px[i], img.px[i + 1], img.px[i + 2]), img.px[i + 3] / 255)
        x += img.w + padding
    return sheet


def write(path: pathlib.Path, canvas: Canvas) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = canvas.to_png()
    path.write_bytes(data)
    print(f"  {path.relative_to(ROOT)}  {canvas.w}x{canvas.h}  {len(data) / 1024:.0f} KB")


def main() -> int:
    print("Generating SriEdu icons and store assets…")
    preview: list[tuple[str, Canvas]] = []

    for density, size in MIPMAPS.items():
        square = icon(size, rounded=True, supersample=4 if size <= 96 else 2)
        round_icon = icon(size, rounded=False, supersample=4 if size <= 96 else 2)
        # Round variant: mask to a circle.
        masked = Canvas(size, size)
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - size / 2, y + 0.5 - size / 2
                if math.hypot(dx, dy) <= size / 2 - 0.5:
                    i = (y * size + x) * 4
                    masked.px[i : i + 4] = round_icon.px[i : i + 4]
        base = ROOT / "android" / "app" / "src" / "main" / "res" / f"mipmap-{density}"
        write(base / "ic_launcher.png", square)
        write(base / "ic_launcher_round.png", masked)
        if density == "xhdpi":
            preview.append(("square", square))
            preview.append(("round", masked))

    write(STORE / "play_icon_512.png", icon(512, rounded=False, supersample=2))
    write(STORE / "adaptive_foreground_432.png", adaptive_foreground(432))
    write(STORE / "feature_graphic_1024x500.png", feature_graphic())
    write(STORE / "promo_icon_preview.png", contact_sheet(preview))

    guide = STORE / "README.txt"
    guide.write_text(
        "Generated by tools/generate_store_assets.py — do not hand-edit.\n\n"
        "play_icon_512.png            512x512  Play listing icon (32-bit PNG, no alpha needed)\n"
        "adaptive_foreground_432.png  432x432  Play adaptive icon foreground (artwork inside 66% safe zone)\n"
        "feature_graphic_1024x500.png 1024x500 Play feature graphic (NO TEXT — add your own title)\n"
        "promo_icon_preview.png       contact sheet of the launcher icons for review\n\n"
        "Screenshots cannot be generated here: run the app on a device and capture\n"
        "them with `flutter screenshot` or `adb exec-out screencap -p > shot.png`.\n"
        "The required set and captions are listed in docs/PLAY_LISTING.md.\n",
        encoding="utf-8",
    )
    print(f"  wrote {guide.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

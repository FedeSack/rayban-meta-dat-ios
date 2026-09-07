#!/usr/bin/env python3
"""Generate placeholder Bobi Glasses AppIcon PNGs (no third-party deps)."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

# DatTheme / asset catalog brand colors. RGB only — App Store 1024 rejects alpha.
ACCENT = (0x00, 0x6C, 0xEB)
INK = (0xFF, 0xFF, 0xFF)

# iPhone sizes required for modern App Store / iOS 17+ plus the 1024 marketing icon.
# Includes 60pt@2x (120x120) — ITMS-90022.
ICON_SPECS: list[tuple[str, int, str, str]] = [
    # filename, pixel size, idiom slot (documented in Contents.json)
    ("AppIcon-20@2x.png", 40, "20x20", "2x"),
    ("AppIcon-20@3x.png", 60, "20x20", "3x"),
    ("AppIcon-29@2x.png", 58, "29x29", "2x"),
    ("AppIcon-29@3x.png", 87, "29x29", "3x"),
    ("AppIcon-40@2x.png", 80, "40x40", "2x"),
    ("AppIcon-40@3x.png", 120, "40x40", "3x"),
    ("AppIcon-60@2x.png", 120, "60x60", "2x"),
    ("AppIcon-60@3x.png", 180, "60x60", "3x"),
    ("AppIcon-1024.png", 1024, "1024x1024", "1x"),
]


def _png_chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_rgb_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    if len(pixels) != width * height * 3:
        raise ValueError(f"{path.name}: expected {width * height * 3} bytes, got {len(pixels)}")
    raw = bytearray()
    row = width * 3
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * row : (y + 1) * row])
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + _png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _png_chunk(b"IEND", b"")
    )


def _smooth(edge_norm: float, size: int) -> float:
    # 1 inside, 0 outside, ~1px antialias in pixel space.
    return max(0.0, min(1.0, 0.5 - edge_norm * size))


def _circle(px: float, py: float, cx: float, cy: float, radius: float, size: int) -> float:
    return _smooth(math.hypot(px - cx, py - cy) - radius, size)


def _capsule(px: float, py: float, x0: float, y0: float, x1: float, y1: float, radius: float, size: int) -> float:
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / (length * length)))
    return _circle(px, py, x0 + dx * t, y0 + dy * t, radius, size)


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(round(a[0] + (b[0] - a[0]) * t)),
        int(round(a[1] + (b[1] - a[1]) * t)),
        int(round(a[2] + (b[2] - a[2]) * t)),
    )


def render_icon(size: int) -> bytes:
    """Solid accent field + white glasses mark. No alpha."""
    out = bytearray(size * size * 3)
    # Geometry in normalized 0..1 space so every size stays readable.
    left = (0.33, 0.50)
    right = (0.67, 0.50)
    lens_r = 0.155
    rim = 0.038
    bridge_r = 0.028
    for y in range(size):
        py = (y + 0.5) / size
        row = y * size * 3
        for x in range(size):
            px = (x + 0.5) / size
            mark = max(
                _capsule(px, py, left[0], left[1], right[0], right[1], bridge_r, size),
                max(0.0, _circle(px, py, *left, lens_r, size) - _circle(px, py, *left, lens_r - rim, size)),
                max(0.0, _circle(px, py, *right, lens_r, size) - _circle(px, py, *right, lens_r - rim, size)),
            )
            r, g, b = _mix(ACCENT, INK, mark)
            i = row + x * 3
            out[i] = r
            out[i + 1] = g
            out[i + 2] = b
    return bytes(out)


def contents_json() -> str:
    images = []
    for filename, _pixels, size, scale in ICON_SPECS:
        if size == "1024x1024":
            images.append(
                {
                    "filename": filename,
                    "idiom": "ios-marketing",
                    "scale": scale,
                    "size": size,
                }
            )
        else:
            images.append(
                {
                    "filename": filename,
                    "idiom": "iphone",
                    "scale": scale,
                    "size": size,
                }
            )
    import json

    return json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"


def generate(dest: Path) -> None:
    dest.mkdir(parents=True, exist_ok=True)
    for filename, pixels, _size, _scale in ICON_SPECS:
        write_rgb_png(dest / filename, pixels, pixels, render_icon(pixels))
    (dest / "Contents.json").write_text(contents_json())


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dest = root / "GlassesDAT" / "GlassesDAT" / "Assets.xcassets" / "AppIcon.appiconset"
    generate(dest)
    print(f"wrote {len(ICON_SPECS)} AppIcon PNGs to {dest}")


if __name__ == "__main__":
    main()

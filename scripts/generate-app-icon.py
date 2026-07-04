#!/usr/bin/env python3
"""从源 PNG 生成 Codex Status Bar 的 macOS 应用图标。"""

from __future__ import annotations

import os
import subprocess
from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT / "assets"
SOURCE_PATH = ASSETS_DIR / "AppIcon.png"
ICONSET_DIR = ROOT / "build" / "AppIcon.iconset"
ICNS_PATH = ASSETS_DIR / "AppIcon.icns"
SIZES = [16, 32, 64, 128, 256, 512, 1024]


def is_background(pixel: tuple[int, int, int, int]) -> bool:
    """判断像素是否属于源图边缘的近白背景。"""
    red, green, blue, alpha = pixel
    return alpha > 0 and red >= 246 and green >= 246 and blue >= 246


def remove_connected_background(image: Image.Image) -> Image.Image:
    """仅移除与画布边缘连通的近白背景。"""
    image = image.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or not (0 <= x < width and 0 <= y < height):
            continue
        visited.add((x, y))
        if not is_background(pixels[x, y]):
            continue
        pixels[x, y] = (255, 255, 255, 0)
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    return image


def square_crop(image: Image.Image) -> Image.Image:
    """居中裁剪为正方形。"""
    width, height = image.size
    side = min(width, height)
    left = (width - side) // 2
    top = (height - side) // 2
    return image.crop((left, top, left + side, top + side))


def save_iconset() -> None:
    """生成 iconset PNG 文件和最终 icns 文件。"""
    if not SOURCE_PATH.exists():
        raise FileNotFoundError(f"missing source icon: {SOURCE_PATH}")

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)
    source = remove_connected_background(square_crop(Image.open(SOURCE_PATH)))

    for size in SIZES:
        icon = source.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(ICONSET_DIR / f"icon_{size}x{size}.png")
        if size <= 512:
            retina = source.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
            retina.save(ICONSET_DIR / f"icon_{size}x{size}@2x.png")

    subprocess.run(["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_PATH)], check=True)


def main() -> None:
    """脚本入口。"""
    os.chdir(ROOT)
    save_iconset()
    print(ICNS_PATH)


if __name__ == "__main__":
    main()

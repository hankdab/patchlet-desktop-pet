from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image

APP_DIR = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path(
    "/Users/apple/.codex/generated_images/019e0d1b-4697-7d71-87a4-f83a9a9c53ba/"
    "ig_0aff4dd49c45eda4016a07ccacd2048195a49c016cacd85773.png"
)
DEFAULT_OUT = APP_DIR / "assets" / "patchlet-edge-directions.png"
DEFAULT_CONTACT = Path("/tmp/patchlet-edge-directions-contact.png")
CELL_W = 208
CELL_H = 192
ROWS = 4
COLS = 8


def chroma_key(cell: Image.Image) -> Image.Image:
    pixels = cell.load()
    for y in range(cell.height):
        for x in range(cell.width):
            r, g, b, _ = pixels[x, y]
            if r > 150 and b > 130 and g < 105:
                pixels[x, y] = (0, 0, 0, 0)
    return cell


def is_sprite_pixel(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a == 0:
        return False
    return not (r > 150 and b > 130 and g < 105)


def extract_components(image: Image.Image) -> list[Image.Image]:
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    components: list[tuple[int, int, int, int, int]] = []

    for start_y in range(height):
        for start_x in range(width):
            index = start_y * width + start_x
            if visited[index] or not is_sprite_pixel(pixels[start_x, start_y]):
                continue

            visited[index] = 1
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            min_x = max_x = start_x
            min_y = max_y = start_y
            area = 0

            while queue:
                x, y = queue.popleft()
                area += 1
                min_x = min(min_x, x)
                max_x = max(max_x, x)
                min_y = min(min_y, y)
                max_y = max(max_y, y)

                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if nx < 0 or ny < 0 or nx >= width or ny >= height:
                        continue
                    nindex = ny * width + nx
                    if visited[nindex] or not is_sprite_pixel(pixels[nx, ny]):
                        continue
                    visited[nindex] = 1
                    queue.append((nx, ny))

            if area > 600:
                components.append((min_x, min_y, max_x + 1, max_y + 1, area))

    components = sorted(components, key=lambda item: item[4], reverse=True)[: ROWS * COLS]
    components = sorted(components, key=lambda item: (item[1] + item[3]) / 2)
    rows = [components[i * COLS : (i + 1) * COLS] for i in range(ROWS)]
    ordered: list[Image.Image] = []
    for row in rows:
        for left, top, right, bottom, _ in sorted(row, key=lambda item: (item[0] + item[2]) / 2):
            sprite = image.crop((left, top, right, bottom))
            ordered.append(chroma_key(sprite))
    if len(ordered) != ROWS * COLS:
        raise RuntimeError(f"Expected {ROWS * COLS} sprites, found {len(ordered)}")
    return ordered


def trim(im: Image.Image) -> Image.Image:
    bbox = im.getchannel("A").getbbox()
    if not bbox:
        return im
    pad = 1
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(im.width, bbox[2] + pad)
    bottom = min(im.height, bbox[3] + pad)
    return im.crop((left, top, right, bottom))


def remove_hairline(sprite: Image.Image, side: str) -> Image.Image:
    pixels = sprite.load()
    alpha = sprite.getchannel("A")
    width, height = sprite.size
    zone = range(max(0, width - 24), width) if side == "right" else range(0, min(24, width))

    for x in zone:
        count = sum(1 for y in range(height) if alpha.getpixel((x, y)) > 20)
        if count < 20:
            continue

        isolated = 0
        for y in range(height):
            if alpha.getpixel((x, y)) <= 20:
                continue
            left = alpha.getpixel((max(0, x - 4), y)) if x > 3 else 0
            right = alpha.getpixel((min(width - 1, x + 4), y)) if x < width - 4 else 0
            if left <= 20 and right <= 20:
                isolated += 1

        if isolated <= 14:
            continue

        for dx in (-1, 0, 1):
            xx = x + dx
            if not 0 <= xx < width:
                continue
            for y in range(height):
                if alpha.getpixel((xx, y)) <= 20:
                    continue
                r, g, b, _ = pixels[xx, y]
                if (r < 95 and g < 95 and b < 120) or (r > 80 and b > 90 and g < 50):
                    pixels[xx, y] = (0, 0, 0, 0)

    return trim(sprite)


def fit_sprite(sprite: Image.Image) -> Image.Image:
    max_w = CELL_W - 6
    max_h = CELL_H - 6
    scale = min(1.0, max_w / sprite.width, max_h / sprite.height)
    if scale >= 1.0:
        return sprite
    return sprite.resize((round(sprite.width * scale), round(sprite.height * scale)), Image.Resampling.LANCZOS)


def build_sheet(source: Path, out: Path, contact: Path) -> None:
    image = Image.open(source).convert("RGBA")
    sprites = extract_components(image)
    atlas = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0))
    preview = Image.new("RGBA", atlas.size, (255, 255, 255, 255))

    for row in range(ROWS):
        for col in range(COLS):
            side = "right" if row in (0, 1) else "left"
            sprite = sprites[row * COLS + col]
            sprite = fit_sprite(remove_hairline(trim(sprite), side))
            x = CELL_W - sprite.width if side == "right" else 0
            y = round((CELL_H - sprite.height) / 2)
            position = (col * CELL_W + x, row * CELL_H + y)
            atlas.alpha_composite(sprite, position)
            preview.alpha_composite(sprite, position)

    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out)
    preview.save(contact)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import image-generated edge direction frames.")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--contact", type=Path, default=DEFAULT_CONTACT)
    args = parser.parse_args()
    build_sheet(args.source, args.out, args.contact)
    print(args.out)
    print(args.contact)


if __name__ == "__main__":
    main()

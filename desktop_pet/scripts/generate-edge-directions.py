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
COLS = 12
BOB_OFFSETS = [0, -2, -4, -5, -3, -1, 0, 2, 4, 5, 3, 1]


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


def extract_row_components(image: Image.Image, expected: int = COLS) -> list[Image.Image]:
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

    components = sorted(components, key=lambda item: item[4], reverse=True)[:expected]
    if len(components) != expected:
        raise RuntimeError(f"Expected {expected} sprites in row source, found {len(components)}")
    ordered: list[Image.Image] = []
    for left, top, right, bottom, _ in sorted(components, key=lambda item: (item[0] + item[2]) / 2):
        ordered.append(chroma_key(image.crop((left, top, right, bottom))))
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

    def is_dark(px: tuple[int, int, int, int]) -> bool:
        r, g, b, a = px
        return a > 20 and ((r < 95 and g < 95 and b < 120) or (r > 80 and b > 90 and g < 50))

    def erase_vertical_runs(x: int) -> None:
        run: list[int] = []

        def flush() -> None:
            if len(run) < 14:
                return
            outer_x = min(width - 1, x + 3) if side == "right" else max(0, x - 3)
            outside_empty = sum(1 for y in run if alpha.getpixel((outer_x, y)) <= 20)
            if outside_empty / len(run) < 0.65:
                return
            for xx in (x - 1, x, x + 1):
                if not 0 <= xx < width:
                    continue
                for y in run:
                    if is_dark(pixels[xx, y]):
                        pixels[xx, y] = (0, 0, 0, 0)

        for y in range(height):
            if is_dark(pixels[x, y]):
                run.append(y)
                continue
            flush()
            run = []
        flush()

    for x in zone:
        opaque_ys = [y for y in range(height) if alpha.getpixel((x, y)) > 20]
        count = len(opaque_ys)
        if count < 20:
            erase_vertical_runs(x)
            continue

        isolated = 0
        for y in opaque_ys:
            left = alpha.getpixel((max(0, x - 4), y)) if x > 3 else 0
            right = alpha.getpixel((min(width - 1, x + 4), y)) if x < width - 4 else 0
            if left <= 20 and right <= 20:
                isolated += 1

        dark_count = sum(1 for y in opaque_ys if is_dark(pixels[x, y]))
        span = max(opaque_ys) - min(opaque_ys) + 1
        tall_dark_edge = dark_count >= 24 and span >= height * 0.38 and dark_count / max(1, count) >= 0.55
        if isolated <= 14 and not tall_dark_edge:
            continue

        for dx in (-1, 0, 1):
            xx = x + dx
            if not 0 <= xx < width:
                continue
            for y in range(height):
                if alpha.getpixel((xx, y)) <= 20:
                    continue
                if is_dark(pixels[xx, y]):
                    pixels[xx, y] = (0, 0, 0, 0)
        erase_vertical_runs(x)

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
    write_sheet(sprites, out, contact)


def build_sheet_from_rows(row_sources: list[Path], out: Path, contact: Path) -> None:
    if len(row_sources) != ROWS:
        raise RuntimeError(f"Expected {ROWS} row sources, got {len(row_sources)}")
    sprites: list[Image.Image] = []
    for source in row_sources:
        sprites.extend(extract_row_components(Image.open(source).convert("RGBA")))
    write_sheet(sprites, out, contact)


def write_sheet(sprites: list[Image.Image], out: Path, contact: Path) -> None:
    if len(sprites) != ROWS * COLS:
        raise RuntimeError(f"Expected {ROWS * COLS} sprites, got {len(sprites)}")
    atlas = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0))
    preview = Image.new("RGBA", atlas.size, (255, 255, 255, 255))

    for row in range(ROWS):
        for col in range(COLS):
            side = "right" if row in (0, 1) else "left"
            sprite = sprites[row * COLS + col]
            sprite = fit_sprite(remove_hairline(trim(sprite), side))
            x = CELL_W - sprite.width if side == "right" else 0
            y = round((CELL_H - sprite.height) / 2) + BOB_OFFSETS[col]
            y = max(0, min(CELL_H - sprite.height, y))
            position = (col * CELL_W + x, row * CELL_H + y)
            atlas.alpha_composite(sprite, position)
            preview.alpha_composite(sprite, position)

    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out)
    preview.save(contact)


def main() -> None:
    parser = argparse.ArgumentParser(description="Import image-generated edge direction frames.")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument(
        "--row-source",
        type=Path,
        action="append",
        default=[],
        help="Use four separate row strip images instead of one 4x8 source. Pass in row order.",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--contact", type=Path, default=DEFAULT_CONTACT)
    args = parser.parse_args()
    if args.row_source:
        build_sheet_from_rows(args.row_source, args.out, args.contact)
    else:
        build_sheet(args.source, args.out, args.contact)
    print(args.out)
    print(args.contact)


if __name__ == "__main__":
    main()

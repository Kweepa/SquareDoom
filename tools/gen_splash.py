#!/usr/bin/env python3
"""Pack splash/DOOM_05.png as split MCM splash PRGs using splash/palette.png.

PNG is 320×200 hires (2px = 1 MCM). Bitmap 00 / $d021 is black.
splashc.prg → $4000 matrix + colour staging (boot copies colour to $D800).
splash.prg  → $6000 bitmap, loaded after colour so it paints in already coloured.
Fails if a pixel is not in the palette, pairs differ, or a cell needs
more than 3 colours besides background.
"""
from __future__ import annotations

from collections import Counter
from pathlib import Path
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PNG = ROOT / "splash" / "DOOM_05.png"
PALETTE = ROOT / "splash" / "palette.png"
OUT_COL = ROOT / "splashc.prg"
OUT_BMP = ROOT / "splash.prg"
PREVIEW = ROOT / "tmp" / "splash_preview.png"

LOAD_COL = 0x4000
LOAD_BMP = 0x6000
COLS = 40
ROWS = 25
BG = 0
BITMAP_SIZE = 8000
SCR_SIZE = 1000


def load_palette(
	path: Path,
) -> tuple[dict[tuple[int, int, int], int], list[tuple[int, int, int]]]:
	im = Image.open(path).convert("RGB")
	w, h = im.size
	if (w, h) != (16, 1):
		raise SystemExit(f"{path.name} expected 16x1, got {w}x{h}")
	px = im.load()
	out: dict[tuple[int, int, int], int] = {}
	rgb: list[tuple[int, int, int]] = []
	for i in range(16):
		c = px[i, 0]
		if c in out:
			raise SystemExit(f"{path.name} duplicate colour {c}")
		out[c] = i
		rgb.append(c)
	return out, rgb


def load_bitmap(path: Path, pal: dict[tuple[int, int, int], int]) -> list[list[int]]:
	im = Image.open(path).convert("RGB")
	w, h = im.size
	if (w, h) != (320, 200):
		raise SystemExit(f"{path.name} expected 320x200, got {w}x{h}")
	px = im.load()
	src = [[0] * (w // 2) for _ in range(h)]
	for y in range(h):
		for mx in range(w // 2):
			a = px[mx * 2, y]
			b = px[mx * 2 + 1, y]
			if a != b:
				raise SystemExit(
					f"{path.name} unpaired hires pixels at ({mx * 2},{y}): {a} vs {b}"
				)
			if a not in pal:
				raise SystemExit(f"{path.name} unknown colour {a} at ({mx * 2},{y})")
			src[y][mx] = pal[a]
	return src


def pack_cell(pixels: list[int]) -> tuple[list[int], int, int]:
	extra = [c for c, _ in Counter(pixels).most_common() if c != BG]
	if len(extra) > 3:
		raise SystemExit(f"cell has {len(extra)} colours besides bg {BG}: {extra}")
	if len(set(pixels)) == 4 and BG not in pixels:
		raise SystemExit(f"4-colour cell missing bg {BG}: {set(pixels)}")
	slots = extra[:3]
	while len(slots) < 3:
		slots.append(0)
	pair = {BG: 0}
	for i, c in enumerate(slots):
		if c not in pair:
			pair[c] = i + 1
	rows = []
	for y in range(8):
		b = 0
		for x in range(4):
			b = (b << 2) | pair[pixels[y * 4 + x]]
		rows.append(b)
	scr = ((slots[0] & 15) << 4) | (slots[1] & 15)
	col = slots[2] & 15
	return rows, scr, col


def decode_preview(
	bmp: list[int],
	scr: list[int],
	col: list[int],
	rgb: list[tuple[int, int, int]],
	bg: int,
) -> Image.Image:
	im = Image.new("RGB", (COLS * 8, ROWS * 8), rgb[bg])
	pp = im.load()
	for cy in range(ROWS):
		for cx in range(COLS):
			cell = cy * COLS + cx
			lut = (bg, scr[cell] >> 4, scr[cell] & 15, col[cell] & 15)
			base = cy * 320 + cx * 8
			for y in range(8):
				b = bmp[base + y]
				for p in range(4):
					bits = (b >> (6 - p * 2)) & 3
					c = rgb[lut[bits]]
					xx = cx * 8 + p * 2
					yy = cy * 8 + y
					pp[xx, yy] = c
					pp[xx + 1, yy] = c
	return im


def main() -> None:
	pal, rgb = load_palette(PALETTE)
	grid = load_bitmap(PNG, pal)
	bmp = [0] * BITMAP_SIZE
	scr = [0] * SCR_SIZE
	col = [0] * SCR_SIZE
	for cy in range(ROWS):
		for cx in range(COLS):
			pix = []
			for y in range(8):
				pix.extend(grid[cy * 8 + y][cx * 4 : cx * 4 + 4])
			rows, s, c = pack_cell(pix)
			base = cy * 320 + cx * 8
			bmp[base : base + 8] = rows
			scr[cy * COLS + cx] = s
			col[cy * COLS + cx] = c

	col_data = bytes(scr) + bytes(col) + bytes([BG])
	OUT_COL.write_bytes(struct.pack("<H", LOAD_COL) + col_data)
	OUT_BMP.write_bytes(struct.pack("<H", LOAD_BMP) + bytes(bmp))
	PREVIEW.parent.mkdir(parents=True, exist_ok=True)
	decode_preview(bmp, scr, col, rgb, BG).save(PREVIEW)
	print(f"wrote {OUT_COL.relative_to(ROOT)} load=${LOAD_COL:04x} data={len(col_data)}")
	print(f"wrote {OUT_BMP.relative_to(ROOT)} load=${LOAD_BMP:04x} data={len(bmp)}")
	print(f"wrote {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
	main()

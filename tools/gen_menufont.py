#!/usr/bin/env python3
"""Build tmp/menufont.asm from doommenufont.png (64x96, ASCII 32–127)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PNG = ROOT / "doommenufont.png"
ASM_OUT = ROOT / "tmp" / "menufont.asm"


def fmt(g: list[int]) -> str:
	return ",".join(f"${b:02x}" for b in g)


def glyph_from_png(px, col: int, row: int) -> list[int]:
	out = []
	for y in range(8):
		b = 0
		for x in range(8):
			if px[col * 8 + x, row * 8 + y] > 0:
				b |= 0x80 >> x
		out.append(b)
	return out


def main() -> None:
	im = Image.open(PNG)
	if im.size != (64, 96):
		raise SystemExit(f"doommenufont.png expected 64x96, got {im.size}")
	px = im.load()
	ascii_glyphs = {
		32 + i: glyph_from_png(px, i % 8, i // 8) for i in range(96)
	}
	ASM_OUT.parent.mkdir(parents=True, exist_ok=True)
	lines = [
		"; Auto-generated from doommenufont.png by tools/gen_menufont.py",
		"!zone menufont",
		"menufont_udgs",
	]
	for ch in range(32, 128):
		g = ascii_glyphs[ch]
		note = "space" if ch == 32 else repr(chr(ch))
		lines.append(f"\t!byte {fmt(g)}\t; {ch} {note}")
	ASM_OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
	print(f"wrote {ASM_OUT.relative_to(ROOT)}")


if __name__ == "__main__":
	main()

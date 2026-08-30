#!/usr/bin/env python3
"""Build tmp/menu_text.asm from control/credits/order/ending/readthis txt files.

credits.txt / order.txt / readthis.txt / ending.txt are split into screens
on lines that are only '^'. control.txt keeps inline ^ as monospaced spans.

Story lines are wrapped 16px earlier than a full-width panel so dark-grey
shows left and right of the white box. Widths match menu.asm left-justify
(including `--` : second hyphen 1px left).
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tmp" / "menu_text.asm"
FONT_PNG = ROOT / "doommenufont.png"
CREDITS = ROOT / "credits.txt"
ORDER = ROOT / "order.txt"
READTHIS = ROOT / "readthis.txt"
ENDING = ROOT / "ending.txt"

SCREENS = (
	("control_text", ROOT / "control.txt"),
)

FONT_GAP = 1
SPACE_W = 4
BOX_PAD = 2
# 16px sooner than a full-width panel (280) → grey margins L/R
MAX_TEXT_PIX = 40 * 8 - BOX_PAD * 8 * 2 - 8 - 16  # 264
# 25 rows - 8 brand - 2 vgaps
MAX_PAGE_LINES = 25 - 8 - 2  # 15


def esc_scr(s: str) -> str:
	return s.replace("\\", "\\\\").replace('"', '\\"')


def _glyph_w_from_rows(rows: list[int]) -> int:
	occ = 0
	for b in rows:
		occ |= b
	if occ == 0:
		return SPACE_W
	lead = 0
	while lead < 8 and (occ & 0x80) == 0:
		occ = (occ << 1) & 0xFF
		lead += 1
	w = 0
	while occ:
		w += 1
		occ = (occ << 1) & 0xFF
	return w


def load_glyph_widths() -> list[int]:
	"""Match gen_menufont.py (un-mirror) + menu.asm font_scan / SPACE_W."""
	im = Image.open(FONT_PNG)
	if im.size != (64, 96):
		raise SystemExit(f"doommenufont.png expected 64x96, got {im.size}")
	px = im.load()
	widths = []
	for i in range(96):
		col, row = i % 8, i // 8
		rows = []
		for y in range(8):
			b = 0
			for x in range(8):
				if px[col * 8 + x, row * 8 + y] > 0:
					b |= 0x80 >> x
			rows.append(b)
		widths.append(_glyph_w_from_rows(rows))
	return widths


def _char_w(ch: str, widths: list[int], mono: bool) -> int:
	if mono:
		return 8
	idx = ord(ch) - 32
	if 0 <= idx < 96:
		w = widths[idx]
		return (SPACE_W if w == 0 else w) + FONT_GAP
	return SPACE_W + FONT_GAP


def line_pix(s: str, widths: list[int], marked: bool) -> int:
	n = 0
	mono = False
	prev = ""
	for ch in s:
		if marked and ch == "^":
			if not mono:
				# snap to next cell, matching pix_snap_len
				n = (n + 7) & ~7
			mono = not mono
			prev = ""
			continue
		w = _char_w(ch, widths, mono)
		if not mono and ch == "-" and prev == "-":
			w -= 1
		n += w
		prev = ch if not mono else ""
	return n


def _hard_break(word: str, widths: list[int], marked: bool, max_pix: int) -> list[str]:
	out: list[str] = []
	cur = ""
	for ch in word:
		trial = cur + ch
		if cur and line_pix(trial, widths, marked) > max_pix:
			out.append(cur)
			cur = ch
		else:
			cur = trial
	if cur:
		out.append(cur)
	return out or [word]


def wrap_line(s: str, widths: list[int], marked: bool = False, max_pix: int = MAX_TEXT_PIX) -> list[str]:
	if line_pix(s, widths, marked) <= max_pix:
		return [s] if s else [" "]
	words = s.split(" ")
	out: list[str] = []
	cur = ""
	for w in words:
		if not cur:
			trial = w
		else:
			trial = cur + " " + w
		if line_pix(trial, widths, marked) <= max_pix:
			cur = trial
			continue
		if cur:
			out.append(cur)
		if line_pix(w, widths, marked) <= max_pix:
			cur = w
			continue
		hunks = _hard_break(w, widths, marked, max_pix)
		out.extend(hunks[:-1])
		cur = hunks[-1] if hunks else ""
	if cur:
		out.append(cur)
	return out or [" "]


def join_paragraphs(lines: list[str]) -> list[str]:
	"""Collapse continuation lines; blank lines stay as paragraph breaks."""
	out: list[str] = []
	buf: list[str] = []

	def flush() -> None:
		if buf:
			out.append(" ".join(x.strip() for x in buf if x.strip()))
			buf.clear()

	for line in lines:
		if not line.strip():
			flush()
			out.append(" ")
		else:
			buf.append(line)
	flush()
	return out


def wrap_page(lines: list[str], widths: list[int], marked: bool = False, join: bool = True) -> list[str]:
	src = join_paragraphs(lines) if join else lines
	out: list[str] = []
	for line in src:
		out.extend(wrap_line(line, widths, marked=marked))
	return out


def split_overlong_pages(pages: list[list[str]]) -> list[list[str]]:
	out: list[list[str]] = []
	for p in pages:
		for i in range(0, len(p), MAX_PAGE_LINES):
			chunk = p[i : i + MAX_PAGE_LINES]
			if chunk:
				out.append(chunk)
	return out


def emit_blob_lines(label: str, lines: list[str]) -> list[str]:
	while lines and not lines[-1].strip():
		lines = lines[:-1]
	out = [f"{label}"]
	for line in lines:
		body = line if line.strip() else " "
		out.append(f'\t!scr "{esc_scr(body)}",0')
	out.append("\t!byte 0")
	out.append("")
	return out


def emit_blob(label: str, path: Path, widths: list[int]) -> list[str]:
	raw = path.read_text(encoding="utf-8").splitlines()
	return emit_blob_lines(label, wrap_page(raw, widths, marked=True, join=False))


def split_caret_pages(text: str) -> list[list[str]]:
	pages: list[list[str]] = []
	cur: list[str] = []
	for line in text.splitlines():
		if line.strip() == "^":
			pages.append(cur)
			cur = []
		else:
			cur.append(line)
	pages.append(cur)
	cleaned: list[list[str]] = []
	for p in pages:
		while p and not p[0].strip():
			p = p[1:]
		while p and not p[-1].strip():
			p = p[:-1]
		if p:
			cleaned.append(p)
	return cleaned


def emit_caret_pages(
	path: Path, prefix: str, count_sym: str, lo_sym: str, hi_sym: str, widths: list[int]
) -> list[str]:
	if not path.is_file():
		raise SystemExit(f"missing {path}")
	pages = split_caret_pages(path.read_text(encoding="utf-8"))
	pages = [wrap_page(p, widths, marked=False) for p in pages]
	pages = split_overlong_pages(pages)
	if not pages:
		raise SystemExit(f"{path.name} has no screens")
	if len(pages) > 255:
		raise SystemExit(f"{path.name} has {len(pages)} screens; max 255")
	out: list[str] = [f"{count_sym} = {len(pages)}", ""]
	labels = [f"{prefix}{i}_text" for i in range(1, len(pages) + 1)]
	for label, lines in zip(labels, pages):
		out.extend(emit_blob_lines(label, lines))
	out.append(lo_sym)
	out.append("\t!byte " + ", ".join(f"<{n}" for n in labels))
	out.append(hi_sym)
	out.append("\t!byte " + ", ".join(f">{n}" for n in labels))
	out.append("")
	return out


def main() -> None:
	widths = load_glyph_widths()
	out: list[str] = [
		"; Auto-generated by tools/gen_menu_text.py — edit *.txt in repo root",
		"; credits/order/readthis/ending pages split on lines that are only '^'",
		"; long lines wrapped to the 40-column hires panel",
		"",
	]
	for label, path in SCREENS:
		if not path.is_file():
			raise SystemExit(f"missing {path}")
		out.extend(emit_blob(label, path, widths))
	out.extend(emit_caret_pages(ORDER, "order", "ORDER_PAGES", "order_lo", "order_hi", widths))
	out.extend(emit_caret_pages(CREDITS, "credits", "CREDITS_PAGES", "credits_lo", "credits_hi", widths))
	out.extend(
		emit_caret_pages(READTHIS, "readthis", "READTHIS_PAGES", "readthis_lo", "readthis_hi", widths)
	)
	out.extend(emit_caret_pages(ENDING, "ending", "ENDING_PAGES", "ending_lo", "ending_hi", widths))
	OUT.parent.mkdir(parents=True, exist_ok=True)
	OUT.write_text("\n".join(out) + "\n", encoding="utf-8")
	print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
	main()

#!/usr/bin/env python3
"""Carve ACME's $0400–$D000 game.prg into code + high (skip the $8E00 Krill gap)."""
from __future__ import annotations

import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game.prg"
LBL = ROOT / "squaredoom.lbl"
HIGH = ROOT / "high.prg"

LOCODE_BASE = 0x0400
MEM_LEVEL = 0x9000
HIGH_END = 0xD000  # VIC_SPRITES + SPRITE_HEAD


def lbl_addr(name: str) -> int:
    pat = re.compile(rf"^al C:([0-9a-fA-F]+)\s+\.{re.escape(name)}\s*$")
    for line in LBL.read_text(encoding="utf-8", errors="replace").splitlines():
        m = pat.match(line)
        if m:
            return int(m.group(1), 16)
    raise SystemExit(f"{LBL.name}: missing label {name}")


def main() -> None:
    if not GAME.is_file():
        raise SystemExit(f"missing {GAME}")
    if not LBL.is_file():
        raise SystemExit(f"missing {LBL}")

    raw = GAME.read_bytes()
    if len(raw) < 2:
        raise SystemExit("game.prg too small")
    load = int.from_bytes(raw[:2], "little")
    body = raw[2:]
    if load != LOCODE_BASE:
        raise SystemExit(f"game.prg load ${load:04x}, expected ${LOCODE_BASE:04x}")

    end_code = lbl_addr("end_code")
    loadraw = lbl_addr("loadraw")
    if end_code > loadraw:
        raise SystemExit(f"end_code ${end_code:04x} overlaps Krill ${loadraw:04x}")
    if end_code < load:
        raise SystemExit(f"end_code ${end_code:04x} before load ${load:04x}")

    img_end = load + len(body)
    if img_end < HIGH_END:
        raise SystemExit(f"game.prg ends at ${img_end:04x}, need ${HIGH_END:04x}")

    def slice_abs(start: int, end: int) -> bytes:
        return body[start - load : end - load]

    code = slice_abs(LOCODE_BASE, end_code)
    high = slice_abs(MEM_LEVEL, HIGH_END)
    GAME.write_bytes(struct.pack("<H", LOCODE_BASE) + code)
    HIGH.write_bytes(struct.pack("<H", MEM_LEVEL) + high)
    print(
        f"split game.prg ${LOCODE_BASE:04x}–${end_code:04x} ({len(code)} B), "
        f"high.prg ${MEM_LEVEL:04x}–${HIGH_END:04x} ({len(high)} B)"
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Validate ACME game.prg is one CPU image $0400 through py_tab. No high.prg."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game.prg"
LBL = ROOT / "squaredoom.lbl"

LOCODE_BASE = 0x0400
MEM_LEVEL = 0x96E0
PY_TAB = 0xAC00
PY_TAB_SIZE = 12 * 256
GAME_END = PY_TAB + PY_TAB_SIZE  # $B800, flush under SQTAB


def lbl_addr(lbl_path: Path, name: str) -> int | None:
    pat = re.compile(rf"^al C:([0-9a-fA-F]+)\s+\.{re.escape(name)}\s*$")
    for line in lbl_path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = pat.match(line)
        if m:
            return int(m.group(1), 16)
    return None


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Validate game.prg is $0400 through py_tab (no high.prg)"
    )
    ap.add_argument("--lbl", type=Path, default=LBL, help="VICE labels (default squaredoom.lbl)")
    args = ap.parse_args()
    lbl_path = args.lbl

    if not GAME.is_file():
        raise SystemExit(f"missing {GAME}")
    if not lbl_path.is_file():
        raise SystemExit(f"missing {lbl_path}")

    raw = GAME.read_bytes()
    if len(raw) < 2:
        raise SystemExit("game.prg too small")
    load = int.from_bytes(raw[:2], "little")
    body = raw[2:]
    if load != LOCODE_BASE:
        raise SystemExit(f"game.prg load ${load:04x}, expected ${LOCODE_BASE:04x}")

    end_code = lbl_addr(lbl_path, "end_code")
    if end_code is None:
        raise SystemExit(f"{lbl_path.name}: missing label end_code")
    mem_level = lbl_addr(lbl_path, "MEM_LEVEL")
    if mem_level is None:
        mem_level = MEM_LEVEL
    py_tab = lbl_addr(lbl_path, "PY_TAB")
    if py_tab is None:
        py_tab = PY_TAB
    game_end = py_tab + PY_TAB_SIZE

    if end_code > mem_level:
        raise SystemExit(f"end_code ${end_code:04x} overlaps MEM_LEVEL ${mem_level:04x}")
    if end_code < load:
        raise SystemExit(f"end_code ${end_code:04x} before load ${load:04x}")

    img_end = load + len(body)
    if img_end != game_end:
        raise SystemExit(
            f"game.prg ends at ${img_end:04x}, expected ${game_end:04x} (py_tab end)"
        )
    if img_end > 0xC000:
        raise SystemExit(f"game.prg covers ${img_end:04x}; must stay below $C000 (Krill $C400)")

    print(
        f"game.prg ${LOCODE_BASE:04x}–${img_end:04x} ({len(body)} B), "
        f"end_code ${end_code:04x}, locode slack {mem_level - end_code} B"
    )


if __name__ == "__main__":
    main()

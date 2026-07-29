#!/usr/bin/env python3
"""Build squaredoom.d64 from squaredoom.prg, levels/e1m*.bin, and UI screens."""

import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import List, Optional, Tuple

DEFAULT_VICE_BIN = Path(r"c:\app\vice3.10\bin")
LEVEL_LOAD_ADDR = 0xA000
UI_LOAD_ADDR = 0xC800
LEVEL_NAME_RE = re.compile(r"^(e\dm\d)\.bin$", re.IGNORECASE)

# (dos_name, relative path under screens/, kind: "bin" raw or "prg" with header)
UI_FILES = [
    ("logo", "logo.bin", "bin"),
    ("cred", "cred.prg", "prg"),
    ("help", "help.prg", "prg"),
    ("ordr", "ordr.prg", "prg"),
    ("endg", "endg.prg", "prg"),
]


def find_c1541(explicit: Optional[Path] = None) -> Optional[Path]:
    if explicit is not None:
        p = explicit
        return p if p.is_file() else None
    env = os.environ.get("VICE_BIN")
    if env:
        for name in ("c1541.exe", "c1541"):
            p = Path(env) / name
            if p.is_file():
                return p
    for name in ("c1541.exe", "c1541"):
        p = DEFAULT_VICE_BIN / name
        if p.is_file():
            return p
    w = shutil.which("c1541")
    return Path(w) if w else None


def collect_levels(level_dir: Path) -> List[Tuple[str, Path]]:
    levels: List[Tuple[str, Path]] = []
    for p in sorted(level_dir.iterdir()):
        if not p.is_file():
            continue
        m = LEVEL_NAME_RE.match(p.name)
        if m:
            # Lowercase for c1541 cmdline → PETSCII letters (same as JSW r00).
            # Uppercase ASCII becomes shifted PETSCII and shows as junk (-1\1).
            levels.append((m.group(1).lower(), p))
    return levels


def stage_ui(screens_dir: Path, tmp_dir: Path) -> List[Tuple[str, Path]]:
    staged: List[Tuple[str, Path]] = []
    for dos_name, rel, kind in UI_FILES:
        src = screens_dir / rel
        if not src.is_file():
            print(f"missing UI screen: {src}", file=sys.stderr)
            sys.exit(1)
        out = tmp_dir / dos_name
        if kind == "bin":
            out.write_bytes(struct.pack("<H", UI_LOAD_ADDR) + src.read_bytes())
        else:
            # ACME cbm PRG already has load address
            out.write_bytes(src.read_bytes())
        staged.append((dos_name, out))
    return staged


def main() -> None:
    ap = argparse.ArgumentParser(description="Build squaredoom.d64 via c1541")
    ap.add_argument("--out", default="squaredoom.d64")
    ap.add_argument("--prg", default="squaredoom.prg")
    ap.add_argument("--levels", default="levels", help="directory with e1mN.bin files")
    ap.add_argument(
        "--screens",
        default="screens",
        help="directory with logo.bin and cred/help/ordr/endg.prg",
    )
    ap.add_argument(
        "--c1541",
        type=Path,
        default=None,
        help=f"path to c1541 (default: {DEFAULT_VICE_BIN}\\c1541.exe or PATH)",
    )
    args = ap.parse_args()

    c1541 = find_c1541(args.c1541)
    if not c1541:
        print(
            "c1541 not found. Install VICE or set VICE_BIN / --c1541.",
            file=sys.stderr,
        )
        sys.exit(1)

    prg = Path(args.prg)
    if not prg.is_file():
        print(f"missing PRG: {prg}", file=sys.stderr)
        sys.exit(1)

    levels = collect_levels(Path(args.levels))
    if not levels:
        print(f"no eNmN.bin files in {args.levels}", file=sys.stderr)
        sys.exit(1)

    d64 = Path(args.out)

    with tempfile.TemporaryDirectory(prefix="sd_disk_") as tmp:
        tmp_dir = Path(tmp)
        staged: List[Tuple[str, Path]] = []
        for dos_name, bin_path in levels:
            payload = bin_path.read_bytes()
            prg_path = tmp_dir / dos_name
            prg_path.write_bytes(struct.pack("<H", LEVEL_LOAD_ADDR) + payload)
            staged.append((dos_name, prg_path))

        ui_staged = stage_ui(Path(args.screens), tmp_dir)
        staged.extend(ui_staged)

        # Format creates/overwrites the image (no prior unlink — VICE may hold the file)
        cmd = [
            str(c1541),
            "-format",
            "squaredoom,01",
            "d64",
            str(d64),
            "-attach",
            str(d64),
            "-write",
            str(prg),
            "squaredoom",
        ]
        for dos_name, path in staged:
            cmd.extend(["-write", str(path), f"{dos_name},p"])
        subprocess.check_call(cmd)

    print(
        f"Wrote {d64} via {c1541} ({len(levels)} levels, {len(ui_staged)} UI screens)"
    )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build squaredoom.d64: boot (autostart name squaredoom), splash colour+bitmap, krill, menu, gfx, game, high, levels.

krill/loader.prg and krill/install.prg are prebuilt Krill v194 binaries (see
krill/README.md). Boot KERNAL-loads SPLASHC then SPLASH first (cover paints
in colour during the bitmap load, stays up through INSTALL), then
LOADER+INSTALL, JSR install, and every later load is loadraw.
GAME is code only; HIGH is $9000–$D000.
"""

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

LEVEL_LOAD_ADDR = 0x9000
LEVEL_BYTES = 3473
LEVEL_NAME_RE = re.compile(r"^(e\dm\d)\.bin$", re.IGNORECASE)

# (dos_name, path relative to repo root). Splash colour then bitmap after boot
# so the KERNAL-load of the cover is sequential; INSTALL still sits before MENU
# overwrites the $2000 installer RAM.
DISK_PRGS = [
	("splashc", "splashc.prg"),
	("splash", "splash.prg"),
	("loader", "krill/loader.prg"),
	("install", "krill/install.prg"),
	("menu", "menu.prg"),
	("gfx", "gfx.prg"),
	("game", "game.prg"),
	("high", "high.prg"),
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
			levels.append((m.group(1).lower(), p))
	return levels


def stage_level(dos_name: str, bin_path: Path, tmp_dir: Path) -> Tuple[str, Path]:
	"""PRG @ $9000 = cooked level blob only."""
	level = bin_path.read_bytes()
	if len(level) != LEVEL_BYTES:
		print(
			f"warning: {bin_path.name} is {len(level)} bytes (expected {LEVEL_BYTES})",
			file=sys.stderr,
		)
	out = tmp_dir / dos_name
	out.write_bytes(struct.pack("<H", LEVEL_LOAD_ADDR) + level)
	return dos_name, out


def main() -> None:
	ap = argparse.ArgumentParser(description="Build squaredoom.d64 via c1541")
	ap.add_argument("--out", default="squaredoom.d64")
	ap.add_argument("--boot", default="boot.prg")
	ap.add_argument("--levels", default="levels", help="directory with e1mN.bin files")
	ap.add_argument(
		"--c1541",
		type=Path,
		default=None,
		help="path to c1541 (default: VICE_BIN env or PATH)",
	)
	args = ap.parse_args()

	c1541 = find_c1541(args.c1541)
	if not c1541:
		print(
			"c1541 not found. Install VICE or set VICE_BIN in setup-env.bat / --c1541.",
			file=sys.stderr,
		)
		sys.exit(1)

	root = Path(__file__).resolve().parent.parent
	boot = Path(args.boot)
	if not boot.is_file():
		print(f"missing boot PRG: {boot}", file=sys.stderr)
		sys.exit(1)

	for dos_name, rel in DISK_PRGS:
		p = root / rel
		if not p.is_file():
			print(f"missing PRG: {p}", file=sys.stderr)
			sys.exit(1)

	levels = collect_levels(Path(args.levels))
	if not levels:
		print(f"no eNmN.bin files in {args.levels}", file=sys.stderr)
		sys.exit(1)

	d64 = Path(args.out)

	with tempfile.TemporaryDirectory(prefix="sd_disk_") as tmp:
		tmp_dir = Path(tmp)
		staged: List[Tuple[str, Path]] = []
		for dos_name, rel in DISK_PRGS:
			staged.append((dos_name, root / rel))
		for dos_name, bin_path in levels:
			staged.append(stage_level(dos_name, bin_path, tmp_dir))

		cmd = [
			str(c1541),
			"-format",
			"squaredoom,01",
			"d64",
			str(d64),
			"-attach",
			str(d64),
			"-write",
			str(boot),
			"squaredoom",
		]
		for dos_name, path in staged:
			cmd.extend(["-write", str(path), f"{dos_name},p"])
		subprocess.check_call(cmd)

	print(
		f"Wrote {d64} via {c1541} (boot + krill + {len(DISK_PRGS) - 2} prgs, {len(levels)} levels)"
	)


if __name__ == "__main__":
	main()

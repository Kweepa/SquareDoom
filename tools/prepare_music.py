#!/usr/bin/env python3
"""Relocate a PSID to $9000 and return a 4K payload (no PRG header).

Uses sidreloc (SIDRELOC env or PATH). Keeps original ZP ($f0-$f7 for current
SidTracker exports) via -k so music does not collide with game ZP at $80+.

SidTracker tunes (author contains \"SidTracker\") get voice-3 mute + D417/D418
shadow redirects. Last byte of the 4K window is a flag for the game
($9FFF = 1 → use shadow merge after MUSIC_PLAY).
"""

from __future__ import annotations

import argparse
import os
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Optional, Tuple

SID_LOAD_ADDR = 0x9000
SID_SIZE = 0x1000
SID_PAGE = f"{SID_LOAD_ADDR >> 8:02x}"  # "90"
# Last byte of music window: 1 = SidTracker (shadow D417/D418)
MUSIC_FLAG_SIDTRACKER = 1

# SID voice 3 registers (freq…SR) — music must not write these
V3_REG_LO = 0xD40E
V3_REG_HI = 0xD414
# Redirect filter/volume writes here (readable scrap; game merges after play).
# Avoid $0314–$0333 (KERNAL soft vectors: IRQ/BRK/NMI). Hardware NMI is
# $FFFA → nmi_stub; soft NMI at $0318 must stay a real vector, not SID data.
SID_FILT_SHADOW = 0x02F8  # was $D417
SID_VOL_SHADOW = 0x02F9  # was $D418
# Absolute store opcodes with 16-bit operand
_ABS_STORE_OPS = {
	0x8D,  # STA abs
	0x9D,  # STA abs,X
	0x99,  # STA abs,Y
	0x8E,  # STX abs
	0x8C,  # STY abs
}
NOP = 0xEA


def find_sidreloc(explicit: Optional[Path] = None) -> Optional[Path]:
	if explicit is not None:
		return explicit if explicit.is_file() else None
	env = os.environ.get("SIDRELOC")
	if env:
		p = Path(env)
		if p.is_file():
			return p
	for name in ("sidreloc.exe", "sidreloc"):
		w = shutil.which(name)
		if w:
			return Path(w)
	return None


def is_sidtracker_psid(data: bytes) -> bool:
	"""True if PSID author field mentions SidTracker (SidTracker64 exports)."""
	if len(data) < 86 or data[0:4] not in (b"PSID", b"RSID"):
		return False
	author = data[54:86].split(b"\x00", 1)[0]
	return b"sidtracker" in author.lower()


def parse_psid_payload(data: bytes) -> tuple[int, int, int, bytes]:
	"""Return (load, init, play, raw_payload) from a PSID file."""
	if len(data) < 0x7C or data[0:4] not in (b"PSID", b"RSID"):
		raise ValueError("not a PSID/RSID file")
	version = struct.unpack(">H", data[4:6])[0]
	data_off = struct.unpack(">H", data[6:8])[0]
	load = struct.unpack(">H", data[8:10])[0]
	init = struct.unpack(">H", data[10:12])[0]
	play = struct.unpack(">H", data[12:14])[0]
	if version < 2 or data_off < 0x76:
		raise ValueError(f"unsupported PSID version/offset ({version}, ${data_off:04x})")
	body = data[data_off:]
	if load == 0:
		if len(body) < 2:
			raise ValueError("SID data too short for embedded load address")
		load = struct.unpack("<H", body[0:2])[0]
		payload = body[2:]
	else:
		payload = body
	if init == 0:
		init = load
	return load, init, play, payload


def mute_sid_voice3(payload: bytes, label: str = "") -> bytes:
	"""NOP music writes to SID voice 3; shadow $D417/$D418 to scrap.

	1. Absolute STA/STX/STY to $D40E–$D414 → three NOPs each.
	2. SidTracker ``LDX #$0E`` / ``JSR`` or ``JMP`` voice-update → five NOPs.
	3. Absolute stores to $D417/$D418 → same opcode storing $02F8/$02F9
	   (game merges filter modes + volume after MUSIC_PLAY).
	"""
	data = bytearray(payload)
	n_abs = 0
	n_call = 0
	n_shadow = 0
	i = 0
	while i < len(data) - 2:
		op = data[i]
		# SidTracker: LDX #$0E / JSR abs  or  LDX #$0E / JMP abs
		if (
			i + 4 < len(data)
			and data[i] == 0xA2
			and data[i + 1] == 0x0E
			and data[i + 2] in (0x20, 0x4C)
		):
			data[i : i + 5] = bytes([NOP] * 5)
			n_call += 1
			i += 5
			continue
		if op in _ABS_STORE_OPS:
			addr = data[i + 1] | (data[i + 2] << 8)
			if V3_REG_LO <= addr <= V3_REG_HI:
				data[i : i + 3] = bytes([NOP] * 3)
				n_abs += 1
				i += 3
				continue
			if addr == 0xD417:
				data[i + 1] = SID_FILT_SHADOW & 0xFF
				data[i + 2] = SID_FILT_SHADOW >> 8
				n_shadow += 1
				i += 3
				continue
			if addr == 0xD418:
				data[i + 1] = SID_VOL_SHADOW & 0xFF
				data[i + 2] = SID_VOL_SHADOW >> 8
				n_shadow += 1
				i += 3
				continue
		i += 1

	tag = f"{label}: " if label else ""
	print(
		f"  {tag}muted voice 3: {n_abs} abs store(s), {n_call} LDX #$0E call(s); "
		f"shadowed D417/D418: {n_shadow}",
		file=sys.stderr,
	)
	if n_abs == 0 and n_call == 0:
		print(
			f"  {tag}warning: no voice-3 stores/calls found — unexpected SidTracker shape?",
			file=sys.stderr,
		)
	if n_shadow == 0:
		print(
			f"  {tag}warning: no D417/D418 stores redirected — filter/vol merge may fail",
			file=sys.stderr,
		)
	return bytes(data)


def relocate_sid(
	src: Path,
	sidreloc: Path,
	dest_page: str = SID_PAGE,
) -> Tuple[bytes, bool]:
	"""Run sidreloc; optionally SidTracker-patch. Returns (payload, is_sidtracker)."""
	src_bytes = src.read_bytes()
	sidtracker = is_sidtracker_psid(src_bytes)
	author = ""
	if len(src_bytes) >= 86:
		author = src_bytes[54:86].split(b"\x00", 1)[0].decode("latin-1", errors="replace")

	with tempfile.TemporaryDirectory(prefix="sd_sid_") as tmp:
		out = Path(tmp) / "reloc.sid"
		cmd = [
			str(sidreloc),
			"-k",  # keep SidTracker ZP ($f0-$f7); avoid default $80-$ff clash
			"-q",  # silence expected CIA timer write during init
			"-p",
			dest_page,
			str(src),
			str(out),
		]
		proc = subprocess.run(cmd, capture_output=True, text=True)
		# Win32 sidreloc often exits 32 even when it prints "Relocation successful."
		ok_msg = "Relocation successful" in ((proc.stderr or "") + (proc.stdout or ""))
		if (proc.returncode not in (0, 32) and not ok_msg) or not out.is_file():
			msg = (proc.stderr or proc.stdout or "").strip() or f"exit {proc.returncode}"
			raise RuntimeError(f"sidreloc failed on {src.name}: {msg}")
		if not ok_msg and proc.returncode != 0:
			msg = (proc.stderr or proc.stdout or "").strip() or f"exit {proc.returncode}"
			raise RuntimeError(f"sidreloc failed on {src.name}: {msg}")
		load, init, play, payload = parse_psid_payload(out.read_bytes())
		if load != SID_LOAD_ADDR:
			raise RuntimeError(
				f"sidreloc produced load ${load:04x}, expected ${SID_LOAD_ADDR:04x}"
			)
		# Reserve 1 byte at end of 4K window for SidTracker flag
		if len(payload) > SID_SIZE - 1:
			raise RuntimeError(
				f"{src.name}: relocated payload {len(payload)} bytes exceeds "
				f"{SID_SIZE - 1} (need 1 byte for music flags)"
			)
		# Stamp expected API for callers (init/play after reloc)
		if init != SID_LOAD_ADDR or play != SID_LOAD_ADDR + 3:
			print(
				f"note: {src.name} init=${init:04x} play=${play:04x} "
				f"(game calls ${SID_LOAD_ADDR:04x} / ${SID_LOAD_ADDR + 3:04x})",
				file=sys.stderr,
			)
		if sidtracker:
			print(
				f"  {src.name}: SidTracker ({author!r}) — voice3 mute + D417/D418 shadow",
				file=sys.stderr,
			)
			payload = mute_sid_voice3(payload, label=src.name)
		else:
			print(
				f"  {src.name}: non-SidTracker ({author!r}) — no voice3/shadow patch",
				file=sys.stderr,
			)
		return payload, sidtracker


def pad_sid_window(payload: bytes, sidtracker: bool = False) -> bytes:
	"""Pad to 4K; last byte = MUSIC_FLAG_SIDTRACKER if sidtracker else 0."""
	if len(payload) > SID_SIZE - 1:
		raise ValueError(f"payload {len(payload)} > {SID_SIZE - 1}")
	flag = MUSIC_FLAG_SIDTRACKER if sidtracker else 0
	return payload + bytes(SID_SIZE - 1 - len(payload)) + bytes([flag])


def resolve_level_sid(music_dir: Path, level_name: str, fallback: str = "e1m1") -> Path:
	"""music/e1mN.sid if present, else music/e1m1.sid."""
	cand = music_dir / f"{level_name}.sid"
	if cand.is_file():
		return cand
	fb = music_dir / f"{fallback}.sid"
	if fb.is_file():
		return fb
	raise FileNotFoundError(
		f"no music for {level_name} and missing fallback {fb}"
	)


def main() -> None:
	ap = argparse.ArgumentParser(description="Relocate SID to $9000 4K payload")
	ap.add_argument("sid", type=Path, help="input .sid (PSID)")
	ap.add_argument(
		"-o",
		"--output",
		type=Path,
		required=True,
		help="output raw 4K bin (no load header)",
	)
	ap.add_argument(
		"--sidreloc",
		type=Path,
		default=None,
		help="path to sidreloc (default: SIDRELOC env or PATH)",
	)
	args = ap.parse_args()

	sidreloc = find_sidreloc(args.sidreloc)
	if not sidreloc:
		print(
			"sidreloc not found. Install sidreloc or set SIDRELOC in setup-env.bat.",
			file=sys.stderr,
		)
		sys.exit(1)
	if not args.sid.is_file():
		print(f"missing SID: {args.sid}", file=sys.stderr)
		sys.exit(1)

	try:
		raw, sidtracker = relocate_sid(args.sid, sidreloc)
		payload = pad_sid_window(raw, sidtracker=sidtracker)
	except (ValueError, RuntimeError) as e:
		print(str(e), file=sys.stderr)
		sys.exit(1)

	args.output.write_bytes(payload)
	print(
		f"Wrote {args.output} ({len(payload)} bytes @ ${SID_LOAD_ADDR:04x}, "
		f"sidtracker={int(sidtracker)})"
	)


if __name__ == "__main__":
	main()

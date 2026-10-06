#!/usr/bin/env python3
"""Menu music: mkmusic/*.sid → mus1.prg, mus2.prg (load @ $9000).

SidTracker64 player, CIA-timed (init programs $dc04/05; the rate differs per
tune, 25..48 Hz). Both share one player layout: $9000 init, $9003 play,
ZP $f0-$f7, and a single `sta $d418` at $9057 that runs every tick with the
tune's filter-mode nibble ($0f / $1f).

Patch: that store becomes `jsr vol_stub`, which keeps the high nibble
(filter mode) and replaces the volume nibble with effects_vol ($02FD), the
Options audio row (menu music and in-game effects). Flags and A are preserved.
The stub is appended after each tune; every image ends below $A000.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Quake64 mkmusic tracks 2 and 5. Jukebox lists them as Track 1 and Track 2.
TRACKS = (
    "MK_DOOM_21_REFERENCE.sid",
    "MK_DOOM_5_REFERENCE.sid",
)

LOAD = 0x9000
INIT = 0x9000
PLAY = 0x9003
LIMIT = 0xA000
VOL_STORE = 0x9057  # STA $D418
EFFECTS_VOL = 0x02FD


def die(msg: str) -> None:
    print(f"genmusic: {msg}", file=sys.stderr)
    sys.exit(1)


def convert(src: Path, out: Path) -> int:
    d = src.read_bytes()
    if d[:4] != b"PSID":
        die(f"{src.name}: not a PSID")
    _ver, off, load, init, play = struct.unpack(">HHHHH", d[4:14])
    body = bytearray(d[off:])
    if load == 0:
        load = body[0] | body[1] << 8
        del body[:2]
    if (load, init, play) != (LOAD, INIT, PLAY):
        die(f"{src.name}: want load/init/play ${LOAD:04X}/${INIT:04X}/${PLAY:04X}, "
            f"got ${load:04X}/${init:04X}/${play:04X}")

    i = VOL_STORE - LOAD
    if bytes(body[i:i + 3]) != b"\x8d\x18\xd4":
        die(f"{src.name}: ${VOL_STORE:04X} is not STA $D418 ({body[i:i + 3].hex()})")
    if body.count(b"\x8d\x18\xd4") != 1:
        die(f"{src.name}: more than one STA $D418 byte pattern")

    stub = LOAD + len(body)
    body[i:i + 3] = bytes((0x20, stub & 0xFF, stub >> 8))
    body += bytes((
        0x08,                               # php
        0x48,                               # pha
        0x29, 0xF0,                         # and #$f0
        0x0D, EFFECTS_VOL & 0xFF, EFFECTS_VOL >> 8,  # ora effects_vol
        0x8D, 0x18, 0xD4,                   # sta $d418
        0x68,                               # pla
        0x28,                               # plp
        0x60,                               # rts
    ))

    end = LOAD + len(body)
    if end > LIMIT:
        die(f"{out.name} ends ${end:04X}, past ${LIMIT:04X}")
    out.write_bytes(bytes((LOAD & 0xFF, LOAD >> 8)) + bytes(body))
    return end - 1


def main() -> None:
    for n, name in enumerate(TRACKS, 1):
        out = ROOT / f"mus{n}.prg"
        last = convert(ROOT / "mkmusic" / name, out)
        print(f"genmusic: {out.name} ${LOAD:04X}-${last:04X} <- {name}")


if __name__ == "__main__":
    main()

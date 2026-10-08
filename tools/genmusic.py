#!/usr/bin/env python3
"""Menu music: four tunes → mus1.prg .. mus4.prg (load @ $9000).

SidTracker64 (mkmusic/): CIA-timed. init programs $dc04/05; the rate differs
per tune (25..48 Hz). Shared layout: $9000 init, $9003 play, ZP $f0-$f7, and
a single `sta $d418` at $9057 that runs every tick with the tune's filter-mode
nibble. That store becomes `jsr vol_stub`, which keeps the high nibble and
replaces the volume nibble with effects_vol ($02FD).

Nordischsound (music/At_Dooms_Gate_E1M1.sid): 50 Hz player at $1000. sidreloc
-p 90 -k moves it to $9000/$9003. It does not write the CIA timer (the menu
loads the ~50 Hz latch after init). Each tick pokes the filter mode into the
immediate of `lda #$00 / ora #$0f / sta $d418`. The `ora #$0f / sta $d418`
becomes `jsr vol_stub`, which keeps that high nibble and ORs effects_vol.

Every image ends below $A000.
"""

from __future__ import annotations

import struct
import subprocess
import sys
import tempfile
from pathlib import Path

from prepare_music import find_sidreloc, parse_psid_payload

ROOT = Path(__file__).resolve().parents[1]

# Jukebox: Track 1, Track 2, Track 3, then At Doom's Gate.
SIDTRACKER = (
    "MK_DOOM_21_REFERENCE.sid",
    "MK_DOOM_5_REFERENCE.sid",
    "e1m1.sid",
)
NORDISCH = "At_Dooms_Gate_E1M1.sid"

LOAD = 0x9000
INIT = 0x9000
PLAY = 0x9003
LIMIT = 0xA000
VOL_STORE = 0x9057  # STA $D418
EFFECTS_VOL = 0x02FD
# lda #$00 / ora #$0f / sta $d418. The immediate at +1 is poked every tick.
NORDISCH_VOL = bytes((0xA9, 0x00, 0x09, 0x0F, 0x8D, 0x18, 0xD4))


def die(msg: str) -> None:
    print(f"genmusic: {msg}", file=sys.stderr)
    sys.exit(1)


def write_prg(out: Path, body: bytes) -> int:
    end = LOAD + len(body)
    if end > LIMIT:
        die(f"{out.name} ends ${end:04X}, past ${LIMIT:04X}")
    out.write_bytes(bytes((LOAD & 0xFF, LOAD >> 8)) + body)
    return end - 1


def convert_sidtracker(src: Path, out: Path) -> int:
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
    return write_prg(out, bytes(body))


def convert_nordisch(src: Path, out: Path) -> int:
    sidreloc = find_sidreloc()
    if sidreloc is None:
        die("sidreloc not found. Set SIDRELOC in setup-env.bat")
    with tempfile.TemporaryDirectory(prefix="sd_menu_sid_") as tmp:
        reloc = Path(tmp) / "reloc.sid"
        cmd = [str(sidreloc), "-k", "-q", "-p", "90", str(src), str(reloc)]
        proc = subprocess.run(cmd, capture_output=True, text=True)
        ok_msg = "Relocation successful" in ((proc.stderr or "") + (proc.stdout or ""))
        if (proc.returncode not in (0, 32) and not ok_msg) or not reloc.is_file():
            msg = (proc.stderr or proc.stdout or "").strip() or f"exit {proc.returncode}"
            die(f"sidreloc failed on {src.name}: {msg}")
        if not ok_msg and proc.returncode != 0:
            msg = (proc.stderr or proc.stdout or "").strip() or f"exit {proc.returncode}"
            die(f"sidreloc failed on {src.name}: {msg}")
        load, init, play, payload = parse_psid_payload(reloc.read_bytes())
    if (load, init, play) != (LOAD, INIT, PLAY):
        die(f"{src.name}: after sidreloc want ${LOAD:04X}/${INIT:04X}/${PLAY:04X}, "
            f"got ${load:04X}/${init:04X}/${play:04X}")
    body = bytearray(payload)
    i = body.find(NORDISCH_VOL)
    if i < 0 or body.find(NORDISCH_VOL, i + 1) >= 0:
        die(f"{src.name}: expected one volume sequence, found "
            f"{body.count(NORDISCH_VOL)}")
    # Leave `lda #imm` so the player's sta to that immediate still sets the
    # filter nibble. ora #$0f / sta $d418 (5 bytes) → jsr stub / nop nop.
    stub = LOAD + len(body)
    body[i + 2 : i + 7] = bytes((0x20, stub & 0xFF, stub >> 8, 0xEA, 0xEA))
    body += bytes((
        0x29, 0xF0,                         # and #$f0
        0x0D, EFFECTS_VOL & 0xFF, EFFECTS_VOL >> 8,  # ora effects_vol
        0x8D, 0x18, 0xD4,                   # sta $d418
        0x60,                               # rts
    ))
    return write_prg(out, bytes(body))


def main() -> None:
    n = 1
    for name in SIDTRACKER:
        out = ROOT / f"mus{n}.prg"
        last = convert_sidtracker(ROOT / "mkmusic" / name, out)
        print(f"genmusic: {out.name} ${LOAD:04X}-${last:04X} <- {name}")
        n += 1
    out = ROOT / f"mus{n}.prg"
    last = convert_nordisch(ROOT / "music" / NORDISCH, out)
    print(f"genmusic: {out.name} ${LOAD:04X}-${last:04X} <- {NORDISCH}")


if __name__ == "__main__":
    main()

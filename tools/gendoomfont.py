"""Convert VicDoom doomfont.s → ACME doomfont.asm (glyphs 0–63)."""
import argparse
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Convert VicDoom doomfont.s → ACME doomfont.asm"
    )
    ap.add_argument(
        "src",
        type=Path,
        help="path to VicDoom doomfont.s",
    )
    ap.add_argument(
        "--dst",
        type=Path,
        default=ROOT / "doomfont.asm",
        help="output doomfont.asm (default: repo doomfont.asm)",
    )
    ap.add_argument(
        "--png-src",
        type=Path,
        default=None,
        help="optional doomfont.png to copy alongside",
    )
    ap.add_argument(
        "--png-dst",
        type=Path,
        default=ROOT / "doomfont.png",
        help="destination for --png-src (default: repo doomfont.png)",
    )
    args = ap.parse_args()

    text = args.src.read_text()
    bytes_ = []
    for m in re.finditer(r"\.byte\s+(.+)", text):
        for p in m.group(1).split(","):
            p = p.strip()
            if p.startswith("$"):
                bytes_.append(int(p[1:], 16))
            else:
                bytes_.append(int(p, 0))

    assert len(bytes_) >= 512, len(bytes_)
    lines = [
        "; Auto-converted from VicDoom doomfont.s — first 64 glyphs (0-63)",
        "; Health=/ (47), armor=30, key=; (59), digits=48-57, pistol=38",
        "!zone doomfont",
        "doomfont_udgs",
    ]
    for i in range(0, 512, 8):
        chunk = bytes_[i : i + 8]
        hexes = ",".join(f"${b:02x}" for b in chunk)
        lines.append(f"\t!byte {hexes}\t; char {i // 8}")

    args.dst.write_text("\n".join(lines) + "\n")
    print(f"wrote {args.dst} ({512} bytes of glyphs)")

    if args.png_src is not None:
        shutil.copy(args.png_src, args.png_dst)
        print(f"copied {args.png_dst}")


if __name__ == "__main__":
    main()

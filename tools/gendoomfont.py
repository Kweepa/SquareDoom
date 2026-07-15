"""Convert VicDoom doomfont.s → ACME doomfont.asm (glyphs 0–63)."""
import re
import shutil
from pathlib import Path

src = Path(r"C:\Users\Steve\Desktop\Stuff2\dev\vicdoom-master\doomfont.s")
dst = Path(r"c:\dev\SquareDoom\doomfont.asm")
png_src = Path(r"C:\Users\Steve\Desktop\Stuff2\dev\vicdoom-master\doomfont.png")
png_dst = Path(r"c:\dev\SquareDoom\doomfont.png")

text = src.read_text()
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

dst.write_text("\n".join(lines) + "\n")
shutil.copy(png_src, png_dst)
print(f"wrote {dst} ({512} bytes of glyphs)")
print(f"copied {png_dst}")

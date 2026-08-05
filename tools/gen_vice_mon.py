#!/usr/bin/env python3
"""Write tmp/vice.mon — load VICE labels for make.bat -moncommands."""
from pathlib import Path

root = Path(__file__).resolve().parent.parent
lbl = root / "squaredoom.lbl"
mon = root / "tmp" / "vice.mon"
if not lbl.is_file():
	raise SystemExit(f"missing {lbl}")
mon.parent.mkdir(parents=True, exist_ok=True)
# Forward slashes — VICE moncommands tolerates them on Windows
mon.write_text(f'll "{lbl.as_posix()}"\n', encoding="ascii")
print(f"Wrote {mon}")

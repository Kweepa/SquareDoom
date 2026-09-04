#!/usr/bin/env python3
"""Print locode slack (MEM_LEVEL − end_code) from a VICE label file."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def lbl_addr(path: Path, name: str) -> int | None:
    pat = re.compile(rf"^al C:([0-9a-fA-F]+)\s+\.{re.escape(name)}\s*$")
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = pat.match(line)
        if m:
            return int(m.group(1), 16)
    return None


def _tag(path: Path) -> str:
    return "Krill" if "krill" in path.stem.lower() else "KERNAL"


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("squaredoom.lbl")
    if not path.is_file():
        raise SystemExit(f"missing {path}")

    end_code = lbl_addr(path, "end_code")
    limit = lbl_addr(path, "MEM_CODE_LIMIT")
    if end_code is None:
        raise SystemExit(f"{path.name}: missing label end_code")
    if limit is None:
        raise SystemExit(f"{path.name}: missing label MEM_CODE_LIMIT")

    free = limit - end_code
    if free < 0:
        raise SystemExit(
            f"Code overlaps limit at ${limit:04x}; overshoot={-free}"
        )
    print(f"Locode slack ({_tag(path)}): {free} bytes")


if __name__ == "__main__":
    main()

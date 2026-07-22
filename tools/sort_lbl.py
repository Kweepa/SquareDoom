#!/usr/bin/env python3
"""Sort ACME --vicelabels output by address; drop empty/invalid names."""

from __future__ import annotations

import re
import sys
from pathlib import Path

# VICE ll rejects bare "." and non-ASCII junk (e.g. UTF-8 BOM as a label).
_VALID_NAME = re.compile(r"\.[A-Za-z_][A-Za-z0-9_]*$")


def _keep(line: str) -> bool:
    parts = line.split()
    return len(parts) >= 3 and bool(_VALID_NAME.fullmatch(parts[2]))


def sort_lbl(path: Path) -> None:
    lines = [
        line
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.strip() and _keep(line)
    ]

    def key(line: str) -> int:
        parts = line.split()
        if len(parts) >= 2 and parts[1].startswith("C:"):
            return int(parts[1][2:], 16)
        return -1

    path.write_text("\n".join(sorted(lines, key=key)) + "\n", encoding="utf-8")


def main() -> None:
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("squaredoom.lbl")
    if not path.is_file():
        raise SystemExit(f"missing {path}")
    sort_lbl(path)


if __name__ == "__main__":
    main()

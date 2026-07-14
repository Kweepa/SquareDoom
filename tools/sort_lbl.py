#!/usr/bin/env python3
"""Sort ACME --vicelabels output by address."""

from __future__ import annotations

import sys
from pathlib import Path


def sort_lbl(path: Path) -> None:
    lines = [line for line in path.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]

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

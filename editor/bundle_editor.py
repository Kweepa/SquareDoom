#!/usr/bin/env python3
"""Bundle the map editor into a single self-contained HTML file (no server)."""

from __future__ import annotations

import base64
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "index.html"

JS_ORDER = [
    "js/model.js",
    "js/io.js",
    "js/mapView.js",
    "js/previewView.js",
    "js/tileEditor.js",
    "js/itemEditor.js",
    "js/itemPalette.js",
    "js/levelList.js",
    "js/shiftControls.js",
    "js/main.js",
]


def strip_module(src: str) -> str:
    src = re.sub(r"^import\s[\s\S]*?;\s*\n", "", src, flags=re.M)
    lines = []
    for line in src.splitlines():
        line = re.sub(r"^export\s+default\s+", "", line)
        line = re.sub(r"^export\s+", "", line)
        lines.append(line)
    return "\n".join(lines)


def wrap_top_level_await(src: str) -> str:
    marker = "const images = await loadImages();"
    if marker not in src:
        raise SystemExit("await loadImages marker not found")
    pre, post = src.split(marker, 1)
    return (
        pre
        + "(async () => {\nconst images = await loadImages();"
        + post
        + "\n})().catch((err) => {\n  console.error(err);\n  setStatus(String(err.message || err), true);\n});\n"
    )


def main() -> None:
    css = (ROOT / "styles.css").read_text(encoding="utf-8")

    image_data = {}
    for p in sorted((ROOT / "itemgraphics").glob("*.png")):
        image_data[p.stem] = "data:image/png;base64," + base64.b64encode(p.read_bytes()).decode(
            "ascii"
        )

    parts = []
    for rel in JS_ORDER:
        raw = (ROOT / rel).read_text(encoding="utf-8")
        stripped = strip_module(raw)
        if rel.endswith("main.js"):
            stripped = wrap_top_level_await(stripped)
        parts.append(f"// ---- {rel} ----\n{stripped}")

    js = "\n\n".join(parts)
    js = f"const ITEM_IMAGE_DATA = {json.dumps(image_data, indent=2)};\n\n" + js

    spawn_icon = image_data.get("spawn")
    favicon_link = (
        f'  <link rel="icon" type="image/png" href="{spawn_icon}" />\n' if spawn_icon else ""
    )

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>SquareDoom Map Editor</title>
{favicon_link}  <style>
{css}
  </style>
</head>
<body>
  <header class="toolbar">
    <h1>SquareDoom</h1>
    <div class="toolbar-actions">
      <button type="button" id="btn-undo" title="Ctrl+Z" disabled>Undo</button>
      <button type="button" id="btn-redo" title="Ctrl+Y" disabled>Redo</button>
      <button type="button" id="btn-save">Save</button>
      <button type="button" id="btn-load">Load</button>
      <button type="button" id="btn-cook">Cook</button>
    </div>
    <p id="status" class="status" role="status"></p>
  </header>

  <main class="layout">
    <aside class="left">
      <section id="level-list"></section>
      <section>
        <h2>Items</h2>
        <div id="item-palette"></div>
      </section>
    </aside>

    <section class="center">
      <h2>Map <span id="map-level-label"></span></h2>
      <div class="map-stage" id="map-stage">
        <canvas id="map-canvas" tabindex="0"></canvas>
      </div>
      <p class="hint">
        Drag box select · Ctrl+drag add · Click select · Shift+click empty · Shift+Alt overwrite · Del clears · Ctrl+Z/Y undo/redo
      </p>
    </section>

    <aside class="right">
      <div class="right-editors">
        <div id="tile-editor"></div>
        <div id="item-editor"></div>
      </div>
      <div id="preview-panel" class="preview-panel panel">
        <h2>Camera preview</h2>
        <div class="preview-frame">
          <canvas id="preview-canvas" tabindex="0"></canvas>
        </div>
        <p class="muted" id="preview-hint">Place or select a camera</p>
      </div>
      <div id="shift-controls"></div>
    </aside>
  </main>

  <script>
{js}
  </script>
</body>
</html>
"""
    OUT.write_text(html, encoding="utf-8")
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()

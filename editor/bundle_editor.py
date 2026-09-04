#!/usr/bin/env python3
"""Bundle the map editor into a single self-contained HTML file (no server)."""

from __future__ import annotations

import base64
import io
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
OUT = ROOT / "index.html"
GAME_GFX = REPO / "itemgraphics"
EDITOR_GFX = ROOT / "itemgraphics"

# Keep monochrome/editor icons for viewpoints + enemies (no game item atlases).
KEEP_EDITOR_ICONS = frozenset(
    {
        "spawn",
        "camera",
        "soldier",
        "imp",
        "pinky",
        "caco",
        "baron",
        "cursor",
        "acid",
    }
)

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


def png_data_url(raw: bytes) -> str:
    return "data:image/png;base64," + base64.b64encode(raw).decode("ascii")


def game_atlas_icon_png(path: Path) -> bytes:
    """Embed mip0 (left 8×8 of a 12×8 atlas), or the full image if smaller."""
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if w >= 8 and h >= 8:
        img = img.crop((0, 0, 8, 8))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def collect_item_images() -> dict[str, str]:
    """Editor icons for spawn/enemies/camera; game itemgraphics mip0 for props."""
    image_data: dict[str, str] = {}
    if EDITOR_GFX.is_dir():
        for p in sorted(EDITOR_GFX.glob("*.png")):
            image_data[p.stem] = png_data_url(p.read_bytes())
    if GAME_GFX.is_dir():
        for p in sorted(GAME_GFX.glob("*.png")):
            if p.stem in KEEP_EDITOR_ICONS:
                continue
            image_data[p.stem] = png_data_url(game_atlas_icon_png(p))
    return image_data


def main() -> None:
    css = (ROOT / "styles.css").read_text(encoding="utf-8")
    image_data = collect_item_images()

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
    props = sorted(k for k in image_data if k not in KEEP_EDITOR_ICONS)
    print(f"  game-atlas icons: {len(props)}  editor-kept: {sorted(KEEP_EDITOR_ICONS & image_data.keys())}")


if __name__ == "__main__":
    main()

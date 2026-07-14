import {
  EDITOR_ITEM_TYPES,
  CAMERA_TYPE,
  MAP_SIZE,
  WORLD_PER_TILE,
  WORLD_MAX,
  activeLevel,
  addItem,
  addTile,
  applyTilePatch,
  clearTiles,
  createEpisode,
  defaultSkills,
  findPreviewCamera,
  gameItemCount,
  getTileProps,
  hasSpawn,
  isCamera,
  moveItemsBy,
  moveTiles,
  nudgeTileHeights,
  occupiedTiles,
  parseTileKey,
  removeItem,
  sectorCount,
  shiftLevel,
  tileKey,
  tilesInSector,
  clampWorld,
  itemsInTiles,
  MAX_ITEMS,
} from './model.js?v=24';
import { MapView } from './mapView.js?v=24';
import { ItemPalette } from './itemPalette.js?v=24';
import { LevelList } from './levelList.js?v=24';
import { TileEditor } from './tileEditor.js?v=24';
import { ItemEditor } from './itemEditor.js?v=24';
import { PreviewView } from './previewView.js?v=28';
import { initShiftControls } from './shiftControls.js?v=24';
import { cookAndDownload, fetchEpisodeJSON, loadEpisodeJSON, saveEpisodeJSON } from './io.js?v=24';

const statusEl = document.getElementById('status');
const titleEl = document.querySelector('.toolbar h1');
const AUTOSAVE_MS = 10000;
const EPISODE_FILE = 'episode1.json';

let dirty = false;
let autosaveTimer = null;
let saving = false;

function setStatus(msg, isError = false) {
  statusEl.textContent = msg || '';
  statusEl.classList.toggle('error', isError);
}

function updateDirtyIndicator() {
  const star = dirty ? '*' : '';
  if (titleEl) titleEl.textContent = `SquareDoom${star}`;
  document.title = dirty ? 'SquareDoom *' : 'SquareDoom Map Editor';
}

function markDirty() {
  if (!dirty) {
    dirty = true;
    updateDirtyIndicator();
  }
  scheduleAutosave();
}

function markClean() {
  dirty = false;
  updateDirtyIndicator();
  if (autosaveTimer) {
    clearTimeout(autosaveTimer);
    autosaveTimer = null;
  }
}

function scheduleAutosave() {
  if (autosaveTimer) clearTimeout(autosaveTimer);
  autosaveTimer = setTimeout(() => {
    autosaveTimer = null;
    void runAutosave();
  }, AUTOSAVE_MS);
}

async function runAutosave() {
  if (!dirty || saving) return;
  await saveNow('Autosaved');
}

async function saveNow(okMsg = 'Saved') {
  if (saving) return;
  saving = true;
  setStatus('Saving…');
  try {
    const how = await saveEpisodeJSON(episode, EPISODE_FILE);
    if (how == null) {
      setStatus('Save cancelled', true);
    } else {
      markClean();
      setStatus(`${okMsg} ${EPISODE_FILE}`);
    }
  } catch (err) {
    setStatus(String(err.message || err), true);
  } finally {
    saving = false;
  }
}

async function loadImages() {
  /** @type {Record<string, HTMLImageElement>} */
  const images = {};
  await Promise.all(
    EDITOR_ITEM_TYPES.map(
      (type) =>
        new Promise((resolve) => {
          const img = new Image();
          img.src = `itemgraphics/${type}.png`;
          img.onload = () => {
            images[type] = img;
            resolve();
          };
          img.onerror = () => resolve();
        }),
    ),
  );
  return images;
}

const episode = createEpisode();

/** @type {{
 *   tiles: Set<string>,
 *   items: Set<any>,
 *   primaryTile: {tx:number,ty:number}|null,
 *   hoverTile: {tx:number,ty:number}|null,
 * }} */
const selection = {
  tiles: new Set(),
  items: new Set(),
  primaryTile: null,
  hoverTile: null,
  box: null,
};

/** @type {null | {
 *   mode: 'items' | 'box',
 *   lastTx: number,
 *   lastTy: number,
 *   lastWx: number,
 *   lastWy: number,
 *   additive?: boolean,
 *   startTx?: number,
 *   startTy?: number,
 *   startPx?: number,
 *   startPy?: number,
 *   moved?: boolean,
 *   baseTiles?: Set<string>,
 * }} */
let drag = null;

const images = await loadImages();

const levelList = new LevelList(document.getElementById('level-list'), {
  getActive: () => episode.activeLevel,
  onSelect: (name) => {
    episode.activeLevel = name;
    clearSelection();
    refreshAll();
  },
});

new ItemPalette(document.getElementById('item-palette'), images);

const tileEditor = new TileEditor(document.getElementById('tile-editor'), {
  getTiles: () => [...selection.tiles].map(parseTileKey),
  getProps: () => {
    const level = activeLevel(episode);
    return [...selection.tiles]
      .map(parseTileKey)
      .map(({ tx, ty }) => getTileProps(level, tx, ty))
      .filter(Boolean);
  },
  sectorCount: () => sectorCount(activeLevel(episode)),
  onChange: (patch) => {
    const level = activeLevel(episode);
    const tiles = [...selection.tiles].map(parseTileKey);
    applyTilePatch(level, tiles, patch);
    markDirty();
    setStatus(`Updated ${tiles.length} tile(s) · ${sectorCount(level)} sectors`);
    refreshAll();
  },
  onClear: () => {
    doClearTiles();
  },
  onSelectSector: () => {
    doSelectSector();
  },
});

const itemEditor = new ItemEditor(document.getElementById('item-editor'), {
  getItems: () => [...selection.items],
  onChange: (patch) => {
    const items = [...selection.items];
    for (const item of items) {
      if ('type' in patch) {
        if (patch.type === 'spawn' && item.type !== 'spawn' && hasSpawn(activeLevel(episode))) {
          setStatus('Only one spawn allowed', true);
          continue;
        }
        if (patch.type === CAMERA_TYPE && !isCamera(item)) {
          item.type = CAMERA_TYPE;
          item.angle = 0;
          delete item.skills;
        } else if (patch.type !== CAMERA_TYPE && isCamera(item)) {
          item.type = patch.type;
          item.skills = defaultSkills();
          delete item.angle;
        } else {
          item.type = patch.type;
        }
      }
      if ('x' in patch) item.x = clampWorld(patch.x);
      if ('y' in patch) item.y = clampWorld(patch.y);
      if ('angle' in patch) item.angle = Number(patch.angle) || 0;
      if ('skillKey' in patch && item.skills) {
        item.skills = { ...item.skills, [patch.skillKey]: patch.skillValue };
      }
    }
    markDirty();
    refreshEditors();
    mapView.draw();
    previewView.draw();
  },
  onDelete: () => {
    doDeleteItems();
  },
});

const mapView = new MapView(document.getElementById('map-canvas'), {
  getLevel: () => activeLevel(episode),
  getSelection: () => selection,
  images,
  stage: document.getElementById('map-stage'),
  onDropItem: (type, wx, wy) => {
    placeItem(type, wx, wy);
  },
  onPointer: (e, info) => {
    handlePointer(e, info);
  },
});

initShiftControls(
  document.getElementById('shift-controls'),
  (dx, dy) => {
    doShift(dx, dy);
  },
  (delta) => {
    doHeightNudge(delta);
  },
);

const previewHint = document.getElementById('preview-hint');
const previewRays = document.getElementById('preview-rays');
const previewColH = document.getElementById('preview-col-h');

function previewInt(el, fallback, lo, hi) {
  const n = Number(el.value);
  if (!Number.isFinite(n)) return fallback;
  return Math.max(lo, Math.min(hi, Math.round(n)));
}

const previewView = new PreviewView(document.getElementById('preview-canvas'), {
  getLevel: () => activeLevel(episode),
  getCamera: () => {
    const selectedCam = [...selection.items].find((it) => isCamera(it));
    return findPreviewCamera(activeLevel(episode), selectedCam ?? null);
  },
  getRaycasts: () => previewInt(previewRays, 40, 8, 320),
  getColumnHeight: () => previewInt(previewColH, 25, 8, 240),
  images,
  onRotate: (angle) => {
    const selectedCam = [...selection.items].find((it) => isCamera(it));
    const cam = findPreviewCamera(activeLevel(episode), selectedCam ?? null);
    if (!cam) return;
    cam.angle = angle;
    markDirty();
    if (selection.items.has(cam)) itemEditor.render();
    previewView.draw();
  },
  onMove: (x, y) => {
    const selectedCam = [...selection.items].find((it) => isCamera(it));
    const cam = findPreviewCamera(activeLevel(episode), selectedCam ?? null);
    if (!cam) return;
    // Keep fractional world coords while walking; |0 truncate made forward stick.
    cam.x = Math.max(0, Math.min(WORLD_MAX, x));
    cam.y = Math.max(0, Math.min(WORLD_MAX, y));
    markDirty();
    if (selection.items.has(cam)) itemEditor.render();
    mapView.draw();
    previewView.draw();
  },
});

function redrawPreview() {
  previewView.draw();
}

previewRays.addEventListener('change', redrawPreview);
previewColH.addEventListener('change', redrawPreview);
previewRays.addEventListener('input', redrawPreview);
previewColH.addEventListener('input', redrawPreview);

function updatePreviewHint() {
  const selectedCam = [...selection.items].find((it) => isCamera(it));
  const cam = findPreviewCamera(activeLevel(episode), selectedCam ?? null);
  if (!cam) {
    previewHint.textContent = 'Place or select a camera';
    return;
  }
  if (selectedCam) {
    previewHint.textContent = 'Drag L/R to rotate · U/D to walk';
  } else {
    previewHint.textContent = 'Showing first camera — select one to edit';
  }
}

function selectedTileList() {
  return [...selection.tiles].map(parseTileKey);
}

function brushProps() {
  const level = activeLevel(episode);
  if (selection.primaryTile) {
    const props = getTileProps(
      level,
      selection.primaryTile.tx,
      selection.primaryTile.ty,
    );
    if (props) return props;
  }
  for (const key of selection.tiles) {
    const { tx, ty } = parseTileKey(key);
    const props = getTileProps(level, tx, ty);
    if (props) return props;
  }
  return null;
}

function setTileSelection(tiles, primary = null) {
  selection.tiles = new Set(tiles.map(({ tx, ty }) => tileKey(tx, ty)));
  selection.primaryTile = primary || (tiles.length ? tiles[tiles.length - 1] : null);
}

function clearSelection() {
  selection.tiles.clear();
  selection.items.clear();
  selection.primaryTile = null;
  selection.hoverTile = null;
  selection.box = null;
  drag = null;
}

function refreshEditors() {
  tileEditor.render();
  itemEditor.render();
}

function refreshAll() {
  levelList.render();
  const label = document.getElementById('map-level-label');
  if (label) {
    const n = sectorCount(activeLevel(episode));
    label.textContent = `(${episode.activeLevel} · ${n} sector${n === 1 ? '' : 's'})`;
  }
  refreshEditors();
  updatePreviewHint();
  mapView.draw();
  previewView.draw();
}

function placeItem(type, wx, wy) {
  const level = activeLevel(episode);
  if (!EDITOR_ITEM_TYPES.includes(type)) return;
  if (type !== CAMERA_TYPE && gameItemCount(level) >= MAX_ITEMS) {
    setStatus(`Max ${MAX_ITEMS} items`, true);
    return;
  }
  if (type === 'spawn' && hasSpawn(level)) {
    setStatus('Only one spawn allowed', true);
    return;
  }
  const item = addItem(level, type, wx, wy);
  if (!item) {
    setStatus('Could not place item', true);
    return;
  }
  selection.tiles.clear();
  selection.primaryTile = null;
  selection.items = new Set([item]);
  markDirty();
  setStatus(`Placed ${type}`);
  refreshAll();
}

function doDeleteItems() {
  if (!selection.items.size) return;
  const level = activeLevel(episode);
  const n = selection.items.size;
  for (const it of [...selection.items]) removeItem(level, it);
  selection.items.clear();
  markDirty();
  setStatus(`Deleted ${n} item(s)`);
  refreshAll();
}

function doClearTiles() {
  if (!selection.tiles.size) {
    setStatus('No tiles selected', true);
    return;
  }
  const level = activeLevel(episode);
  const tiles = selectedTileList();
  clearTiles(level, tiles);
  selection.tiles.clear();
  selection.primaryTile = null;
  markDirty();
  setStatus(`Cleared ${tiles.length} tile(s) · ${sectorCount(level)} sectors`);
  refreshAll();
}

function doSelectSector() {
  const level = activeLevel(episode);
  const primary = selection.primaryTile || selectedTileList()[0];
  if (!primary) {
    setStatus('Select a tile first', true);
    return;
  }
  const id = level.map[primary.ty * MAP_SIZE + primary.tx];
  if (!id) {
    setStatus('Selected tile has no sector', true);
    return;
  }
  const tiles = tilesInSector(level, id);
  setTileSelection(tiles, primary);
  selection.items.clear();
  setStatus(`Selected sector #${id} (${tiles.length} tiles)`);
  refreshAll();
}

function doShift(dx, dy) {
  const level = activeLevel(episode);
  const dir = dy < 0 ? 'up' : dy > 0 ? 'down' : dx < 0 ? 'left' : 'right';

  if (selection.tiles.size > 0) {
    const tiles = selectedTileList();
    const occupied = tiles.filter(({ tx, ty }) => level.map[ty * MAP_SIZE + tx] !== 0);
    const items = itemsInTiles(level, occupied);

    const moved = moveTiles(level, occupied, dx, dy);
    moveItemsBy(level, items, dx * WORLD_PER_TILE, dy * WORLD_PER_TILE);

    const nextTiles = new Set();
    for (const key of selection.tiles) {
      const { tx, ty } = parseTileKey(key);
      const ntx = tx + dx;
      const nty = ty + dy;
      if (ntx >= 0 && ntx < MAP_SIZE && nty >= 0 && nty < MAP_SIZE) {
        nextTiles.add(tileKey(ntx, nty));
      }
    }
    for (const t of moved) nextTiles.add(tileKey(t.tx, t.ty));
    selection.tiles = nextTiles;

    if (selection.primaryTile) {
      const ntx = selection.primaryTile.tx + dx;
      const nty = selection.primaryTile.ty + dy;
      selection.primaryTile =
        ntx >= 0 && ntx < MAP_SIZE && nty >= 0 && nty < MAP_SIZE
          ? { tx: ntx, ty: nty }
          : (nextTiles.size ? parseTileKey([...nextTiles][0]) : null);
    }

    for (const it of [...selection.items]) {
      if (!level.items.includes(it)) selection.items.delete(it);
    }

    markDirty();
    setStatus(`Shifted selection ${dir} (${moved.length} tiles)`);
    refreshAll();
    return;
  }

  shiftLevel(level, dx, dy);

  for (const it of [...selection.items]) {
    if (!level.items.includes(it)) selection.items.delete(it);
  }

  markDirty();
  setStatus(`Shifted map ${dir}`);
  refreshAll();
}

function doHeightNudge(delta) {
  const level = activeLevel(episode);
  const tiles =
    selection.tiles.size > 0 ? selectedTileList() : occupiedTiles(level);
  const before = tiles.filter(({ tx, ty }) => getTileProps(level, tx, ty));
  if (!before.length) {
    setStatus(selection.tiles.size ? 'No occupied tiles in selection' : 'Map is empty', true);
    return;
  }
  nudgeTileHeights(level, tiles, delta);
  markDirty();
  setStatus(
    `${delta > 0 ? 'Raised' : 'Lowered'} floor & ceiling on ${
      selection.tiles.size ? 'selection' : 'map'
    }`,
  );
  refreshAll();
}

function tilesInBox(x0, y0, x1, y1, occupiedOnly = true) {
  const level = activeLevel(episode);
  const minX = Math.min(x0, x1);
  const maxX = Math.max(x0, x1);
  const minY = Math.min(y0, y1);
  const maxY = Math.max(y0, y1);
  const out = [];
  for (let ty = minY; ty <= maxY; ty++) {
    for (let tx = minX; tx <= maxX; tx++) {
      if (occupiedOnly && level.map[ty * MAP_SIZE + tx] === 0) continue;
      out.push({ tx, ty });
    }
  }
  return out;
}

function applyBoxSelection(additive, startTx, startTy, endTx, endTy, baseTiles) {
  const boxed = tilesInBox(startTx, startTy, endTx, endTy, true);
  if (additive) {
    const next = new Set(baseTiles);
    for (const t of boxed) next.add(tileKey(t.tx, t.ty));
    selection.tiles = next;
    selection.primaryTile = boxed.length
      ? boxed[boxed.length - 1]
      : (next.size ? parseTileKey([...next][next.size - 1]) : null);
  } else {
    selection.items.clear();
    setTileSelection(boxed, boxed.length ? boxed[boxed.length - 1] : null);
  }
}

function startBoxSelect(info, additive) {
  drag = {
    mode: 'box',
    additive,
    startTx: info.tx,
    startTy: info.ty,
    startPx: info.px,
    startPy: info.py,
    lastTx: info.tx,
    lastTy: info.ty,
    lastWx: info.wx,
    lastWy: info.wy,
    moved: false,
    baseTiles: additive ? new Set(selection.tiles) : new Set(),
  };
  selection.box = { x0: info.tx, y0: info.ty, x1: info.tx, y1: info.ty };
}

function startDrag(info, mode) {
  drag = {
    mode,
    lastTx: info.tx,
    lastTy: info.ty,
    lastWx: info.wx,
    lastWy: info.wy,
  };
}

function handlePointer(e, info) {
  const level = activeLevel(episode);

  if (e.type === 'pointerleave') {
    selection.hoverTile = null;
    if (!drag) mapView.draw();
    return;
  }

  if (e.type === 'pointermove') {
    selection.hoverTile = { tx: info.tx, ty: info.ty };

    if (drag && (e.buttons & 1)) {
      if (drag.mode === 'box') {
        const dist = Math.hypot(info.px - drag.startPx, info.py - drag.startPy);
        if (dist > 4) drag.moved = true;
        drag.lastTx = info.tx;
        drag.lastTy = info.ty;
        selection.box = {
          x0: drag.startTx,
          y0: drag.startTy,
          x1: info.tx,
          y1: info.ty,
        };
        if (drag.moved) {
          applyBoxSelection(
            drag.additive,
            drag.startTx,
            drag.startTy,
            info.tx,
            info.ty,
            drag.baseTiles,
          );
        }
        refreshEditors();
        mapView.draw();
        return;
      }

      if (drag.mode === 'items') {
        const dx = info.wx - drag.lastWx;
        const dy = info.wy - drag.lastWy;
        if (dx || dy) {
          const kept = moveItemsBy(level, [...selection.items], dx, dy);
          selection.items = new Set(kept);
          drag.lastWx = info.wx;
          drag.lastWy = info.wy;
          markDirty();
          refreshEditors();
          mapView.draw();
          previewView.draw();
        }
      }
      return;
    }

    mapView.draw();
    return;
  }

  if (e.type === 'pointerup') {
    if (drag) {
      if (drag.mode === 'box') {
        const { additive, startTx, startTy, moved, baseTiles } = drag;
        selection.box = null;
        if (!moved) {
          // Plain click / ctrl+click
          const key = tileKey(startTx, startTy);
          if (additive) {
            if (selection.tiles.has(key)) {
              selection.tiles.delete(key);
              if (
                selection.primaryTile &&
                selection.primaryTile.tx === startTx &&
                selection.primaryTile.ty === startTy
              ) {
                selection.primaryTile = selection.tiles.size
                  ? parseTileKey([...selection.tiles][selection.tiles.size - 1])
                  : null;
              }
            } else {
              selection.tiles.add(key);
              selection.primaryTile = { tx: startTx, ty: startTy };
            }
          } else {
            selection.items.clear();
            setTileSelection([{ tx: startTx, ty: startTy }], { tx: startTx, ty: startTy });
          }
        } else {
          applyBoxSelection(additive, startTx, startTy, drag.lastTx, drag.lastTy, baseTiles);
        }
        drag = null;
        const n = sectorCount(level);
        setStatus(
          `Selection: ${selection.tiles.size} tile(s), ${selection.items.size} item(s) · ${n} sectors`,
        );
        refreshAll();
        return;
      }

      drag = null;
      const n = sectorCount(level);
      if (selection.tiles.size || selection.items.size) {
        setStatus(
          `Selection: ${selection.tiles.size} tile(s), ${selection.items.size} item(s) · ${n} sectors`,
        );
      }
      refreshAll();
    }
    return;
  }

  if (e.type !== 'pointerdown') return;

  try {
    e.currentTarget.setPointerCapture(e.pointerId);
  } catch (_) { /* ignore */ }

  // Shift+click: paint / add tile
  if (info.shift) {
    selection.items.clear();
    const brush = brushProps();
    if (!addTile(level, info.tx, info.ty, brush)) {
      setStatus('No free sector ids', true);
      return;
    }
    setTileSelection([{ tx: info.tx, ty: info.ty }], { tx: info.tx, ty: info.ty });
    markDirty();
    setStatus(
      brush
        ? `Painted tile from selection · ${sectorCount(level)} sectors`
        : `Added default tile · ${sectorCount(level)} sectors`,
    );
    refreshAll();
    return;
  }

  // Item hit — drag to reposition (tile selection uses Shift panel)
  if (info.item) {
    if (info.ctrl) {
      if (selection.items.has(info.item)) selection.items.delete(info.item);
      else selection.items.add(info.item);
    } else if (selection.items.has(info.item)) {
      // Keep multi-selection and start drag
    } else {
      selection.items = new Set([info.item]);
      selection.tiles.clear();
      selection.primaryTile = null;
    }
    startDrag(info, 'items');
    refreshEditors();
    updatePreviewHint();
    mapView.draw();
    previewView.draw();
    return;
  }

  // Ctrl+drag starts additive box select (click-toggle happens on pointerup if no move)
  if (info.ctrl) {
    startBoxSelect(info, true);
    refreshEditors();
    mapView.draw();
    return;
  }

  // Box select (click selects one tile on pointerup)
  startBoxSelect(info, false);
  refreshEditors();
  mapView.draw();
}

function nudgeTileSelection(dtx, dty) {
  const primary = selection.primaryTile || selectedTileList()[0];
  if (!primary) return;
  const tx = Math.max(0, Math.min(MAP_SIZE - 1, primary.tx + dtx));
  const ty = Math.max(0, Math.min(MAP_SIZE - 1, primary.ty + dty));
  if (tx === primary.tx && ty === primary.ty) return;
  selection.items.clear();
  setTileSelection([{ tx, ty }], { tx, ty });
  selection.primaryTile = { tx, ty };
  refreshEditors();
  updatePreviewHint();
  mapView.draw();
  previewView.draw();
}

document.addEventListener('keydown', (e) => {
  if (
    e.target instanceof HTMLInputElement ||
    e.target instanceof HTMLSelectElement ||
    e.target instanceof HTMLTextAreaElement
  ) {
    return;
  }

  if (e.key === 'ArrowLeft' || e.key === 'ArrowRight' || e.key === 'ArrowUp' || e.key === 'ArrowDown') {
    if (!selection.tiles.size && !selection.primaryTile) return;
    e.preventDefault();
    const dx = e.key === 'ArrowLeft' ? -1 : e.key === 'ArrowRight' ? 1 : 0;
    const dy = e.key === 'ArrowUp' ? -1 : e.key === 'ArrowDown' ? 1 : 0;
    nudgeTileSelection(dx, dy);
    return;
  }

  if (e.key !== 'Delete' && e.key !== 'Backspace') return;
  e.preventDefault();
  if (selection.items.size) doDeleteItems();
  else if (selection.tiles.size) doClearTiles();
});

document.getElementById('btn-save').addEventListener('click', async () => {
  await saveNow('Saved');
});

document.getElementById('btn-load').addEventListener('click', async () => {
  try {
    const loaded = await loadEpisodeJSON();
    if (!loaded) return;
    Object.assign(episode.levels, loaded.levels);
    if (loaded.activeLevel && episode.levels[loaded.activeLevel]) {
      episode.activeLevel = loaded.activeLevel;
    }
    clearSelection();
    markClean();
    setStatus('Loaded');
    refreshAll();
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
});

document.getElementById('btn-cook').addEventListener('click', () => {
  const warnings = cookAndDownload(episode, episode.activeLevel);
  if (warnings?.length) {
    setStatus(`Cooked ${episode.activeLevel} — ${warnings[0]}`, true);
  } else {
    setStatus(`Cooked ${episode.activeLevel}`);
  }
});

async function boot() {
  updateDirtyIndicator();
  try {
    const loaded = await fetchEpisodeJSON(EPISODE_FILE);
    Object.assign(episode.levels, loaded.levels);
    if (loaded.activeLevel && episode.levels[loaded.activeLevel]) {
      episode.activeLevel = loaded.activeLevel;
    }
    markClean();
    setStatus(`Loaded ${EPISODE_FILE}`);
  } catch (err) {
    setStatus(`No ${EPISODE_FILE} yet — editing blank episode`, false);
  }
  refreshAll();
}

boot();

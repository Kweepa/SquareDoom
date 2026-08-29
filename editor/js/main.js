import {
  EDITOR_ITEM_TYPES,
  CAMERA_TYPE,
  SPAWN_TYPE,
  SWITCH_TYPE,
  MAP_SIZE,
  MAX_ENEMIES,
  ENEMY_TYPES,
  LEVEL_NAMES,
  WORLD_PER_TILE,
  WORLD_MAX,
  activeLevel,
  addItem,
  addTile,
  applyTilePatch,
  clearTiles,
  closetNeighbourFloor,
  clampLevelName,
  clampParTime,
  createEpisode,
  defaultSkills,
  enemyCount,
  gameItemCount,
  findPreviewCamera,
  getCell,
  getTileProps,
  isCamera,
  isSpawn,
  isSwitch,
  isSwitchCookType,
  itemStillOnLevel,
  monsterClosetHeights,
  moveItemsBy,
  moveTiles,
  nudgeTileHeights,
  occupiedTiles,
  parseTileKey,
  rebuildSectors,
  compactSectorIds,
  removeItem,
  sectorCount,
  secretCount,
  shiftLevel,
  tileKey,
  tilesInSector,
  clampWorld,
  itemsInTiles,
  normalizeAngle,
  validateVoidBorder,
} from './model.js?v=31';
import { MapView } from './mapView.js?v=25';
import { ItemPalette } from './itemPalette.js?v=24';
import { LevelList } from './levelList.js?v=24';
import { TileEditor } from './tileEditor.js?v=28';
import { ItemEditor } from './itemEditor.js?v=26';
import { PreviewView } from './previewView.js?v=32';
import { initShiftControls } from './shiftControls.js?v=24';
import {
  allowStoredEpisodeFile,
  autosaveEpisodeJSON,
  cookAndDownload,
  episodeFileName,
  getStoredEpisodeHandle,
  hasEpisodeFileHandle,
  levelFromJSON,
  levelToJSON,
  loadEpisodeJSON,
  saveEpisodeJSON,
  tryRestoreEpisodeFile,
} from './io.js?v=27';

const statusEl = document.getElementById('status');
const titleEl = document.querySelector('.toolbar h1');
const btnUndo = document.getElementById('btn-undo');
const btnRedo = document.getElementById('btn-redo');
const AUTOSAVE_MS = 10000;
const EPISODE_FILE = 'episode1.json';
const UNDO_LIMIT = 30;

let dirty = false;
let autosaveTimer = null;
let saving = false;

/** @type {string[]} JSON snapshots of the active level (pre-edit). */
let undoStack = [];
/** @type {string[]} */
let redoStack = [];
/** When true, further pushUndo calls are ignored (one entry per drag gesture). */
let undoGestureActive = false;

function setStatus(msg, isError = false) {
  statusEl.textContent = msg || '';
  statusEl.classList.toggle('error', isError);
}

function updateDirtyIndicator() {
  const star = dirty ? '*' : '';
  if (titleEl) titleEl.textContent = `SquareDoom${star}`;
  document.title = dirty ? 'SquareDoom *' : 'SquareDoom Map Editor';
}

function updateUndoButtons() {
  if (btnUndo) btnUndo.disabled = undoStack.length === 0;
  if (btnRedo) btnRedo.disabled = redoStack.length === 0;
}

function levelSnapshot() {
  return JSON.stringify(levelToJSON(activeLevel(episode)));
}

/** Push current level JSON before a mutation. No-op during an open gesture. */
function pushUndo() {
  if (undoGestureActive) return;
  undoStack.push(levelSnapshot());
  if (undoStack.length > UNDO_LIMIT) undoStack.shift();
  redoStack.length = 0;
  updateUndoButtons();
}

/** Push once for a multi-step gesture (item drag, camera walk). */
function beginUndoGesture() {
  if (undoGestureActive) return;
  pushUndo();
  undoGestureActive = true;
}

function endUndoGesture() {
  undoGestureActive = false;
}

function clearUndoHistory() {
  undoStack.length = 0;
  redoStack.length = 0;
  undoGestureActive = false;
  updateUndoButtons();
}

function restoreLevelFromSnapshot(jsonStr) {
  episode.levels[episode.activeLevel] = levelFromJSON(JSON.parse(jsonStr));
  clearSelection();
  markDirty();
  refreshAll();
}

function undo() {
  if (!undoStack.length) return;
  endUndoGesture();
  redoStack.push(levelSnapshot());
  if (redoStack.length > UNDO_LIMIT) redoStack.shift();
  restoreLevelFromSnapshot(undoStack.pop());
  setStatus('Undo');
  updateUndoButtons();
}

function redo() {
  if (!redoStack.length) return;
  endUndoGesture();
  undoStack.push(levelSnapshot());
  if (undoStack.length > UNDO_LIMIT) undoStack.shift();
  restoreLevelFromSnapshot(redoStack.pop());
  setStatus('Redo');
  updateUndoButtons();
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
  clearAutosaveTimer();
}

function clearAutosaveTimer() {
  if (autosaveTimer) {
    clearTimeout(autosaveTimer);
    autosaveTimer = null;
  }
}

function isEditingField(el = document.activeElement) {
  return (
    el instanceof HTMLInputElement ||
    el instanceof HTMLTextAreaElement ||
    el instanceof HTMLSelectElement ||
    !!el?.isContentEditable
  );
}

function scheduleAutosave() {
  clearAutosaveTimer();
  if (!dirty || isEditingField()) return;
  autosaveTimer = setTimeout(() => {
    autosaveTimer = null;
    void runAutosave();
  }, AUTOSAVE_MS);
}

async function runAutosave() {
  if (!dirty || saving || !hasEpisodeFileHandle()) return;
  if (isEditingField()) {
    // Still typing — wait a full idle delay after they leave the field.
    scheduleAutosave();
    return;
  }
  await saveNow('Autosaved');
}

/** Pause autosave while typing in inputs; restart the idle delay on leave. */
document.addEventListener('focusin', (e) => {
  if (isEditingField(e.target)) clearAutosaveTimer();
});
document.addEventListener('focusout', () => {
  // focus may move to another field; check after the new target is active.
  requestAnimationFrame(() => {
    if (dirty && !isEditingField()) scheduleAutosave();
  });
});

/** Set after UI init — saveNow runs above the bundled async IIFE. */
let refreshAfterPack = () => {};

async function saveNow(okMsg = 'Saved') {
  if (saving) return;
  saving = true;
  setStatus('Optimizing sectors…');
  try {
    for (const name of LEVEL_NAMES) {
      rebuildSectors(episode.levels[name], { optimal: true });
      compactSectorIds(episode.levels[name]);
    }
    refreshAfterPack();

    const borderIssues = validateVoidBorder(activeLevel(episode));
    if (borderIssues.length) {
      setStatus(borderIssues[0], true);
      return;
    }
    setStatus('Saving…');
    const how = hasEpisodeFileHandle()
      ? await autosaveEpisodeJSON(episode)
      : await saveEpisodeJSON(episode, EPISODE_FILE);
    if (how == null) {
      setStatus('Save cancelled', true);
    } else {
      markClean();
      setStatus(`${okMsg} ${episodeFileName()}`);
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
          const data =
            typeof ITEM_IMAGE_DATA !== 'undefined' && ITEM_IMAGE_DATA
              ? ITEM_IMAGE_DATA[type]
              : null;
          const img = new Image();
          img.src = data || `itemgraphics/${type}.png`;
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
    if (name === episode.activeLevel) return;
    episode.activeLevel = name;
    clearUndoHistory();
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
      .map(({ tx, ty }) => {
        const id = getCell(level, tx, ty);
        const props = getTileProps(level, tx, ty);
        return props ? { ...props, id } : null;
      })
      .filter(Boolean);
  },
  sectorCount: () => sectorCount(activeLevel(episode)),
  itemCount: () => gameItemCount(activeLevel(episode)),
  enemyCount: () => enemyCount(activeLevel(episode)),
  secretCount: () => secretCount(activeLevel(episode)),
  hasItemSelection: () => selection.items.size > 0,
  getLevelName: () => activeLevel(episode).name || '',
  onLevelNameChange: (name) => {
    const level = activeLevel(episode);
    const next = clampLevelName(name);
    if (level.name === next) return;
    pushUndo();
    level.name = next;
    markDirty();
    setStatus(next ? `Level name: ${next}` : 'Level name cleared');
    refreshEditors();
  },
  getParTime: () => clampParTime(activeLevel(episode).parTime),
  onParTimeChange: (sec) => {
    const level = activeLevel(episode);
    const next = clampParTime(sec);
    if (clampParTime(level.parTime) === next) return;
    pushUndo();
    level.parTime = next;
    markDirty();
    setStatus(`Par time: ${next}s`);
    refreshEditors();
  },
  onChange: (patch) => {
    const level = activeLevel(episode);
    const tiles = [...selection.tiles].map(parseTileKey);
    pushUndo();
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
  onMakeMonsterCloset: () => {
    const level = activeLevel(episode);
    const tiles = [...selection.tiles].map(parseTileKey);
    if (!tiles.length) {
      setStatus('Select tiles to make a monster closet');
      return;
    }
    const n = closetNeighbourFloor(level, tiles);
    if (n == null) {
      setStatus('No adjacent neighbour floor found for monster closet');
      return;
    }
    const heights = monsterClosetHeights(n);
    pushUndo();
    applyTilePatch(level, tiles, heights);
    markDirty();
    setStatus(
      `Monster closet: floor ${heights.floorHeight}, ceil ${heights.ceilingHeight} (neighbour floor ${n})`,
    );
    refreshAll();
  },
});

const itemEditor = new ItemEditor(document.getElementById('item-editor'), {
  getItems: () => [...selection.items],
  onChange: (patch) => {
    const items = [...selection.items];
    pushUndo();
    for (const item of items) {
      if ('type' in patch) {
        if (isSpawn(item)) continue; // spawn type is fixed
        if (patch.type === SPAWN_TYPE) continue;
        if (patch.type === SWITCH_TYPE || isSwitchCookType(patch.type)) {
          continue; // switch is a sector trigger, not an item
        }
        if (patch.type === CAMERA_TYPE && !isCamera(item)) {
          item.type = CAMERA_TYPE;
          item.angle = 0;
          delete item.skills;
        } else if (patch.type !== CAMERA_TYPE && isCamera(item)) {
          item.type = patch.type;
          item.skills = defaultSkills();
          delete item.angle;
        } else if (isSwitch(item)) {
          item.type = patch.type;
          item.skills = defaultSkills();
        } else {
          item.type = patch.type;
        }
      }
      if ('x' in patch) item.x = clampWorld(patch.x);
      if ('y' in patch) item.y = clampWorld(patch.y);
      if ('angle' in patch) item.angle = normalizeAngle(patch.angle);
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

const previewView = new PreviewView(document.getElementById('preview-canvas'), {
  getLevel: () => activeLevel(episode),
  getCamera: () => {
    const selected = [...selection.items].find((it) => isCamera(it) || isSpawn(it));
    return findPreviewCamera(activeLevel(episode), selected ?? null);
  },
  images,
  onRotate: (angle) => {
    const selected = [...selection.items].find((it) => isCamera(it) || isSpawn(it));
    const cam = findPreviewCamera(activeLevel(episode), selected ?? null);
    if (!cam) return;
    beginUndoGesture();
    cam.angle = normalizeAngle(angle);
    markDirty();
    if (selection.items.has(cam)) itemEditor.render();
    mapView.draw();
    previewView.draw();
  },
  onMove: (x, y) => {
    const selected = [...selection.items].find((it) => isCamera(it) || isSpawn(it));
    const cam = findPreviewCamera(activeLevel(episode), selected ?? null);
    if (!cam) return;
    beginUndoGesture();
    // Keep fractional world coords while walking; |0 truncate made forward stick.
    cam.x = Math.max(0, Math.min(WORLD_MAX, x));
    cam.y = Math.max(0, Math.min(WORLD_MAX, y));
    markDirty();
    if (selection.items.has(cam)) itemEditor.render();
    mapView.draw();
    previewView.draw();
  },
  onEditEnd: () => {
    endUndoGesture();
  },
});

function updatePreviewHint() {
  const selected = [...selection.items].find((it) => isCamera(it) || isSpawn(it));
  const cam = findPreviewCamera(activeLevel(episode), selected ?? null);
  if (!cam) {
    previewHint.textContent = 'Place or select a camera';
    return;
  }
  if (selected && isSpawn(selected)) {
    previewHint.textContent = 'Spawn view — drag L/R to set angle · U/D to move';
  } else if (selected) {
    previewHint.textContent = 'Drag L/R to rotate · U/D to walk';
  } else if (isSpawn(cam)) {
    previewHint.textContent = 'Showing spawn — select spawn to edit angle';
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

refreshAfterPack = refreshAll;

function placeItem(type, wx, wy) {
  const level = activeLevel(episode);
  if (!EDITOR_ITEM_TYPES.includes(type)) return;
  if (ENEMY_TYPES.has(type) && enemyCount(level) >= MAX_ENEMIES) {
    setStatus(`Max ${MAX_ENEMIES} enemies (mobj limit)`, true);
    return;
  }
  pushUndo();
  const item = addItem(level, type, wx, wy);
  if (!item) {
    undoStack.pop();
    updateUndoButtons();
    setStatus('Could not place item', true);
    return;
  }
  selection.tiles.clear();
  selection.primaryTile = null;
  selection.items = new Set([item]);
  markDirty();
  setStatus(type === SPAWN_TYPE ? 'Moved spawn' : `Placed ${type}`);
  refreshAll();
}

function doDeleteItems() {
  if (!selection.items.size) return;
  const level = activeLevel(episode);
  const toDelete = [...selection.items].filter((it) => !isSpawn(it));
  if (!toDelete.length) {
    setStatus('Spawn cannot be deleted', true);
    return;
  }
  pushUndo();
  for (const it of toDelete) removeItem(level, it);
  selection.items = new Set([...selection.items].filter((it) => isSpawn(it)));
  markDirty();
  setStatus(`Deleted ${toDelete.length} item(s)`);
  refreshAll();
}

function doClearTiles() {
  if (!selection.tiles.size) {
    setStatus('No tiles selected', true);
    return;
  }
  const level = activeLevel(episode);
  const tiles = selectedTileList();
  pushUndo();
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

  pushUndo();
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
      if (!itemStillOnLevel(level, it)) selection.items.delete(it);
    }

    markDirty();
    setStatus(`Shifted selection ${dir} (${moved.length} tiles)`);
    refreshAll();
    return;
  }

  shiftLevel(level, dx, dy);

  for (const it of [...selection.items]) {
    if (!itemStillOnLevel(level, it)) selection.items.delete(it);
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
  pushUndo();
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
        const dtx = info.tx - drag.lastTx;
        const dty = info.ty - drag.lastTy;
        if (dtx || dty) {
          beginUndoGesture();
          const kept = moveItemsBy(level, [...selection.items], dtx * WORLD_PER_TILE, dty * WORLD_PER_TILE);
          selection.items = new Set(kept);
          drag.lastTx = info.tx;
          drag.lastTy = info.ty;
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
            const key = tileKey(startTx, startTy);
            // Click selected empty (void) tile → deselect
            if (!getCell(level, startTx, startTy) && selection.tiles.has(key)) {
              selection.items.clear();
              selection.tiles.clear();
              selection.primaryTile = null;
            } else {
              selection.items.clear();
              setTileSelection([{ tx: startTx, ty: startTy }], { tx: startTx, ty: startTy });
            }
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

      endUndoGesture();
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

  // Shift+click empty: paint/add. Occupied tiles need Shift+Alt to overwrite.
  if (info.shift && (!info.sectorId || info.alt)) {
    selection.items.clear();
    const brush = brushProps();
    pushUndo();
    if (!addTile(level, info.tx, info.ty, brush)) {
      undoStack.pop();
      updateUndoButtons();
      setStatus('No free sector ids', true);
      return;
    }
    setTileSelection([{ tx: info.tx, ty: info.ty }], { tx: info.tx, ty: info.ty });
    markDirty();
    if (level._lastPaintNote) {
      setStatus(level._lastPaintNote, true);
    } else {
      setStatus(
        brush
          ? `Painted tile from selection · ${sectorCount(level)} sectors`
          : `Added default tile · ${sectorCount(level)} sectors`,
      );
    }
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

  if ((e.ctrlKey || e.metaKey) && !e.altKey) {
    const key = e.key.toLowerCase();
    if (key === 'z' && !e.shiftKey) {
      e.preventDefault();
      undo();
      return;
    }
    if (key === 'y' || (key === 'z' && e.shiftKey)) {
      e.preventDefault();
      redo();
      return;
    }
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

document.getElementById('btn-undo').addEventListener('click', () => {
  undo();
});

document.getElementById('btn-redo').addEventListener('click', () => {
  redo();
});

document.getElementById('btn-save').addEventListener('click', async () => {
  await saveNow('Saved');
});

function applyLoadedEpisode(loaded) {
  Object.assign(episode.levels, loaded.levels);
  if (loaded.activeLevel && episode.levels[loaded.activeLevel]) {
    episode.activeLevel = loaded.activeLevel;
  }
  clearUndoHistory();
  clearSelection();
  /** @type {string[]} */
  const shapeNotes = [];
  for (const name of Object.keys(episode.levels)) {
    const lvl = episode.levels[name];
    if (lvl._loadWarnings?.length) {
      shapeNotes.push(...lvl._loadWarnings.map((w) => `${name}: ${w}`));
      delete lvl._loadWarnings;
    }
  }
  if (shapeNotes.length) {
    markDirty();
    setStatus(`Loaded ${episodeFileName()} — ${shapeNotes[0]}`, true);
  } else {
    markClean();
    setStatus(`Loaded ${episodeFileName()}`);
  }
  refreshAll();
}

function showFileAccessGate(storedHandle) {
  const overlay = document.createElement('div');
  overlay.className = 'file-gate';
  overlay.innerHTML = `
    <div class="file-gate-card" role="dialog" aria-modal="true" aria-labelledby="file-gate-title">
      <h2 id="file-gate-title">Open map file</h2>
      <p class="muted">
        ${
          storedHandle
            ? `Browser needs permission to read/write <strong>${storedHandle.name}</strong>.`
            : `Choose project file <strong>${EPISODE_FILE}</strong> (usually in the editor folder).`
        }
      </p>
      <div class="btn-row">
        <button type="button" class="file-gate-primary" id="file-gate-ok">
          ${storedHandle ? `Allow ${storedHandle.name}` : `Open ${EPISODE_FILE}…`}
        </button>
        ${storedHandle ? `<button type="button" id="file-gate-other">Choose different file…</button>` : ''}
      </div>
    </div>
  `;
  document.body.appendChild(overlay);
  const ok = overlay.querySelector('#file-gate-ok');
  const other = overlay.querySelector('#file-gate-other');
  ok.focus();

  const finish = async (loader) => {
    ok.disabled = true;
    if (other) other.disabled = true;
    try {
      const loaded = await loader();
      if (!loaded) {
        ok.disabled = false;
        if (other) other.disabled = false;
        setStatus('Open cancelled', true);
        return;
      }
      overlay.remove();
      applyLoadedEpisode(loaded);
    } catch (err) {
      ok.disabled = false;
      if (other) other.disabled = false;
      setStatus(String(err.message || err), true);
    }
  };

  ok.addEventListener('click', () => {
    void finish(() =>
      storedHandle ? allowStoredEpisodeFile(storedHandle) : loadEpisodeJSON(),
    );
  });
  other?.addEventListener('click', () => {
    void finish(() => loadEpisodeJSON());
  });
}

document.getElementById('btn-load').addEventListener('click', async () => {
  try {
    const loaded = await loadEpisodeJSON();
    if (!loaded) return;
    applyLoadedEpisode(loaded);
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
});

document.getElementById('btn-cook').addEventListener('click', () => {
  const result = cookAndDownload(episode, episode.activeLevel);
  if (result?.errors?.length) {
    setStatus(`Cook blocked — ${result.errors[0]}`, true);
  } else if (result?.warnings?.length) {
    setStatus(`Cooked ${episode.activeLevel} — ${result.warnings[0]}`, true);
  } else {
    setStatus(`Cooked ${episode.activeLevel}`);
  }
});

async function boot() {
  updateDirtyIndicator();
  refreshAll();
  try {
    const loaded = await tryRestoreEpisodeFile();
    if (loaded) {
      applyLoadedEpisode(loaded);
      return;
    }
    const stored = await getStoredEpisodeHandle();
    showFileAccessGate(stored);
    setStatus(
      stored
        ? `Click Allow to open ${stored.name}`
        : `Open ${EPISODE_FILE} to edit the project map`,
      false,
    );
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
}

boot();

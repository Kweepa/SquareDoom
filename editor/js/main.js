import {
  ITEM_TYPES,
  EDITOR_ITEM_TYPES,
  CAMERA_TYPE,
  MAP_SIZE,
  activeLevel,
  addItem,
  clearTile,
  createEpisode,
  defaultSkills,
  deleteSector,
  findPreviewCamera,
  gameItemCount,
  getCell,
  hasSpawn,
  isCamera,
  mergeIdenticalSectors,
  mergeSectors,
  moveItem,
  paintDefaultSector,
  paintSector,
  removeItem,
  shiftLevel,
  splitSectorAt,
  clampWorld,
  MAX_ITEMS,
} from './model.js';
import { MapView } from './mapView.js';
import { ItemPalette } from './itemPalette.js';
import { LevelList } from './levelList.js';
import { SectorEditor } from './sectorEditor.js';
import { ItemEditor } from './itemEditor.js';
import { PreviewView } from './previewView.js';
import { initShiftControls } from './shiftControls.js';
import { cookAndDownload, loadEpisodeJSON, saveEpisodeJSON } from './io.js';

const statusEl = document.getElementById('status');

function setStatus(msg, isError = false) {
  statusEl.textContent = msg || '';
  statusEl.classList.toggle('error', isError);
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
 *   sectorId: number,
 *   tile: {tx:number,ty:number}|null,
 *   item: any|null,
 *   hoverSector: number,
 *   mergeTarget: number|null,
 * }} */
const selection = {
  sectorId: 0,
  tile: null,
  item: null,
  hoverSector: 0,
  mergeTarget: null,
};

let draggingItem = null;

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

const sectorEditor = new SectorEditor(document.getElementById('sector-editor'), {
  getSector: () => {
    const level = activeLevel(episode);
    if (!selection.sectorId || !level.sectors.has(selection.sectorId)) return null;
    return { id: selection.sectorId, data: level.sectors.get(selection.sectorId) };
  },
  onChange: (patch) => {
    const level = activeLevel(episode);
    const s = level.sectors.get(selection.sectorId);
    if (!s) return;
    if ('floorHeight' in patch) s.floorHeight = clamp(patch.floorHeight, 0, 31);
    if ('ceilingHeight' in patch) s.ceilingHeight = clamp(patch.ceilingHeight, 0, 31);
    if ('nsTexture' in patch) s.nsTexture = clamp(patch.nsTexture, 0, 15);
    if ('ewTexture' in patch) s.ewTexture = clamp(patch.ewTexture, 0, 15);
    if ('brightness' in patch) s.brightness = clamp(patch.brightness, 0, 7);
    if ('floorColor' in patch) s.floorColor = patch.floorColor;
    if ('ceilingColor' in patch) s.ceilingColor = patch.ceilingColor;
    refreshEditors();
    mapView.draw();
    previewView.draw();
  },
  onMergeIdentical: () => {
    mergeIdenticalSectors(activeLevel(episode));
    if (selection.sectorId && !activeLevel(episode).sectors.has(selection.sectorId)) {
      clearSelection();
    }
    setStatus('Merged identical sectors');
    refreshAll();
  },
  onMergeWithNext: () => {
    if (selection.mergeTarget) {
      selection.mergeTarget = null;
      setStatus('Merge cancelled');
    } else if (selection.sectorId) {
      selection.mergeTarget = selection.sectorId;
      setStatus(`Merge armed: click another sector to merge into #${selection.sectorId}`);
    } else {
      setStatus('Select a sector first', true);
    }
    refreshEditors();
  },
  onDeleteSector: () => {
    if (!selection.sectorId) return;
    deleteSector(activeLevel(episode), selection.sectorId);
    clearSelection();
    setStatus('Sector deleted');
    refreshAll();
  },
  onClearTile: () => {
    doClearTile();
  },
  mergeArmed: () => selection.mergeTarget != null,
});

const itemEditor = new ItemEditor(document.getElementById('item-editor'), {
  getItem: () => selection.item,
  onChange: (patch) => {
    const item = selection.item;
    if (!item) return;
    if ('type' in patch) {
      if (patch.type === 'spawn' && patch.type !== item.type && hasSpawn(activeLevel(episode))) {
        setStatus('Only one spawn allowed', true);
        refreshEditors();
        return;
      }
      if (patch.type === CAMERA_TYPE && item.type !== CAMERA_TYPE) {
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
    if ('skills' in patch) item.skills = { ...patch.skills };
    refreshEditors();
    mapView.draw();
    previewView.draw();
  },
  onDelete: () => {
    doDeleteItem();
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

initShiftControls(document.getElementById('shift-controls'), (dx, dy) => {
  doShift(dx, dy);
});

const previewHint = document.getElementById('preview-hint');
const previewView = new PreviewView(document.getElementById('preview-canvas'), {
  getLevel: () => activeLevel(episode),
  getCamera: () => findPreviewCamera(activeLevel(episode), selection.item),
  images,
  onRotate: (angle) => {
    const cam = findPreviewCamera(activeLevel(episode), selection.item);
    if (!cam) return;
    cam.angle = angle;
    if (selection.item === cam) itemEditor.render();
    previewView.draw();
  },
});

function updatePreviewHint() {
  const cam = findPreviewCamera(activeLevel(episode), selection.item);
  if (!cam) {
    previewHint.textContent = 'Place or select a camera';
    return;
  }
  if (isCamera(selection.item)) {
    previewHint.textContent = 'Drag in preview to rotate';
  } else {
    previewHint.textContent = 'Showing first camera — select one to edit angle';
  }
}

function doShift(dx, dy) {
  const level = activeLevel(episode);
  const selectedItem = selection.item;

  shiftLevel(level, dx, dy);

  if (selection.tile) {
    const ntx = selection.tile.tx + dx;
    const nty = selection.tile.ty + dy;
    if (ntx < 0 || ntx >= MAP_SIZE || nty < 0 || nty >= MAP_SIZE) {
      selection.tile = null;
      selection.sectorId = 0;
    } else {
      selection.tile = { tx: ntx, ty: nty };
      selection.sectorId = getCell(level, ntx, nty);
    }
  } else if (selectedItem) {
    if (!level.items.includes(selectedItem)) selection.item = null;
    selection.sectorId = 0;
  } else if (selection.sectorId && !level.sectors.has(selection.sectorId)) {
    selection.sectorId = 0;
  }

  selection.mergeTarget = null;
  selection.hoverSector = 0;

  const dir = dy < 0 ? 'up' : dy > 0 ? 'down' : dx < 0 ? 'left' : 'right';
  setStatus(`Shifted ${dir}`);
  refreshAll();
}

function clamp(v, lo, hi) {
  return Math.max(lo, Math.min(hi, Number(v) || 0));
}

function clearSelection() {
  selection.sectorId = 0;
  selection.tile = null;
  selection.item = null;
  selection.hoverSector = 0;
  selection.mergeTarget = null;
  draggingItem = null;
}

function refreshEditors() {
  sectorEditor.render();
  itemEditor.render();
}

function refreshAll() {
  levelList.render();
  const label = document.getElementById('map-level-label');
  if (label) label.textContent = `(${episode.activeLevel})`;
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
  selection.item = item;
  selection.sectorId = 0;
  selection.tile = null;
  setStatus(`Placed ${type}`);
  refreshAll();
}

function doDeleteItem() {
  if (!selection.item) return;
  removeItem(activeLevel(episode), selection.item);
  selection.item = null;
  setStatus('Item deleted');
  refreshAll();
}

function doClearTile() {
  if (!selection.tile) {
    setStatus('No tile selected', true);
    return;
  }
  const { tx, ty } = selection.tile;
  const old = clearTile(activeLevel(episode), tx, ty);
  if (old && !activeLevel(episode).sectors.has(old)) {
    selection.sectorId = 0;
  } else {
    selection.sectorId = getCell(activeLevel(episode), tx, ty);
  }
  if (!selection.sectorId) selection.tile = null;
  setStatus('Tile cleared');
  refreshAll();
}

function handlePointer(e, info) {
  const level = activeLevel(episode);

  if (e.type === 'pointerleave') {
    selection.hoverSector = 0;
    mapView.draw();
    return;
  }

  if (e.type === 'pointermove') {
    if (draggingItem && (e.buttons & 1)) {
      moveItem(level, draggingItem, info.wx, info.wy);
      mapView.draw();
      if (isCamera(draggingItem)) previewView.draw();
      return;
    }
    selection.hoverSector = info.item ? 0 : info.sectorId;
    mapView.draw();
    return;
  }

  if (e.type === 'pointerup') {
    if (draggingItem) {
      draggingItem = null;
      refreshEditors();
      mapView.draw();
      previewView.draw();
    }
    return;
  }

  if (e.type !== 'pointerdown') return;

  // Item hit takes priority
  if (info.item && !info.shift) {
    selection.item = info.item;
    selection.sectorId = 0;
    selection.tile = null;
    draggingItem = info.item;
    try {
      e.currentTarget.setPointerCapture(e.pointerId);
    } catch (_) { /* ignore */ }
    refreshEditors();
    mapView.draw();
    previewView.draw();
    return;
  }

  selection.item = null;
  selection.tile = { tx: info.tx, ty: info.ty };

  if (info.shift) {
    selection.mergeTarget = null;
    if (info.sectorId === 0) {
      if (selection.sectorId && level.sectors.has(selection.sectorId)) {
        paintSector(level, info.tx, info.ty, selection.sectorId);
        setStatus(`Painted sector #${selection.sectorId}`);
      } else {
        const id = paintDefaultSector(level, info.tx, info.ty);
        if (id) {
          selection.sectorId = id;
          setStatus(`Created sector #${id}`);
        } else {
          setStatus('No free sector ids', true);
        }
      }
    } else {
      const id = splitSectorAt(level, info.tx, info.ty);
      if (id) {
        selection.sectorId = id;
        setStatus(`Split into sector #${id}`);
      } else {
        setStatus('Could not split sector', true);
      }
    }
    refreshAll();
    return;
  }

  // Normal click
  if (selection.mergeTarget && info.sectorId && info.sectorId !== selection.mergeTarget) {
    mergeSectors(level, selection.mergeTarget, info.sectorId);
    selection.sectorId = selection.mergeTarget;
    selection.mergeTarget = null;
    setStatus(`Merged into sector #${selection.sectorId}`);
    refreshAll();
    return;
  }

  selection.sectorId = info.sectorId;
  selection.mergeTarget = null;
  refreshEditors();
  updatePreviewHint();
  mapView.draw();
  previewView.draw();
}

document.addEventListener('keydown', (e) => {
  if (e.target instanceof HTMLInputElement || e.target instanceof HTMLSelectElement || e.target instanceof HTMLTextAreaElement) {
    return;
  }
  if (e.key !== 'Delete' && e.key !== 'Backspace') return;
  e.preventDefault();
  if (selection.item) {
    doDeleteItem();
  } else if (selection.sectorId || selection.tile) {
    doClearTile();
  }
});

document.getElementById('btn-save').addEventListener('click', async () => {
  try {
    await saveEpisodeJSON(episode);
    setStatus('Saved');
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
});

document.getElementById('btn-load').addEventListener('click', async () => {
  try {
    const loaded = await loadEpisodeJSON();
    if (!loaded) return;
    Object.assign(episode.levels, loaded.levels);
    clearSelection();
    setStatus('Loaded');
    refreshAll();
  } catch (err) {
    setStatus(String(err.message || err), true);
  }
});

document.getElementById('btn-cook').addEventListener('click', () => {
  cookAndDownload(episode, episode.activeLevel);
  setStatus(`Cooked ${episode.activeLevel}`);
});

refreshAll();

/** @typedef {number} C64Color 0–15 Commodore 64 palette index */

export const MAP_SIZE = 32;
export const MAP_CELLS = MAP_SIZE * MAP_SIZE;
export const MAX_SECTORS = 255;
export const MAX_ITEMS = 48;
export const WORLD_PER_TILE = 8;
export const WORLD_MAX = MAP_SIZE * WORLD_PER_TILE - 1; // 255

export const LEVEL_NAMES = [
  'E1M1', 'E1M2', 'E1M3', 'E1M4', 'E1M5', 'E1M6', 'E1M7', 'E1M8', 'E1M9',
];

/** Pepto Commodore 64 palette (indices 0–15). */
export const C64_HEX = [
  '#000000', // 0 black
  '#ffffff', // 1 white
  '#813338', // 2 red
  '#75cec8', // 3 cyan
  '#8e3c97', // 4 purple
  '#56ac4d', // 5 green
  '#40318d', // 6 blue
  '#bfce72', // 7 yellow
  '#8e5029', // 8 orange
  '#553f00', // 9 brown
  '#c46c71', // 10 light red
  '#4a4a4a', // 11 dark grey
  '#7b7b7b', // 12 grey
  '#a9ff9f', // 13 light green
  '#706deb', // 14 light blue
  '#b2b2b2', // 15 light grey
];

export const C64_NAMES = [
  'black', 'white', 'red', 'cyan', 'purple', 'green', 'blue', 'yellow',
  'orange', 'brown', 'light red', 'dark grey', 'grey', 'light green',
  'light blue', 'light grey',
];

/** @deprecated old 8-colour names → C64 index (for map migration) */
const LEGACY_COLOR_TO_C64 = {
  black: 0,
  red: 2,
  green: 5,
  yellow: 7,
  blue: 6,
  magenta: 4,
  cyan: 3,
  white: 1,
};

/** Doom-style sector specials (as used by VicDoom), plus editor Door. */
export const DOOR_SECTOR_TYPE = 18;

export const SECTOR_TYPES = [
  { id: 0, name: 'Normal' },
  { id: 1, name: 'Light blink random' },
  { id: 2, name: 'Light blink 0.5s' },
  { id: 3, name: 'Light blink 1.0s' },
  { id: 4, name: 'Damage 20% + blink' },
  { id: 5, name: 'Damage 10%' },
  { id: 7, name: 'Damage 5%' },
  { id: 8, name: 'Light oscillate' },
  { id: 9, name: 'Secret' },
  { id: 10, name: 'Door close (30s)' },
  { id: 11, name: 'Damage end level' },
  { id: 12, name: 'Light blink sync 1s' },
  { id: 13, name: 'Light blink sync 0.5s' },
  { id: 14, name: 'Door open (300s)' },
  { id: 16, name: 'Damage 20%' },
  { id: 17, name: 'Light flicker' },
  { id: DOOR_SECTOR_TYPE, name: 'Door' },
];

export function isDoorSector(sector) {
  return (sector?.sectorType ?? 0) === DOOR_SECTOR_TYPE;
}

export const ITEM_TYPES = [
  'spawn', 'soldier', 'imp', 'pinky', 'caco', 'baron', 'barrel',
  'health', 'shells', 'shotgun', 'chaingun', 'chainsaw',
  'greenarmor', 'bluearmor', 'backpack',
  'redcard', 'bluecard', 'yellowcard',
  'acid', 'skullpile', 'techcolumn',
];

export const CAMERA_TYPE = 'camera';

/** Palette + map placement (includes editor-only camera). */
export const EDITOR_ITEM_TYPES = [...ITEM_TYPES, CAMERA_TYPE];

export function isGameItem(type) {
  return type !== CAMERA_TYPE;
}

export function isCamera(item) {
  return item?.type === CAMERA_TYPE;
}

export function gameItemCount(level) {
  return level.items.filter((it) => isGameItem(it.type)).length;
}

export function getSectorAtWorld(level, wx, wy) {
  const { tx, ty } = worldToTile(wx, wy);
  const id = getCell(level, tx, ty);
  if (!id || !level.sectors.has(id)) return null;
  return level.sectors.get(id);
}

/** Eye height for a camera at world coords: sector floor + 3. */
export function getCameraEyeHeight(level, wx, wy) {
  const sector = getSectorAtWorld(level, wx, wy);
  return (sector?.floorHeight ?? 0) + 3;
}

export function findPreviewCamera(level, selectedItem) {
  if (isCamera(selectedItem)) return selectedItem;
  return level.items.find((it) => isCamera(it)) ?? null;
}

export function colorHex(index) {
  return C64_HEX[index & 15] || C64_HEX[0];
}

/** Normalize JSON colour (legacy name or 0–15) to a C64 index. */
export function normalizeColor(value, fallback = 0) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.max(0, Math.min(15, value | 0));
  }
  if (typeof value === 'string' && value in LEGACY_COLOR_TO_C64) {
    return LEGACY_COLOR_TO_C64[value];
  }
  const asNum = Number(value);
  if (Number.isFinite(asNum)) return Math.max(0, Math.min(15, asNum | 0));
  return fallback;
}

/** @deprecated use colorHex / normalizeColor */
export const COLORS = C64_NAMES;
/** @deprecated use C64_HEX / colorHex */
export const COLOR_HEX = Object.fromEntries(C64_NAMES.map((n, i) => [n, C64_HEX[i]]));

export function colorIndex(value) {
  return normalizeColor(value, 0);
}

export function defaultSector() {
  return {
    floorHeight: 8,
    ceilingHeight: 13,
    sectorType: 0,
    /** Editor-only name; baked away — used to resolve targetTag → sector id. */
    tag: '',
    /** Editor-only; when sectorType ≠ 0, names the target sector's tag. */
    targetTag: '',
    floorColor: 0,
    ceilingColor: 0,
    brightness: 7,
  };
}

export function cloneSector(s) {
  return { ...s };
}

export function sectorsEqual(a, b) {
  return (
    a.floorHeight === b.floorHeight &&
    a.ceilingHeight === b.ceilingHeight &&
    a.sectorType === b.sectorType &&
    (a.tag || '') === (b.tag || '') &&
    (a.targetTag || '') === (b.targetTag || '') &&
    a.floorColor === b.floorColor &&
    a.ceilingColor === b.ceilingColor &&
    a.brightness === b.brightness
  );
}

/** Find sector id whose tag matches (first / lowest id). 0 if none. */
export function findSectorIdByTag(level, tag) {
  const t = String(tag || '').trim();
  if (!t) return 0;
  const ids = [...level.sectors.keys()].sort((a, b) => a - b);
  for (const id of ids) {
    if ((level.sectors.get(id).tag || '').trim() === t) return id;
  }
  return 0;
}

export function defaultSkills() {
  return { easy: true, normal: true, hard: true };
}

export function createEmptyLevel() {
  return {
    /** @type {Map<number, ReturnType<typeof defaultSector>>} sectorId -> data (1..255) */
    sectors: new Map(),
    /** @type {Uint8Array} */
    map: new Uint8Array(MAP_CELLS),
    /** @type {Array<{type:string,x:number,y:number,skills:{easy:boolean,normal:boolean,hard:boolean}}>} */
    items: [],
  };
}

export function createEpisode() {
  /** @type {Record<string, ReturnType<typeof createEmptyLevel>>} */
  const levels = {};
  for (const name of LEVEL_NAMES) {
    levels[name] = createEmptyLevel();
  }
  return {
    levels,
    activeLevel: 'E1M1',
  };
}

export function cellIndex(tx, ty) {
  return ty * MAP_SIZE + tx;
}

export function getCell(level, tx, ty) {
  if (tx < 0 || ty < 0 || tx >= MAP_SIZE || ty >= MAP_SIZE) return 0;
  return level.map[cellIndex(tx, ty)];
}

export function setCell(level, tx, ty, sectorId) {
  level.map[cellIndex(tx, ty)] = sectorId;
}

export function worldToTile(wx, wy) {
  return {
    tx: Math.max(0, Math.min(MAP_SIZE - 1, wx >> 3)),
    ty: Math.max(0, Math.min(MAP_SIZE - 1, wy >> 3)),
  };
}

export function clampWorld(v) {
  return Math.max(0, Math.min(WORLD_MAX, v | 0));
}

/** Allocate next free sector id 1..255, or 0 if full. */
export function allocSectorId(level) {
  for (let id = 1; id <= MAX_SECTORS; id++) {
    if (!level.sectors.has(id)) return id;
  }
  return 0;
}

export function sectorCellCount(level, sectorId) {
  let n = 0;
  for (let i = 0; i < MAP_CELLS; i++) {
    if (level.map[i] === sectorId) n++;
  }
  return n;
}

export function dropSectorIfEmpty(level, sectorId) {
  if (sectorId === 0) return;
  if (sectorCellCount(level, sectorId) === 0) {
    level.sectors.delete(sectorId);
  }
}

/** Create default sector on empty cell; returns new id or 0. */
export function paintDefaultSector(level, tx, ty) {
  const id = allocSectorId(level);
  if (!id) return 0;
  level.sectors.set(id, defaultSector());
  setCell(level, tx, ty, id);
  return id;
}

/** Paint existing sector onto a cell. */
export function paintSector(level, tx, ty, sectorId) {
  if (!level.sectors.has(sectorId)) return false;
  const old = getCell(level, tx, ty);
  setCell(level, tx, ty, sectorId);
  dropSectorIfEmpty(level, old);
  return true;
}

/**
 * Split: copy sector data into a new id for this cell only.
 * Returns new id or 0.
 */
export function splitSectorAt(level, tx, ty) {
  const old = getCell(level, tx, ty);
  if (old === 0 || !level.sectors.has(old)) return 0;
  const id = allocSectorId(level);
  if (!id) return 0;
  level.sectors.set(id, cloneSector(level.sectors.get(old)));
  setCell(level, tx, ty, id);
  dropSectorIfEmpty(level, old);
  return id;
}

/** Clear a single tile. */
export function clearTile(level, tx, ty) {
  const old = getCell(level, tx, ty);
  setCell(level, tx, ty, 0);
  dropSectorIfEmpty(level, old);
  return old;
}

/** Delete all tiles of a sector. */
export function deleteSector(level, sectorId) {
  if (sectorId === 0) return;
  for (let i = 0; i < MAP_CELLS; i++) {
    if (level.map[i] === sectorId) level.map[i] = 0;
  }
  level.sectors.delete(sectorId);
}

/**
 * Shift all map tiles and items by dx/dy tile steps.
 * Content that moves off the map is discarded.
 */
export function shiftLevel(level, dx, dy) {
  const old = level.map;
  const next = new Uint8Array(MAP_CELLS);
  for (let ty = 0; ty < MAP_SIZE; ty++) {
    for (let tx = 0; tx < MAP_SIZE; tx++) {
      const id = old[cellIndex(tx, ty)];
      if (!id) continue;
      const ntx = tx + dx;
      const nty = ty + dy;
      if (ntx >= 0 && ntx < MAP_SIZE && nty >= 0 && nty < MAP_SIZE) {
        next[cellIndex(ntx, nty)] = id;
      }
    }
  }
  level.map = next;

  for (const id of [...level.sectors.keys()]) {
    if (sectorCellCount(level, id) === 0) level.sectors.delete(id);
  }

  const kept = [];
  for (const it of level.items) {
    const nx = it.x + dx * WORLD_PER_TILE;
    const ny = it.y + dy * WORLD_PER_TILE;
    if (nx >= 0 && nx <= WORLD_MAX && ny >= 0 && ny <= WORLD_MAX) {
      it.x = nx;
      it.y = ny;
      kept.push(it);
    }
  }
  level.items.length = 0;
  level.items.push(...kept);
}

/** All occupied map cells. */
export function occupiedTiles(level) {
  const out = [];
  for (let ty = 0; ty < MAP_SIZE; ty++) {
    for (let tx = 0; tx < MAP_SIZE; tx++) {
      if (getCell(level, tx, ty)) out.push({ tx, ty });
    }
  }
  return out;
}

/** Items whose containing tile is in the given tile list. */
export function itemsInTiles(level, tiles) {
  const keys = new Set(tiles.map(({ tx, ty }) => tileKey(tx, ty)));
  return level.items.filter((it) => {
    const tx = Math.floor(it.x / WORLD_PER_TILE);
    const ty = Math.floor(it.y / WORLD_PER_TILE);
    return keys.has(tileKey(tx, ty));
  });
}

/**
 * Raise/lower floor and ceiling together by delta on listed tiles.
 * Each height is clamped independently to 0–31.
 */
export function nudgeTileHeights(level, tiles, delta) {
  if (!delta) return;
  for (const { tx, ty } of tiles) {
    const cur = getTileProps(level, tx, ty);
    if (!cur) continue;
    const next = cloneSector(cur);
    next.floorHeight = clampNum(cur.floorHeight + delta, 0, 31);
    next.ceilingHeight = clampNum(cur.ceilingHeight + delta, 0, 31);
    setTileProps(level, tx, ty, next);
  }
  rebuildSectors(level);
}

/**
 * Merge identical sectors: keep lowest id for each unique property set.
 */
export function mergeIdenticalSectors(level) {
  const reps = []; // { sector, id }
  /** @type {Map<number, number>} oldId -> newId */
  const remap = new Map();

  const ids = [...level.sectors.keys()].sort((a, b) => a - b);
  for (const id of ids) {
    const s = level.sectors.get(id);
    let found = null;
    for (const r of reps) {
      if (sectorsEqual(r.sector, s)) {
        found = r.id;
        break;
      }
    }
    if (found != null) {
      remap.set(id, found);
    } else {
      reps.push({ sector: s, id });
      remap.set(id, id);
    }
  }

  for (let i = 0; i < MAP_CELLS; i++) {
    const id = level.map[i];
    if (id && remap.has(id)) level.map[i] = remap.get(id);
  }

  for (const id of ids) {
    if (remap.get(id) !== id) level.sectors.delete(id);
  }
}

/**
 * Merge identical sectors and drop unused records.
 * Call after any tile property edit.
 */
export function rebuildSectors(level) {
  mergeIdenticalSectors(level);
  for (const id of [...level.sectors.keys()]) {
    if (sectorCellCount(level, id) === 0) level.sectors.delete(id);
  }
}

export function sectorCount(level) {
  return level.sectors.size;
}

/** All map cells that use the given sector id. */
export function tilesInSector(level, sectorId) {
  const out = [];
  if (!sectorId) return out;
  for (let ty = 0; ty < MAP_SIZE; ty++) {
    for (let tx = 0; tx < MAP_SIZE; tx++) {
      if (getCell(level, tx, ty) === sectorId) out.push({ tx, ty });
    }
  }
  return out;
}

export function getTileProps(level, tx, ty) {
  const id = getCell(level, tx, ty);
  if (!id || !level.sectors.has(id)) return null;
  return cloneSector(level.sectors.get(id));
}

/** Place props on a tile (allocates a fresh sector id). Returns id or 0. */
export function setTileProps(level, tx, ty, props) {
  const old = getCell(level, tx, ty);
  const id = allocSectorId(level);
  if (!id) return 0;
  level.sectors.set(id, cloneSector(props));
  setCell(level, tx, ty, id);
  dropSectorIfEmpty(level, old);
  return id;
}

/**
 * Add a tile at (tx,ty). Uses brush props if provided, else default.
 * Rebuilds sectors afterward. Returns true on success.
 */
export function addTile(level, tx, ty, brush = null) {
  const props = brush ? cloneSector(brush) : defaultSector();
  if (!setTileProps(level, tx, ty, props)) return false;
  rebuildSectors(level);
  return true;
}

/**
 * Apply a property patch to all listed tiles. Empty tiles are skipped.
 * Rebuilds sectors afterward.
 */
export function applyTilePatch(level, tiles, patch) {
  for (const { tx, ty } of tiles) {
    const cur = getTileProps(level, tx, ty);
    if (!cur) continue;
    const next = cloneSector(cur);
    if ('floorHeight' in patch) next.floorHeight = clampNum(patch.floorHeight, 0, 31);
    if ('ceilingHeight' in patch) next.ceilingHeight = clampNum(patch.ceilingHeight, 0, 31);
    if ('sectorType' in patch) next.sectorType = clampNum(patch.sectorType, 0, 255);
    if ('tag' in patch) next.tag = String(patch.tag ?? '').trim();
    if ('targetTag' in patch) next.targetTag = String(patch.targetTag ?? '').trim();
    if ('brightness' in patch) next.brightness = clampNum(patch.brightness, 0, 7);
    if ('floorColor' in patch) next.floorColor = normalizeColor(patch.floorColor);
    if ('ceilingColor' in patch) next.ceilingColor = normalizeColor(patch.ceilingColor);
    setTileProps(level, tx, ty, next);
  }
  rebuildSectors(level);
}

/** Clear multiple tiles, then rebuild. */
export function clearTiles(level, tiles) {
  for (const { tx, ty } of tiles) clearTile(level, tx, ty);
  rebuildSectors(level);
}

/**
 * Move tiles by (dtx, dty). Off-map tiles are deleted.
 * Returns the new tile positions that remain on the map.
 */
export function moveTiles(level, tiles, dtx, dty) {
  if (!dtx && !dty) return tiles.map((t) => ({ ...t }));

  const entries = [];
  for (const { tx, ty } of tiles) {
    const props = getTileProps(level, tx, ty);
    if (!props) continue;
    entries.push({ tx, ty, props });
  }

  for (const e of entries) clearTile(level, e.tx, e.ty);

  const placed = [];
  for (const e of entries) {
    const ntx = e.tx + dtx;
    const nty = e.ty + dty;
    if (ntx < 0 || ntx >= MAP_SIZE || nty < 0 || nty >= MAP_SIZE) continue;
    setTileProps(level, ntx, nty, e.props);
    placed.push({ tx: ntx, ty: nty });
  }
  rebuildSectors(level);
  return placed;
}

/**
 * Move items by world delta. Removes items that leave the map.
 * Returns the items that remain.
 */
export function moveItemsBy(level, items, dx, dy) {
  const kept = [];
  for (const it of items) {
    const nx = it.x + dx;
    const ny = it.y + dy;
    if (nx < 0 || nx > WORLD_MAX || ny < 0 || ny > WORLD_MAX) {
      removeItem(level, it);
      continue;
    }
    it.x = nx;
    it.y = ny;
    kept.push(it);
  }
  return kept;
}

function clampNum(v, lo, hi) {
  return Math.max(lo, Math.min(hi, Number(v) || 0));
}

export function tileKey(tx, ty) {
  return `${tx},${ty}`;
}

export function parseTileKey(key) {
  const [tx, ty] = key.split(',').map(Number);
  return { tx, ty };
}

/** Merge source sector into target (all source cells become target). */
export function mergeSectors(level, targetId, sourceId) {
  if (targetId === sourceId || !targetId || !sourceId) return;
  if (!level.sectors.has(targetId) || !level.sectors.has(sourceId)) return;
  for (let i = 0; i < MAP_CELLS; i++) {
    if (level.map[i] === sourceId) level.map[i] = targetId;
  }
  level.sectors.delete(sourceId);
}

export function hasSpawn(level) {
  return level.items.some((it) => it.type === 'spawn');
}

export function addItem(level, type, x, y, skills = defaultSkills()) {
  if (type === CAMERA_TYPE) {
    const item = {
      type: CAMERA_TYPE,
      x: clampWorld(x),
      y: clampWorld(y),
      angle: 0,
    };
    level.items.push(item);
    return item;
  }
  if (gameItemCount(level) >= MAX_ITEMS) return null;
  if (type === 'spawn' && hasSpawn(level)) return null;
  const item = {
    type,
    x: clampWorld(x),
    y: clampWorld(y),
    skills: { ...skills },
  };
  level.items.push(item);
  return item;
}

export function removeItem(level, item) {
  const i = level.items.indexOf(item);
  if (i >= 0) level.items.splice(i, 1);
}

export function moveItem(level, item, x, y) {
  item.x = clampWorld(x);
  item.y = clampWorld(y);
}

export function activeLevel(episode) {
  return episode.levels[episode.activeLevel];
}

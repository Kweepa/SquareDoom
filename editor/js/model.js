/** @typedef {number} C64Color 0–15 Commodore 64 palette index */

export const MAP_SIZE = 32;
export const MAP_CELLS = MAP_SIZE * MAP_SIZE;
export const MAX_SECTORS = 255;
export const MAX_ITEMS = 48;
export const WORLD_PER_TILE = 8;
export const WORLD_MAX = MAP_SIZE * WORLD_PER_TILE - 1; // 255
/** Max tile span on either axis so item billboards can use signed 8-bit world deltas. */
export const MAX_SECTOR_SPAN = 15;

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

/**
 * Paint existing sector onto a cell if result stays a filled ≤15×15 rectangle.
 * Returns true on success.
 */
export function paintSector(level, tx, ty, sectorId) {
  if (!level.sectors.has(sectorId)) return false;
  if (!canAddTileToSector(level, sectorId, tx, ty)) return false;
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
 * Merge identical sectors only when the unified tile set is a filled ≤15×15 rectangle.
 * Invalid / non-mergeable groups keep separate ids (lowest id kept as rep).
 */
export function mergeIdenticalSectors(level) {
  // First split any already-invalid ids into shape-legal pieces
  enforceSectorShapes(level);

  const ids = [...level.sectors.keys()].sort((a, b) => a - b);
  /** @type {Map<number, number>} */
  const remap = new Map();
  /** @type {{ sector: object, id: number, tiles: {tx:number,ty:number}[] }[]} */
  const reps = [];

  for (const id of ids) {
    const s = level.sectors.get(id);
    if (!s) continue;
    const tiles = tilesInSector(level, id);
    if (!tiles.length) continue;
    let found = null;
    for (const r of reps) {
      if (!sectorsEqual(r.sector, s)) continue;
      const union = r.tiles.concat(tiles);
      if (!tilesAreValidSectorShape(union)) continue;
      found = r;
      break;
    }
    if (found) {
      remap.set(id, found.id);
      found.tiles = found.tiles.concat(tiles);
    } else {
      reps.push({ sector: s, id, tiles: tiles.slice() });
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

/** @param {{tx:number,ty:number}[]} tiles */
export function sectorBounds(tiles) {
  if (!tiles.length) return null;
  let minX = tiles[0].tx;
  let maxX = tiles[0].tx;
  let minY = tiles[0].ty;
  let maxY = tiles[0].ty;
  for (let i = 1; i < tiles.length; i++) {
    const t = tiles[i];
    if (t.tx < minX) minX = t.tx;
    if (t.tx > maxX) maxX = t.tx;
    if (t.ty < minY) minY = t.ty;
    if (t.ty > maxY) maxY = t.ty;
  }
  return { minX, maxX, minY, maxY, w: maxX - minX + 1, h: maxY - minY + 1 };
}

/** @param {{tx:number,ty:number}[]} tiles */
export function tilesFitSpan(tiles) {
  const b = sectorBounds(tiles);
  if (!b) return true;
  return b.w <= MAX_SECTOR_SPAN && b.h <= MAX_SECTOR_SPAN;
}

/**
 * Grid-convex: filled axis-aligned rectangle (no dents/L/C shapes).
 * Needed so SEC_SEEN cannot reveal items around a corner within one id.
 */
export function tilesAreConvex(tiles) {
  if (tiles.length <= 1) return true;
  const b = sectorBounds(tiles);
  if (!b || tiles.length !== b.w * b.h) return false;
  const keys = new Set(tiles.map((t) => tileKey(t.tx, t.ty)));
  for (let ty = b.minY; ty <= b.maxY; ty++) {
    for (let tx = b.minX; tx <= b.maxX; tx++) {
      if (!keys.has(tileKey(tx, ty))) return false;
    }
  }
  return true;
}

/** Contiguous filled rectangle within MAX_SECTOR_SPAN. */
export function tilesAreValidSectorShape(tiles) {
  return tilesAreConvex(tiles) && tilesFitSpan(tiles);
}

/** 4-connected contiguity. Empty set is contiguous. */
export function tilesAreContiguous(tiles) {
  if (tiles.length <= 1) return true;
  const keys = new Set(tiles.map((t) => tileKey(t.tx, t.ty)));
  const start = tileKey(tiles[0].tx, tiles[0].ty);
  const seen = new Set([start]);
  const q = [start];
  const dirs = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];
  while (q.length) {
    const { tx, ty } = parseTileKey(q.shift());
    for (const [dx, dy] of dirs) {
      const nk = tileKey(tx + dx, ty + dy);
      if (!keys.has(nk) || seen.has(nk)) continue;
      seen.add(nk);
      q.push(nk);
    }
  }
  return seen.size === keys.size;
}

export function sectorIsContiguous(level, sectorId) {
  return tilesAreContiguous(tilesInSector(level, sectorId));
}

export function sectorIsConvex(level, sectorId) {
  return tilesAreConvex(tilesInSector(level, sectorId));
}

/**
 * True if painting sectorId onto (tx,ty) keeps a filled ≤15×15 rectangle.
 * Already owning the cell is always ok.
 */
export function canAddTileToSector(level, sectorId, tx, ty) {
  if (!sectorId || !level.sectors.has(sectorId)) return false;
  if (getCell(level, tx, ty) === sectorId) return true;
  const tiles = tilesInSector(level, sectorId);
  if (!tiles.length) return true;
  return tilesAreValidSectorShape(tiles.concat([{ tx, ty }]));
}

/**
 * Partition tiles into filled rectangles each ≤ MAX_SECTOR_SPAN on either axis.
 * @param {{tx:number,ty:number}[]} tiles
 * @returns {{tx:number,ty:number}[][]}
 */
export function splitTilesIntoValidChunks(tiles) {
  if (!tiles.length) return [];
  const remaining = new Set(tiles.map((t) => tileKey(t.tx, t.ty)));
  /** @type {{tx:number,ty:number}[][]} */
  const chunks = [];

  while (remaining.size) {
    let x0 = MAP_SIZE;
    let y0 = MAP_SIZE;
    for (const k of remaining) {
      const { tx, ty } = parseTileKey(k);
      if (ty < y0 || (ty === y0 && tx < x0)) {
        x0 = tx;
        y0 = ty;
      }
    }
    let maxW = 0;
    while (
      maxW < MAX_SECTOR_SPAN &&
      remaining.has(tileKey(x0 + maxW, y0))
    ) {
      maxW++;
    }
    let bestW = 1;
    let bestH = 1;
    for (let w = maxW; w >= 1; w--) {
      let h = 0;
      growH: while (h < MAX_SECTOR_SPAN) {
        for (let x = x0; x < x0 + w; x++) {
          if (!remaining.has(tileKey(x, y0 + h))) break growH;
        }
        h++;
      }
      if (h > 0 && w * h >= bestW * bestH) {
        bestW = w;
        bestH = h;
      }
    }
    /** @type {{tx:number,ty:number}[]} */
    const chunk = [];
    for (let ty = y0; ty < y0 + bestH; ty++) {
      for (let tx = x0; tx < x0 + bestW; tx++) {
        remaining.delete(tileKey(tx, ty));
        chunk.push({ tx, ty });
      }
    }
    chunks.push(chunk);
  }
  return chunks;
}

/**
 * Remap tiles of sectorId onto filled ≤15×15 rectangles (first keeps id).
 * @returns {string[]} warning messages
 */
export function splitSectorIntoContiguousComponents(level, sectorId) {
  /** @type {string[]} */
  const warnings = [];
  const tiles = tilesInSector(level, sectorId);
  if (!tiles.length) return warnings;
  if (tilesAreValidSectorShape(tiles)) return warnings;

  const chunks = splitTilesIntoValidChunks(tiles);
  if (chunks.length <= 1) return warnings;

  const src = level.sectors.get(sectorId);
  if (!src) return warnings;

  for (let i = 1; i < chunks.length; i++) {
    const nid = allocSectorId(level);
    if (!nid) {
      warnings.push(`Sector ${sectorId}: no free ids to split remaining tiles`);
      break;
    }
    level.sectors.set(nid, cloneSector(src));
    for (const { tx, ty } of chunks[i]) {
      setCell(level, tx, ty, nid);
    }
    warnings.push(
      `Sector ${sectorId}: split rect onto id ${nid} (${chunks[i].length} tiles)`,
    );
  }
  return warnings;
}

/**
 * Fix every sector that is non-rectangular or larger than MAX_SECTOR_SPAN.
 * @returns {string[]}
 */
export function enforceSectorShapes(level) {
  /** @type {string[]} */
  const warnings = [];
  const ids = [...level.sectors.keys()].sort((a, b) => a - b);
  for (const id of ids) {
    warnings.push(...splitSectorIntoContiguousComponents(level, id));
  }
  return warnings;
}

/**
 * @returns {{ ok: boolean, issues: string[] }}
 */
export function validateAllSectors(level) {
  /** @type {string[]} */
  const issues = [];
  for (const id of [...level.sectors.keys()].sort((a, b) => a - b)) {
    const tiles = tilesInSector(level, id);
    if (!tiles.length) continue;
    if (!tilesAreConvex(tiles)) {
      issues.push(`Sector ${id}: not a filled rectangle (convex)`);
    }
    const b = sectorBounds(tiles);
    if (b && (b.w > MAX_SECTOR_SPAN || b.h > MAX_SECTOR_SPAN)) {
      issues.push(`Sector ${id}: bbox ${b.w}×${b.h} exceeds ${MAX_SECTOR_SPAN}`);
    }
  }
  return { ok: issues.length === 0, issues };
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
 * Prefers extending an adjacent matching sector when legal; otherwise new id.
 * Returns true on success, false if no free id.
 * Sets level._lastPaintNote when extend was skipped due to span/convexity.
 */
export function addTile(level, tx, ty, brush = null) {
  level._lastPaintNote = null;
  const props = brush ? cloneSector(brush) : defaultSector();

  if (brush) {
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];
    /** @type {number[]} */
    const matching = [];
    for (const [dx, dy] of dirs) {
      const nx = tx + dx;
      const ny = ty + dy;
      if (nx < 0 || ny < 0 || nx >= MAP_SIZE || ny >= MAP_SIZE) continue;
      const nid = getCell(level, nx, ny);
      if (!nid) continue;
      const s = level.sectors.get(nid);
      if (s && sectorsEqual(s, props)) matching.push(nid);
    }
    for (const nid of matching) {
      if (canAddTileToSector(level, nid, tx, ty)) {
        paintSector(level, tx, ty, nid);
        rebuildSectors(level);
        return true;
      }
    }
    if (matching.length) {
      level._lastPaintNote =
        'New sector id: adjacent match cannot grow (must stay a ≤15×15 rectangle)';
    }
  }

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

/**
 * Merge source sector into target if union is a filled ≤15×15 rectangle.
 * Returns true on success.
 */
export function mergeSectors(level, targetId, sourceId) {
  if (targetId === sourceId || !targetId || !sourceId) return false;
  if (!level.sectors.has(targetId) || !level.sectors.has(sourceId)) return false;
  const union = tilesInSector(level, targetId).concat(tilesInSector(level, sourceId));
  if (!tilesAreValidSectorShape(union)) return false;
  for (let i = 0; i < MAP_CELLS; i++) {
    if (level.map[i] === sourceId) level.map[i] = targetId;
  }
  level.sectors.delete(sourceId);
  return true;
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

/** @typedef {number} C64Color 0–15 Commodore 64 palette index */

export const MAP_SIZE = 32;
export const MAP_CELLS = MAP_SIZE * MAP_SIZE;
export const MAX_SECTORS = 255;
export const MAX_ITEMS = 48;
/** Live enemy mobjs; last mobj slot is reserved for missile (matches game MAX_MOBJ). */
export const MAX_MOBJ = 32;
export const MAX_ENEMIES = MAX_MOBJ - 1;

/** Fixed cooked level-name length (ASCII, null-padded). */
export const LEVEL_NAME_LEN = 20;
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

/** Doom-style sector specials (as used by VicDoom), plus editor Door / Window / Elevator. */
export const DOOR_SECTOR_TYPE = 18;
/** Blocks player/enemy walk; shots and hitscan pass. */
export const WINDOW_SECTOR_TYPE = 19;
export const ELEVATOR_LOWER_SECTOR_TYPE = 20;
export const ELEVATOR_RAISE_SECTOR_TYPE = 21;

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
  { id: WINDOW_SECTOR_TYPE, name: 'Window' },
  { id: ELEVATOR_LOWER_SECTOR_TYPE, name: 'Elevator lower' },
  { id: ELEVATOR_RAISE_SECTOR_TYPE, name: 'Elevator raise' },
];

export function isDoorSector(sector) {
  return (sector?.sectorType ?? 0) === DOOR_SECTOR_TYPE;
}

export function isWindowSector(sector) {
  return (sector?.sectorType ?? 0) === WINDOW_SECTOR_TYPE;
}

export function isElevatorSector(sector) {
  const t = sector?.sectorType ?? 0;
  return t === ELEVATOR_LOWER_SECTOR_TYPE || t === ELEVATOR_RAISE_SECTOR_TYPE;
}

/** @deprecated Prefer always resolving non-empty targetTag when cooking. */
export function sectorTypeNeedsTarget(type) {
  const t = (type ?? 0) & 0xff;
  return t !== 0 && t !== WINDOW_SECTOR_TYPE;
}

export const ITEM_TYPES = [
  'spawn', 'soldier', 'imp', 'pinky', 'caco', 'baron', 'barrel',
  'health', 'shells', 'shotgun', 'chaingun', 'chainsaw',
  'greenarmor', 'bluearmor', 'backpack',
  'redcard', 'bluecard', 'yellowcard',
  'skullpile', 'techcolumn',
  'switch_opendoor', 'switch_endlevel', 'switch_lowerlift',
  'fireball',
  'poscorpse', 'impcorpse', 'demoncorpse',
];

/** Spawn stays in ITEM_TYPES for typeId/gfx index 0; not placed in the item table. */
export const SPAWN_TYPE = 'spawn';
export const CAMERA_TYPE = 'camera';
/** Palette placeable; fans out to switch_* cook types. */
export const SWITCH_TYPE = 'switch';
/** Runtime-only (missile / death corpses); not placeable in the editor. */
export const FIREBALL_TYPE = 'fireball';
export const RUNTIME_ONLY_TYPES = new Set(['fireball', 'poscorpse', 'impcorpse', 'demoncorpse']);

/** Types that allocate an mobj at level start (missile excluded). */
export const ENEMY_TYPES = new Set(['soldier', 'imp', 'pinky', 'caco', 'baron']);

/** Switch actions → cooked ITEM_TYPES entries (share switch.png). */
export const SWITCH_ACTIONS = [
  { id: 'open_door', name: 'Open door', cookType: 'switch_opendoor' },
  { id: 'end_level', name: 'End level', cookType: 'switch_endlevel' },
  { id: 'lower_lift', name: 'Lower lift', cookType: 'switch_lowerlift' },
];

const SWITCH_COOK_TYPES = new Set(SWITCH_ACTIONS.map((a) => a.cookType));

/** Palette + map placement (spawn is level.spawn; camera is editor-only). */
export const EDITOR_ITEM_TYPES = [
  ...ITEM_TYPES.filter((t) => !SWITCH_COOK_TYPES.has(t) && !RUNTIME_ONLY_TYPES.has(t)),
  SWITCH_TYPE,
  CAMERA_TYPE,
];

export function isGameItem(type) {
  return type !== CAMERA_TYPE && type !== SPAWN_TYPE;
}

export function isCamera(item) {
  return item?.type === CAMERA_TYPE;
}

export function isSpawn(item) {
  return item?.type === SPAWN_TYPE;
}

export function isSwitchCookType(type) {
  return SWITCH_COOK_TYPES.has(type);
}

export function isSwitch(item) {
  return item?.type === SWITCH_TYPE || isSwitchCookType(item?.type);
}

export function defaultSwitchAction() {
  return SWITCH_ACTIONS[0].id;
}

export function normalizeSwitchAction(action) {
  if (SWITCH_ACTIONS.some((a) => a.id === action)) return action;
  const byCook = SWITCH_ACTIONS.find((a) => a.cookType === action);
  return byCook?.id ?? defaultSwitchAction();
}

export function switchCookType(action) {
  const a = SWITCH_ACTIONS.find((x) => x.id === normalizeSwitchAction(action));
  return a.cookType;
}

/** Map legacy/cook type ids to editor switch fields. */
export function coerceSwitchItem(it) {
  if (it.type === SWITCH_TYPE) {
    return {
      type: SWITCH_TYPE,
      x: it.x,
      y: it.y,
      switchAction: normalizeSwitchAction(it.switchAction),
      targetTag: String(it.targetTag ?? '').trim(),
    };
  }
  if (isSwitchCookType(it.type)) {
    return {
      type: SWITCH_TYPE,
      x: it.x,
      y: it.y,
      switchAction: normalizeSwitchAction(it.type),
      targetTag: String(it.targetTag ?? '').trim(),
    };
  }
  return null;
}

/** Radians ↔ cooked playera byte (0..255 full circle). */
export function angleToByte(rad) {
  const t = Number(rad) || 0;
  return ((Math.round((t / (Math.PI * 2)) * 256) % 256) + 256) % 256;
}

export function byteToAngle(b) {
  return ((b & 0xff) / 256) * Math.PI * 2;
}

export function defaultSpawn() {
  return { type: SPAWN_TYPE, x: 128, y: 128, angle: 0 };
}

export function gameItemCount(level) {
  return level.items.filter((it) => isGameItem(it.type)).length;
}

export function enemyCount(level) {
  return level.items.filter((it) => ENEMY_TYPES.has(it.type)).length;
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

/**
 * Preview viewpoint: selected spawn/camera, else first camera, else spawn.
 * @returns {{x:number,y:number,angle:number}|null}
 */
export function findPreviewCamera(level, selectedItem) {
  if (isSpawn(selectedItem) || isCamera(selectedItem)) return selectedItem;
  return level.items.find((it) => isCamera(it)) ?? level.spawn ?? null;
}

/** Map markers: spawn first, then items (for hit-test topmost). */
export function mapMarkers(level) {
  return level.spawn ? [level.spawn, ...level.items] : [...level.items];
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
    floorColor: 11,
    ceilingColor: 11,
    brightness: 15,
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

export function clampLevelName(name) {
  return String(name ?? '').trim().slice(0, LEVEL_NAME_LEN);
}

export function createEmptyLevel() {
  return {
    /** Display name (max LEVEL_NAME_LEN); editor JSON only (not in cooked binary). */
    name: '',
    /** @type {Map<number, ReturnType<typeof defaultSector>>} sectorId -> data (1..255) */
    sectors: new Map(),
    /** @type {Uint8Array} */
    map: new Uint8Array(MAP_CELLS),
    /** Player start — always present; cooked separately from items. */
    spawn: defaultSpawn(),
    /** @type {Array<{type:string,x:number,y:number,skills?:object,angle?:number}>} */
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

  if (level.spawn) {
    const sx = level.spawn.x + dx * WORLD_PER_TILE;
    const sy = level.spawn.y + dy * WORLD_PER_TILE;
    if (sx >= 0 && sx <= WORLD_MAX && sy >= 0 && sy <= WORLD_MAX) {
      level.spawn.x = sx;
      level.spawn.y = sy;
    }
  }
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
 * Group occupied selected tiles by their current sector id.
 * @param {{tx:number,ty:number}[]} tiles
 * @returns {Map<number, {tx:number,ty:number}[]>}
 */
function groupTilesBySector(level, tiles) {
  /** @type {Map<number, {tx:number,ty:number}[]>} */
  const bySector = new Map();
  for (const { tx, ty } of tiles) {
    const id = getCell(level, tx, ty);
    if (!id || !level.sectors.has(id)) continue;
    let list = bySector.get(id);
    if (!list) {
      list = [];
      bySector.set(id, list);
    }
    list.push({ tx, ty });
  }
  return bySector;
}

/**
 * Apply new props per selected sector: mutate in place when the whole sector is
 * selected, otherwise one fresh id for the selection (avoids per-tile alloc).
 * @param {Map<number, {tx:number,ty:number}[]>} bySector
 * @param {(cur: ReturnType<typeof defaultSector>) => ReturnType<typeof defaultSector>} nextProps
 */
function applyPropsBySector(level, bySector, nextProps) {
  for (const [sectorId, selected] of bySector) {
    const cur = level.sectors.get(sectorId);
    if (!cur) continue;
    const next = nextProps(cur);
    const total = sectorCellCount(level, sectorId);
    if (selected.length >= total) {
      level.sectors.set(sectorId, next);
      continue;
    }
    const nid = allocSectorId(level);
    if (!nid) continue;
    level.sectors.set(nid, next);
    for (const { tx, ty } of selected) setCell(level, tx, ty, nid);
    dropSectorIfEmpty(level, sectorId);
  }
}

/**
 * Raise/lower floor and ceiling together by delta on listed tiles.
 * Each height is clamped independently to 0–31.
 */
export function nudgeTileHeights(level, tiles, delta) {
  if (!delta) return;
  applyPropsBySector(level, groupTilesBySector(level, tiles), (cur) => {
    const next = cloneSector(cur);
    next.floorHeight = clampNum(cur.floorHeight + delta, 0, 31);
    next.ceilingHeight = clampNum(cur.ceilingHeight + delta, 0, 31);
    return next;
  });
  rebuildSectors(level);
}

const NEIGHBOR_4 = [
  [1, 0],
  [-1, 0],
  [0, 1],
  [0, -1],
];

/**
 * 4-connected groups of tiles whose sector props match via sectorsEqual.
 * @returns {{ props: ReturnType<typeof defaultSector>, tiles: {tx:number,ty:number}[], oldIds: number[] }[]}
 */
export function equalPropConnectedComponents(level) {
  const visited = new Uint8Array(MAP_CELLS);
  /** @type {{ props: ReturnType<typeof defaultSector>, tiles: {tx:number,ty:number}[], oldIds: number[] }[]} */
  const components = [];

  for (let ty = 0; ty < MAP_SIZE; ty++) {
    for (let tx = 0; tx < MAP_SIZE; tx++) {
      const start = cellIndex(tx, ty);
      const startId = level.map[start];
      if (!startId || visited[start]) continue;
      const props = level.sectors.get(startId);
      if (!props) {
        level.map[start] = 0;
        continue;
      }

      /** @type {{tx:number,ty:number}[]} */
      const tiles = [];
      const oldIdSet = new Set();
      /** @type {{tx:number,ty:number}[]} */
      const stack = [{ tx, ty }];
      visited[start] = 1;

      while (stack.length) {
        const cur = stack.pop();
        const cid = getCell(level, cur.tx, cur.ty);
        tiles.push(cur);
        oldIdSet.add(cid);
        for (const [dx, dy] of NEIGHBOR_4) {
          const nx = cur.tx + dx;
          const ny = cur.ty + dy;
          if (nx < 0 || ny < 0 || nx >= MAP_SIZE || ny >= MAP_SIZE) continue;
          const nidx = cellIndex(nx, ny);
          if (visited[nidx]) continue;
          const nid = level.map[nidx];
          if (!nid) continue;
          const np = level.sectors.get(nid);
          if (!np || !sectorsEqual(props, np)) continue;
          visited[nidx] = 1;
          stack.push({ tx: nx, ty: ny });
        }
      }

      components.push({
        props: cloneSector(props),
        tiles,
        oldIds: [...oldIdSet].sort((a, b) => a - b),
      });
    }
  }
  return components;
}

/**
 * Repack identical-property connected tiles into filled ≤15×15 rectangles.
 * @param {{ optimal?: boolean }} [opts] optimal (default false) runs slow min-cover;
 *   interactive edits use strip packing only.
 */
export function mergeIdenticalSectors(level, opts = {}) {
  const optimal = !!opts.optimal;
  const components = equalPropConnectedComponents(level);
  /** @type {{ id: number, props: ReturnType<typeof defaultSector>, tiles: {tx:number,ty:number}[] }[]} */
  const assignments = [];
  /** @type {{ props: ReturnType<typeof defaultSector>, tiles: {tx:number,ty:number}[] }[]} */
  const pending = [];
  const claimed = new Set();

  for (const comp of components) {
    /** @type {{tx:number,ty:number}[][] | null} */
    let seed = null;
    let seedOk = true;
    /** @type {Map<number, {tx:number,ty:number}[]>} */
    const byId = new Map();
    for (const t of comp.tiles) {
      const id = getCell(level, t.tx, t.ty);
      let list = byId.get(id);
      if (!list) {
        list = [];
        byId.set(id, list);
      }
      list.push(t);
    }
    for (const id of comp.oldIds) {
      const tiles = byId.get(id);
      if (!tiles || !tilesAreValidSectorShape(tiles)) {
        seedOk = false;
        break;
      }
    }
    if (seedOk) {
      seed = comp.oldIds.map((id) => byId.get(id)).filter(Boolean);
    }

    const parts = partitionTilesIntoMinRectangles(comp.tiles, seed, { optimal });
    let oi = 0;
    for (const chunk of parts) {
      let id = 0;
      while (oi < comp.oldIds.length) {
        const cand = comp.oldIds[oi++];
        if (!claimed.has(cand)) {
          id = cand;
          break;
        }
      }
      if (id) {
        claimed.add(id);
        assignments.push({ id, props: cloneSector(comp.props), tiles: chunk });
      } else {
        pending.push({ props: cloneSector(comp.props), tiles: chunk });
      }
    }
  }

  for (const p of pending) {
    let id = 0;
    for (let n = 1; n <= MAX_SECTORS; n++) {
      if (!claimed.has(n)) {
        id = n;
        break;
      }
    }
    if (!id) break;
    claimed.add(id);
    assignments.push({ id, props: p.props, tiles: p.tiles });
  }

  level.map.fill(0);
  level.sectors.clear();
  for (const a of assignments) {
    level.sectors.set(a.id, a.props);
    for (const { tx, ty } of a.tiles) {
      setCell(level, tx, ty, a.id);
    }
  }
}

/**
 * Repack sectors into valid rectangles and drop unused records.
 * Call after any tile property edit (strip-fast). Pass { optimal: true } before save.
 * @param {{ optimal?: boolean }} [opts]
 */
export function rebuildSectors(level, opts = {}) {
  mergeIdenticalSectors(level, opts);
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
 * Partition via row-runs merged vertically when x-range matches (or transposed).
 * Respects MAX_SECTOR_SPAN. Fast upper bound, not always minimal with holes.
 * @param {{tx:number,ty:number}[]} tiles
 * @param {boolean} transpose
 * @returns {{tx:number,ty:number}[][]}
 */
export function stripPartitionTiles(tiles, transpose = false) {
  if (!tiles.length) return [];
  const pts = transpose
    ? tiles.map((t) => ({ tx: t.ty, ty: t.tx }))
    : tiles.map((t) => ({ tx: t.tx, ty: t.ty }));
  const keys = new Set(pts.map((t) => tileKey(t.tx, t.ty)));
  const b = sectorBounds(pts);
  if (!b) return [];

  /** @type {{ y: number, x0: number, x1: number }[]} */
  const runs = [];
  for (let y = b.minY; y <= b.maxY; y++) {
    let x = b.minX;
    while (x <= b.maxX) {
      while (x <= b.maxX && !keys.has(tileKey(x, y))) x++;
      if (x > b.maxX) break;
      const x0 = x;
      while (x <= b.maxX && keys.has(tileKey(x, y))) x++;
      runs.push({ y, x0, x1: x - 1 });
    }
  }

  const used = new Array(runs.length).fill(false);
  /** @type {{ x0: number, x1: number, y0: number, y1: number }[]} */
  const rects = [];
  for (let i = 0; i < runs.length; i++) {
    if (used[i]) continue;
    const { y, x0, x1 } = runs[i];
    let y1 = y;
    used[i] = true;
    let growing = true;
    while (growing) {
      growing = false;
      if (y1 - y + 1 >= MAX_SECTOR_SPAN) break;
      for (let j = i + 1; j < runs.length; j++) {
        if (used[j]) continue;
        const r = runs[j];
        if (r.y === y1 + 1 && r.x0 === x0 && r.x1 === x1) {
          used[j] = true;
          y1 = r.y;
          growing = true;
          break;
        }
      }
    }
    for (let xa = x0; xa <= x1; xa += MAX_SECTOR_SPAN) {
      const xb = Math.min(x1, xa + MAX_SECTOR_SPAN - 1);
      for (let ya = y; ya <= y1; ya += MAX_SECTOR_SPAN) {
        const yb = Math.min(y1, ya + MAX_SECTOR_SPAN - 1);
        rects.push({ x0: xa, x1: xb, y0: ya, y1: yb });
      }
    }
  }

  return rects.map(({ x0, x1, y0, y1 }) => {
    /** @type {{tx:number,ty:number}[]} */
    const part = [];
    for (let ty = y0; ty <= y1; ty++) {
      for (let tx = x0; tx <= x1; tx++) {
        part.push(transpose ? { tx: ty, ty: tx } : { tx, ty });
      }
    }
    return part;
  });
}

function popcountBigInt(x) {
  let n = 0;
  let v = x;
  while (v) {
    v &= v - 1n;
    n++;
  }
  return n;
}

/**
 * Minimum partition into filled ≤MAX_SECTOR_SPAN rectangles.
 * Fast path (optimal: false): strip H/V + keep seed if tighter.
 * Optimal path: bounded exact-cover DFS + randomized restarts.
 * @param {{tx:number,ty:number}[]} tiles
 * @param {{tx:number,ty:number}[][]} [seedParts] optional known valid partition
 * @param {{ optimal?: boolean }} [opts]
 * @returns {{tx:number,ty:number}[][]}
 */
export function partitionTilesIntoMinRectangles(tiles, seedParts = null, opts = {}) {
  const optimal = opts.optimal === true;
  if (!tiles.length) return [];
  if (tiles.length === 1) return [[{ tx: tiles[0].tx, ty: tiles[0].ty }]];

  const ordered = tiles.slice().sort((a, b) => a.ty - b.ty || a.tx - b.tx);
  if (tilesAreValidSectorShape(ordered)) return [ordered.map((t) => ({ ...t }))];

  const n = ordered.length;
  /** @type {Map<string, number>} */
  const indexOf = new Map();
  for (let i = 0; i < n; i++) {
    indexOf.set(tileKey(ordered[i].tx, ordered[i].ty), i);
  }
  const has = (tx, ty) => indexOf.has(tileKey(tx, ty));

  const stripH = stripPartitionTiles(ordered, false);
  const stripV = stripPartitionTiles(ordered, true);
  /** @type {{tx:number,ty:number}[][]} */
  let bestParts = stripH.length <= stripV.length ? stripH : stripV;
  let best = bestParts.length;

  if (
    Array.isArray(seedParts) &&
    seedParts.length > 0 &&
    seedParts.length < best &&
    seedParts.every((p) => tilesAreValidSectorShape(p))
  ) {
    best = seedParts.length;
    bestParts = seedParts.map((p) => p.map((t) => ({ ...t })));
  }

  if (!optimal) return bestParts;

  const areaCap = MAX_SECTOR_SPAN * MAX_SECTOR_SPAN;
  const minPossible = Math.ceil(n / areaCap);
  if (best <= minPossible) return bestParts;

  /** @type {{ mask: bigint, area: number }[]} */
  const cands = [];
  for (let i = 0; i < n; i++) {
    const { tx: x0, ty: y0 } = ordered[i];
    for (let h = 1; h <= MAX_SECTOR_SPAN; h++) {
      if (!has(x0, y0 + h - 1)) break;
      let maxW = MAX_SECTOR_SPAN;
      for (let dy = 0; dy < h; dy++) {
        let rowW = 0;
        while (rowW < maxW && has(x0 + rowW, y0 + dy)) rowW++;
        if (rowW < maxW) maxW = rowW;
        if (!maxW) break;
      }
      for (let w = 1; w <= maxW; w++) {
        let mask = 0n;
        for (let dy = 0; dy < h; dy++) {
          for (let dx = 0; dx < w; dx++) {
            mask |= 1n << BigInt(indexOf.get(tileKey(x0 + dx, y0 + dy)));
          }
        }
        cands.push({ mask, area: w * h });
      }
    }
  }
  cands.sort((a, b) => b.area - a.area);

  /** @type {number[][]} */
  const coverOf = Array.from({ length: n }, () => []);
  for (let ci = 0; ci < cands.length; ci++) {
    let m = cands[ci].mask;
    let bit = 0;
    while (m) {
      if (m & 1n) coverOf[bit].push(ci);
      m >>= 1n;
      bit++;
    }
  }

  function partsFromMasks(masks) {
    return masks.map((mask) => {
      /** @type {{tx:number,ty:number}[]} */
      const part = [];
      for (let i = 0; i < n; i++) {
        if (mask & (1n << BigInt(i))) part.push({ ...ordered[i] });
      }
      return part;
    });
  }

  /** @type {bigint[]} */
  const chosen = [];
  const full = (1n << BigInt(n)) - 1n;
  let nodes = 0;
  const nodeLimit = 80000;

  function dfs(uncovered, depth) {
    if (depth >= best) return;
    if (++nodes > nodeLimit) return;
    if (uncovered === 0n) {
      best = depth;
      bestParts = partsFromMasks(chosen);
      return;
    }
    if (depth + Math.ceil(popcountBigInt(uncovered) / areaCap) >= best) return;

    let bit = -1;
    let fewest = Infinity;
    for (let i = 0; i < n; i++) {
      if ((uncovered & (1n << BigInt(i))) === 0n) continue;
      let count = 0;
      for (const ci of coverOf[i]) {
        if ((cands[ci].mask & uncovered) === cands[ci].mask) count++;
      }
      if (count < fewest) {
        fewest = count;
        bit = i;
        if (count <= 1) break;
      }
    }
    if (bit < 0 || fewest === 0) return;

    for (const ci of coverOf[bit]) {
      const { mask } = cands[ci];
      if ((mask & uncovered) !== mask) continue;
      chosen.push(mask);
      dfs(uncovered ^ mask, depth + 1);
      chosen.pop();
      if (best <= minPossible || nodes > nodeLimit) return;
    }
  }

  dfs(full, 0);
  if (best <= minPossible) return bestParts;

  // Randomized greedy restarts — finds covers the bounded DFS misses (e.g. holed regions).
  const seeded = Array.isArray(seedParts) && seedParts.length > 0;
  const restartLimit = seeded
    ? Math.min(400, 40 + n * 4)
    : n >= 40
      ? 6000
      : Math.min(2500, 200 + n * 30);
  let stagnant = 0;
  for (let trial = 0; trial < restartLimit; trial++) {
    let uncovered = full;
    /** @type {bigint[]} */
    const masks = [];
    let failed = false;
    while (uncovered !== 0n) {
      if (masks.length + 1 >= best) {
        failed = true;
        break;
      }
      /** @type {number[]} */
      const bits = [];
      for (let i = 0; i < n; i++) {
        if (uncovered & (1n << BigInt(i))) bits.push(i);
      }
      let bit = bits[0];
      let fewest = Infinity;
      for (const i of bits) {
        let count = 0;
        for (const ci of coverOf[i]) {
          if ((cands[ci].mask & uncovered) === cands[ci].mask) count++;
        }
        const score = count + Math.random() * 0.75;
        if (score < fewest) {
          fewest = score;
          bit = i;
        }
      }
      /** @type {number[]} */
      const opts = [];
      for (const ci of coverOf[bit]) {
        if ((cands[ci].mask & uncovered) === cands[ci].mask) opts.push(ci);
      }
      if (!opts.length) {
        failed = true;
        break;
      }
      opts.sort((a, b) => cands[b].area - cands[a].area);
      const topN = Math.min(opts.length, 1 + ((Math.random() * 6) | 0));
      const pick = opts[(Math.random() * topN) | 0];
      masks.push(cands[pick].mask);
      uncovered ^= cands[pick].mask;
    }
    if (!failed && uncovered === 0n && masks.length < best) {
      best = masks.length;
      bestParts = partsFromMasks(masks);
      stagnant = 0;
      if (best <= minPossible) break;
      // Beating strip on a large region is enough — stop burning CPU looking for more.
      if (!seeded && n >= 40) break;
    } else if (seeded && ++stagnant > 200) {
      break;
    }
  }

  return bestParts;
}

/**
 * Partition tiles into filled rectangles each ≤ MAX_SECTOR_SPAN on either axis.
 * Greedy max-area from top-left; used for splitting a single illegal sector id.
 * Prefer partitionTilesIntoMinRectangles when minimizing sector count.
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
 * Runtime DDA assumes a sealed id-0 border so marches never leave the map array.
 * @returns {string[]} issues (empty if ok)
 */
export function validateVoidBorder(level) {
  /** @type {string[]} */
  const issues = [];
  const last = MAP_SIZE - 1;
  for (let i = 0; i < MAP_SIZE; i++) {
    if (level.map[i] !== 0) {
      issues.push(`Void border required: non-void at (${i},0)`);
    }
    if (level.map[last * MAP_SIZE + i] !== 0) {
      issues.push(`Void border required: non-void at (${i},${last})`);
    }
    if (level.map[i * MAP_SIZE] !== 0) {
      issues.push(`Void border required: non-void at (0,${i})`);
    }
    if (level.map[i * MAP_SIZE + last] !== 0) {
      issues.push(`Void border required: non-void at (${last},${i})`);
    }
  }
  return issues;
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
  applyPropsBySector(level, groupTilesBySector(level, tiles), (cur) => {
    const next = cloneSector(cur);
    if ('floorHeight' in patch) next.floorHeight = clampNum(patch.floorHeight, 0, 31);
    if ('ceilingHeight' in patch) next.ceilingHeight = clampNum(patch.ceilingHeight, 0, 31);
    if ('sectorType' in patch) next.sectorType = clampNum(patch.sectorType, 0, 255);
    if ('tag' in patch) next.tag = String(patch.tag ?? '').trim();
    if ('targetTag' in patch) next.targetTag = String(patch.targetTag ?? '').trim();
    if ('brightness' in patch) next.brightness = clampNum(patch.brightness, 0, 16);
    if ('floorColor' in patch) next.floorColor = normalizeColor(patch.floorColor);
    if ('ceilingColor' in patch) next.ceilingColor = normalizeColor(patch.ceilingColor);
    return next;
  });
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
 * Allocates at most one sector id per original sector group (not per tile).
 */
export function moveTiles(level, tiles, dtx, dty) {
  if (!dtx && !dty) return tiles.map((t) => ({ ...t }));

  /** @type {{ tx: number, ty: number, props: ReturnType<typeof defaultSector>, sectorId: number }[]} */
  const entries = [];
  for (const { tx, ty } of tiles) {
    const sectorId = getCell(level, tx, ty);
    if (!sectorId || !level.sectors.has(sectorId)) continue;
    const props = getTileProps(level, tx, ty);
    if (!props) continue;
    entries.push({ tx, ty, props, sectorId });
  }

  for (const e of entries) clearTile(level, e.tx, e.ty);

  /** @type {Map<number, { props: ReturnType<typeof defaultSector>, dests: {tx:number,ty:number}[] }>} */
  const groups = new Map();
  for (const e of entries) {
    const ntx = e.tx + dtx;
    const nty = e.ty + dty;
    if (ntx < 0 || ntx >= MAP_SIZE || nty < 0 || nty >= MAP_SIZE) continue;
    let g = groups.get(e.sectorId);
    if (!g) {
      g = { props: e.props, dests: [] };
      groups.set(e.sectorId, g);
    }
    g.dests.push({ tx: ntx, ty: nty });
  }

  const placed = [];
  for (const [oldId, g] of groups) {
    // Reuse the old id when clearTile dropped the sector (whole sector moved).
    let nid = level.sectors.has(oldId) ? 0 : oldId;
    if (!nid) nid = allocSectorId(level);
    if (!nid) break;
    level.sectors.set(nid, cloneSector(g.props));
    for (const d of g.dests) {
      const old = getCell(level, d.tx, d.ty);
      setCell(level, d.tx, d.ty, nid);
      if (old && old !== nid) dropSectorIfEmpty(level, old);
      placed.push(d);
    }
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
      if (isSpawn(it)) {
        it.x = clampWorld(nx);
        it.y = clampWorld(ny);
        kept.push(it);
      } else {
        removeItem(level, it);
      }
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
  return !!level.spawn;
}

/** Place or move the level spawn (always exactly one). */
export function setSpawn(level, x, y, angle) {
  if (!level.spawn) level.spawn = defaultSpawn();
  level.spawn.type = SPAWN_TYPE;
  level.spawn.x = clampWorld(x);
  level.spawn.y = clampWorld(y);
  if (angle !== undefined) level.spawn.angle = Number(angle) || 0;
  return level.spawn;
}

export function addItem(level, type, x, y, skills = defaultSkills()) {
  if (type === SPAWN_TYPE) {
    return setSpawn(level, x, y);
  }
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
  if (type === SWITCH_TYPE || isSwitchCookType(type)) {
    if (gameItemCount(level) >= MAX_ITEMS) return null;
    const item = {
      type: SWITCH_TYPE,
      x: clampWorld(x),
      y: clampWorld(y),
      switchAction: isSwitchCookType(type)
        ? normalizeSwitchAction(type)
        : defaultSwitchAction(),
      targetTag: '',
    };
    level.items.push(item);
    return item;
  }
  if (gameItemCount(level) >= MAX_ITEMS) return null;
  if (ENEMY_TYPES.has(type) && enemyCount(level) >= MAX_ENEMIES) return null;
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
  if (isSpawn(item)) return; // spawn is required
  const i = level.items.indexOf(item);
  if (i >= 0) level.items.splice(i, 1);
}

export function moveItem(level, item, x, y) {
  item.x = clampWorld(x);
  item.y = clampWorld(y);
}

/** True if selection ref is still on the level (spawn or items). */
export function itemStillOnLevel(level, item) {
  if (isSpawn(item)) return level.spawn === item;
  return level.items.includes(item);
}

export function activeLevel(episode) {
  return episode.levels[episode.activeLevel];
}

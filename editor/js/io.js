/**
 * Cooked binary layout (no header), per level — structure-of-arrays:
 *   1. Sector attribute tables: 7 × 256 bytes (index = sector id; byte 0 unused)
 *      order: floor, ceil, sectorType, targetSector, floorColor, ceilingColor, brightness
 *      targetSector is the resolved sector id (from editor targetTag); 0 if empty / unresolved
 *      editor tag strings are not stored in the binary
 *   2. Map: 1024 bytes sector ids
 *   3. Spawn: 3 bytes — x, y, angleByte (playera 0..255)
 *   4. Items SoA: 4 × 48 bytes — typeId[48], x[48], y[48], meta[48]
 *      meta: skillBits (bit0=easy, bit1=normal, bit2=hard) or switch target sector
 *      unused item slots: typeId=0xFF
 *      spawn is not an item (typeId 0 unused in table)
 *   5. sector_max: 1 byte — max sector id used in map or sector table
 * Display name is not in the binary (resident titles in the game PRG).
 * Colors: 0..15 = Commodore 64 palette

 * typeId: index into ITEM_TYPES (0-based); 0xFF = empty slot
 */

import {
  ITEM_TYPES,
  CAMERA_TYPE,
  SPAWN_TYPE,
  SWITCH_TYPE,
  DOOR_SECTOR_TYPE,
  isGameItem,
  isSwitch,
  coerceSwitchItem,
  switchCookType,
  LEVEL_NAMES,
  MAP_CELLS,
  MAX_ITEMS,
  MAX_ENEMIES,
  MAX_SECTORS,
  ENEMY_TYPES,
  enemyCount,
  colorIndex,
  clampLevelName,
  createEmptyLevel,
  createEpisode,
  defaultSector,
  defaultSpawn,
  findSectorIdByTag,
  gameItemCount,
  normalizeColor,
  enforceSectorShapes,
  validateVoidBorder,
  angleToByte,
  byteToAngle,
  setSpawn,
} from './model.js';

const SECTOR_TABLE_COUNT = 7;		 // floor, ceil, type, target, fcol, ccol, bright
const SECTOR_TABLE_SIZE = 256;		 // index = sector id; [0] unused
const ITEM_BYTES = 4;
const SPAWN_BYTES = 3;
const EMPTY_ITEM_TYPE = 0xff;

export function levelToJSON(level) {
  const sectorObj = {};
  for (const [id, s] of level.sectors) {
    sectorObj[String(id)] = {
      floorHeight: s.floorHeight,
      ceilingHeight: s.ceilingHeight,
      sectorType: s.sectorType ?? 0,
      tag: s.tag || '',
      targetTag: s.targetTag || '',
      floorColor: s.floorColor,
      ceilingColor: s.ceilingColor,
      brightness: s.brightness,
    };
  }
  return {
    name: clampLevelName(level.name),
    sectors: sectorObj,
    map: Array.from(level.map),
    spawn: {
      x: level.spawn?.x ?? 0,
      y: level.spawn?.y ?? 0,
      angle: level.spawn?.angle ?? 0,
    },
    items: level.items.map((it) => {
      const base = {
        type: it.type,
        x: it.x,
        y: it.y,
      };
      if (it.type === CAMERA_TYPE) {
        return { ...base, angle: it.angle ?? 0 };
      }
      if (isSwitch(it)) {
        const sw = coerceSwitchItem(it);
        return {
          type: SWITCH_TYPE,
          x: sw.x,
          y: sw.y,
          switchAction: sw.switchAction,
          targetTag: sw.targetTag,
        };
      }
      return { ...base, skills: { ...it.skills } };
    }),
  };
}

export function levelFromJSON(data) {
  const level = createEmptyLevel();
  level.name = clampLevelName(data.name);
  if (data.sectors) {
    for (const [key, s] of Object.entries(data.sectors)) {
      const id = Number(key);
      if (id < 1 || id > MAX_SECTORS) continue;
      const d = defaultSector();
      let sectorType = clamp(s.sectorType ?? d.sectorType, 0, 255);
      // Migrate legacy door checkbox → Door sector type
      if (s.door && sectorType === 0) sectorType = DOOR_SECTOR_TYPE;
      level.sectors.set(id, {
        floorHeight: clamp(s.floorHeight ?? d.floorHeight, 0, 31),
        ceilingHeight: clamp(s.ceilingHeight ?? d.ceilingHeight, 0, 31),
        sectorType,
        tag: String(s.tag ?? d.tag ?? '').trim(),
        targetTag: String(s.targetTag ?? d.targetTag ?? '').trim(),
        floorColor: normalizeColor(s.floorColor, d.floorColor),
        ceilingColor: normalizeColor(s.ceilingColor, d.ceilingColor),
        brightness: clamp(s.brightness ?? d.brightness, 0, 7),
      });
    }
  }
  if (Array.isArray(data.map) && data.map.length === MAP_CELLS) {
    for (let i = 0; i < MAP_CELLS; i++) {
      level.map[i] = data.map[i] & 0xff;
    }
  }

  // Spawn: dedicated field, or migrate legacy item type "spawn"
  let legacySpawn = null;
  if (Array.isArray(data.items)) {
    for (const it of data.items) {
      if (it.type === CAMERA_TYPE) {
        level.items.push({
          type: CAMERA_TYPE,
          x: clamp(it.x ?? 0, 0, 255),
          y: clamp(it.y ?? 0, 0, 255),
          angle: Number(it.angle) || 0,
        });
        continue;
      }
      if (it.type === SPAWN_TYPE) {
        legacySpawn = it;
        continue;
      }
      const asSwitch = coerceSwitchItem(it);
      if (asSwitch) {
        if (gameItemCount(level) >= MAX_ITEMS) break;
        level.items.push(asSwitch);
        continue;
      }
      if (!ITEM_TYPES.includes(it.type) || !isGameItem(it.type)) continue;
      if (gameItemCount(level) >= MAX_ITEMS) break;
      level.items.push({
        type: it.type,
        x: clamp(it.x ?? 0, 0, 255),
        y: clamp(it.y ?? 0, 0, 255),
        skills: {
          easy: it.skills?.easy !== false,
          normal: it.skills?.normal !== false,
          hard: it.skills?.hard !== false,
        },
      });
    }
  }

  if (data.spawn) {
    setSpawn(
      level,
      data.spawn.x ?? 0,
      data.spawn.y ?? 0,
      data.spawn.angle ?? 0,
    );
  } else if (legacySpawn) {
    // Legacy: use spawn item xy; angle from item if present, else old hardcoded playera=250
    const ang =
      legacySpawn.angle != null
        ? Number(legacySpawn.angle) || 0
        : byteToAngle(250);
    setSpawn(level, legacySpawn.x ?? 0, legacySpawn.y ?? 0, ang);
  } else {
    level.spawn = defaultSpawn();
  }

  const shapeWarnings = enforceSectorShapes(level);
  const borderIssues = validateVoidBorder(level);
  const loadWarn = [...shapeWarnings, ...borderIssues];
  if (loadWarn.length) {
    level._loadWarnings = loadWarn;
  }
  return level;
}

export function episodeToJSON(episode) {
  const levels = {};
  for (const name of LEVEL_NAMES) {
    levels[name] = levelToJSON(episode.levels[name]);
  }
  return {
    format: 'squaredoom-map',
    version: 1,
    activeLevel: episode.activeLevel,
    levels,
  };
}

export function episodeFromJSON(data) {
  const episode = createEpisode();
  if (data?.format !== 'squaredoom-map') {
    throw new Error('Unrecognized map format');
  }
  if (data.levels) {
    for (const name of LEVEL_NAMES) {
      if (data.levels[name]) {
        episode.levels[name] = levelFromJSON(data.levels[name]);
      }
    }
  }
  if (data.activeLevel && episode.levels[data.activeLevel]) {
    episode.activeLevel = data.activeLevel;
  }
  return episode;
}

export function cookLevel(level) {
  /** @type {string[]} */
  const warnings = [];
  /** @type {string[]} */
  const errors = [];
  warnings.push(...enforceSectorShapes(level));
  errors.push(...validateVoidBorder(level));

  const floors = new Uint8Array(SECTOR_TABLE_SIZE);
  const ceils = new Uint8Array(SECTOR_TABLE_SIZE);
  const types = new Uint8Array(SECTOR_TABLE_SIZE);
  const targets = new Uint8Array(SECTOR_TABLE_SIZE);
  const fcols = new Uint8Array(SECTOR_TABLE_SIZE);
  const ccols = new Uint8Array(SECTOR_TABLE_SIZE);
  const brights = new Uint8Array(SECTOR_TABLE_SIZE);

  for (let id = 1; id <= MAX_SECTORS; id++) {
    const s = level.sectors.get(id);
    if (!s) continue;
    const type = (s.sectorType ?? 0) & 0xff;
    let targetId = 0;
    const tag = (s.targetTag || '').trim();
    if (tag) {
      targetId = findSectorIdByTag(level, tag);
      if (!targetId) {
        warnings.push(`Sector ${id}: target tag "${tag}" not found`);
      }
    }
    floors[id] = s.floorHeight & 31;
    ceils[id] = s.ceilingHeight & 31;
    types[id] = type;
    targets[id] = targetId & 0xff;
    fcols[id] = colorIndex(s.floorColor) & 15;
    ccols[id] = colorIndex(s.ceilingColor) & 15;
    brights[id] = s.brightness & 7;
  }

  const mapBytes = new Uint8Array(level.map);

  const gameItems = level.items.filter((it) => isGameItem(it.type));
  const nEnemies = enemyCount(level);
  if (nEnemies > MAX_ENEMIES) {
    errors.push(`Too many enemies (${nEnemies}/${MAX_ENEMIES})`);
  }

  const typesArr = new Uint8Array(MAX_ITEMS);
  const xs = new Uint8Array(MAX_ITEMS);
  const ys = new Uint8Array(MAX_ITEMS);
  const metas = new Uint8Array(MAX_ITEMS);
  typesArr.fill(EMPTY_ITEM_TYPE);
  for (let i = 0; i < MAX_ITEMS; i++) {
    const it = gameItems[i];
    if (!it) continue;
    if (isSwitch(it)) {
      const sw = coerceSwitchItem(it);
      const cookType = switchCookType(sw.switchAction);
      const typeId = ITEM_TYPES.indexOf(cookType);
      typesArr[i] = typeId < 0 ? EMPTY_ITEM_TYPE : typeId;
      xs[i] = sw.x & 0xff;
      ys[i] = sw.y & 0xff;
      const tag = (sw.targetTag || '').trim();
      let targetId = 0;
      if (!tag) {
        warnings.push(`Switch at (${sw.x},${sw.y}): empty target tag`);
      } else {
        targetId = findSectorIdByTag(level, tag);
        if (!targetId) {
          warnings.push(`Switch at (${sw.x},${sw.y}): target tag "${tag}" not found`);
        }
      }
      metas[i] = targetId & 0xff;
      continue;
    }
    const typeId = ITEM_TYPES.indexOf(it.type);
    typesArr[i] = typeId < 0 ? EMPTY_ITEM_TYPE : typeId;
    xs[i] = it.x & 0xff;
    ys[i] = it.y & 0xff;
    let bits = 0;
    if (it.skills.easy) bits |= 1;
    if (it.skills.normal) bits |= 2;
    if (it.skills.hard) bits |= 4;
    metas[i] = bits;
  }
  const itemTable = new Uint8Array(MAX_ITEMS * ITEM_BYTES);
  itemTable.set(typesArr, 0);
  itemTable.set(xs, MAX_ITEMS);
  itemTable.set(ys, MAX_ITEMS * 2);
  itemTable.set(metas, MAX_ITEMS * 3);

  const spawn = level.spawn ?? defaultSpawn();
  const spawnBytes = new Uint8Array([
    spawn.x & 0xff,
    spawn.y & 0xff,
    angleToByte(spawn.angle),
  ]);

  // Highest sector id referenced by the map or present in the sector table
  let sectorMax = 0;
  for (let i = 0; i < mapBytes.length; i++) {
    if (mapBytes[i] > sectorMax) sectorMax = mapBytes[i];
  }
  for (const id of level.sectors.keys()) {
    if (id > sectorMax) sectorMax = id;
  }
  if (sectorMax > MAX_SECTORS) sectorMax = MAX_SECTORS;

  const sectorBytes = SECTOR_TABLE_COUNT * SECTOR_TABLE_SIZE;
  const out = new Uint8Array(
    sectorBytes + mapBytes.length + SPAWN_BYTES + itemTable.length + 1,
  );
  let o = 0;
  out.set(floors, o); o += SECTOR_TABLE_SIZE;
  out.set(ceils, o); o += SECTOR_TABLE_SIZE;
  out.set(types, o); o += SECTOR_TABLE_SIZE;
  out.set(targets, o); o += SECTOR_TABLE_SIZE;
  out.set(fcols, o); o += SECTOR_TABLE_SIZE;
  out.set(ccols, o); o += SECTOR_TABLE_SIZE;
  out.set(brights, o); o += SECTOR_TABLE_SIZE;
  out.set(mapBytes, o); o += mapBytes.length;
  out.set(spawnBytes, o); o += SPAWN_BYTES;
  out.set(itemTable, o); o += itemTable.length;
  out[o] = sectorMax & 0xff;
  return { bytes: out, warnings, errors };
}

function clamp(v, lo, hi) {
  v = Number(v) || 0;
  return Math.max(lo, Math.min(hi, v));
}

export function downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}

function pickJsonFile() {
  return new Promise((resolve, reject) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json,application/json';
    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) {
        resolve(null);
        return;
      }
      try {
        const text = await file.text();
        resolve(episodeFromJSON(JSON.parse(text)));
      } catch (err) {
        reject(err);
      }
    };
    // Ignore cancel (no change event in most browsers)
    input.addEventListener('cancel', () => resolve(null));
    input.click();
  });
}

export const DEFAULT_EPISODE_PATH = 'episode1.json';

const HANDLE_DB = 'squaredoom-editor';
const HANDLE_STORE = 'handles';
const HANDLE_KEY = 'episode';

/** @type {FileSystemFileHandle | null} */
let episodeFileHandle = null;

export function episodeFileName() {
  return episodeFileHandle?.name || DEFAULT_EPISODE_PATH;
}

export function hasEpisodeFileHandle() {
  return !!episodeFileHandle;
}

function openHandleDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(HANDLE_DB, 1);
    req.onupgradeneeded = () => {
      const db = req.result;
      if (!db.objectStoreNames.contains(HANDLE_STORE)) {
        db.createObjectStore(HANDLE_STORE);
      }
    };
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

async function storeEpisodeHandle(handle) {
  episodeFileHandle = handle;
  if (!window.indexedDB || !handle) return;
  const db = await openHandleDb();
  await new Promise((resolve, reject) => {
    const tx = db.transaction(HANDLE_STORE, 'readwrite');
    tx.objectStore(HANDLE_STORE).put(handle, HANDLE_KEY);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

async function loadStoredEpisodeHandle() {
  if (!window.indexedDB) return null;
  try {
    const db = await openHandleDb();
    const handle = await new Promise((resolve, reject) => {
      const tx = db.transaction(HANDLE_STORE, 'readonly');
      const req = tx.objectStore(HANDLE_STORE).get(HANDLE_KEY);
      req.onsuccess = () => resolve(req.result || null);
      req.onerror = () => reject(req.error);
    });
    db.close();
    return handle || null;
  } catch (_) {
    return null;
  }
}

async function queryPermission(handle, mode = 'readwrite') {
  if (!handle?.queryPermission) return 'granted';
  return handle.queryPermission({ mode });
}

async function ensurePermission(handle, mode = 'readwrite') {
  if (!handle?.queryPermission || !handle?.requestPermission) return true;
  const opts = { mode };
  if ((await handle.queryPermission(opts)) === 'granted') return true;
  // Shows the browser Allow/Deny prompt (must run from a user gesture).
  return (await handle.requestPermission(opts)) === 'granted';
}

async function writeEpisodeToHandle(handle, episode) {
  const text = JSON.stringify(episodeToJSON(episode), null, 2);
  const writable = await handle.createWritable();
  await writable.write(text);
  await writable.close();
}

async function readEpisodeFromHandle(handle) {
  const file = await handle.getFile();
  return episodeFromJSON(JSON.parse(await file.text()));
}

/** Previously chosen episode file, if any (may still need an Allow click). */
export async function getStoredEpisodeHandle() {
  return loadStoredEpisodeHandle();
}

/** Load without prompting — only when permission is already granted. */
export async function tryRestoreEpisodeFile() {
  const handle = await loadStoredEpisodeHandle();
  if (!handle) return null;
  const writeState = await queryPermission(handle, 'readwrite');
  const readState = writeState === 'granted' ? 'granted' : await queryPermission(handle, 'read');
  if (readState !== 'granted') return null;
  episodeFileHandle = handle;
  return readEpisodeFromHandle(handle);
}

/**
 * Request Allow for a stored handle (call from a click), then load it.
 * @returns {Promise<object|null>}
 */
export async function allowStoredEpisodeFile(handle) {
  if (!handle) return null;
  if (!(await ensurePermission(handle, 'readwrite'))) {
    if (!(await ensurePermission(handle, 'read'))) return null;
  }
  await storeEpisodeHandle(handle);
  return readEpisodeFromHandle(handle);
}

export async function autosaveEpisodeJSON(episode) {
  if (!episodeFileHandle) {
    throw new Error(`Load ${DEFAULT_EPISODE_PATH} once so autosave can write it`);
  }
  if (!(await ensurePermission(episodeFileHandle, 'readwrite'))) {
    throw new Error(`No write permission for ${episodeFileHandle.name}`);
  }
  await writeEpisodeToHandle(episodeFileHandle, episode);
  return 'file';
}

export async function saveEpisodeJSON(episode, suggestedName = DEFAULT_EPISODE_PATH) {
  if (episodeFileHandle && (await ensurePermission(episodeFileHandle, 'readwrite'))) {
    await writeEpisodeToHandle(episodeFileHandle, episode);
    return 'file';
  }

  if (window.showSaveFilePicker) {
    try {
      const handle = await window.showSaveFilePicker({
        suggestedName,
        types: [{ description: 'SquareDoom Map', accept: { 'application/json': ['.json'] } }],
      });
      await storeEpisodeHandle(handle);
      await writeEpisodeToHandle(handle, episode);
      return 'file';
    } catch (e) {
      if (e.name === 'AbortError') return null;
    }
  }

  const text = JSON.stringify(episodeToJSON(episode), null, 2);
  downloadBlob(new Blob([text], { type: 'application/json' }), suggestedName);
  return 'download';
}

export async function loadEpisodeJSON() {
  if (window.showOpenFilePicker) {
    try {
      const [handle] = await window.showOpenFilePicker({
        types: [{ description: 'SquareDoom Map', accept: { 'application/json': ['.json'] } }],
        multiple: false,
      });
      await storeEpisodeHandle(handle);
      return readEpisodeFromHandle(handle);
    } catch (e) {
      if (e.name === 'AbortError') return null;
      // Fall through to <input type="file"> on SecurityError etc.
    }
  }
  return pickJsonFile();
}

export function cookAndDownload(episode, levelName) {
  const level = episode.levels[levelName];
  const { bytes, warnings, errors } = cookLevel(level);
  if (errors?.length) {
    return { warnings, errors };
  }
  const blob = new Blob([bytes], { type: 'application/octet-stream' });
  downloadBlob(blob, `${levelName.toLowerCase()}.bin`);
  return { warnings, errors: [] };
}

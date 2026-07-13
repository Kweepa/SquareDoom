/**
 * Cooked binary layout (no header), per level:
 *   1. Sector table: 255 * 7 bytes (sectors 1..255; unused slots zeroed)
 *      each: floor, ceil, sectorType, targetSector, floorColor, ceilingColor, brightness
 *      targetSector is the resolved sector id (from editor targetTag); 0 if type is 0 / unresolved
 *      editor tag strings are not stored in the binary
 *   2. Map: 1024 bytes sector ids
 *   3. Items: 48 * 4 bytes: typeId, x, y, skillBits
 *      skillBits: bit0=easy, bit1=normal, bit2=hard
 *      unused item slots: typeId=0xFF
 * Colors: 0..15 = Commodore 64 palette
 * typeId: index into ITEM_TYPES (0-based); 0xFF = empty slot
 */

import {
  ITEM_TYPES,
  CAMERA_TYPE,
  DOOR_SECTOR_TYPE,
  isGameItem,
  LEVEL_NAMES,
  MAP_CELLS,
  MAX_ITEMS,
  MAX_SECTORS,
  colorIndex,
  createEmptyLevel,
  createEpisode,
  defaultSector,
  findSectorIdByTag,
  gameItemCount,
  normalizeColor,
} from './model.js';

const SECTOR_BYTES = 7;
const ITEM_BYTES = 4;
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
    sectors: sectorObj,
    map: Array.from(level.map),
    items: level.items.map((it) => {
      const base = {
        type: it.type,
        x: it.x,
        y: it.y,
      };
      if (it.type === CAMERA_TYPE) {
        return { ...base, angle: it.angle ?? 0 };
      }
      return { ...base, skills: { ...it.skills } };
    }),
  };
}

export function levelFromJSON(data) {
  const level = createEmptyLevel();
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
      if (!ITEM_TYPES.includes(it.type)) continue;
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
  const sectorTable = new Uint8Array(MAX_SECTORS * SECTOR_BYTES);
  for (let id = 1; id <= MAX_SECTORS; id++) {
    const s = level.sectors.get(id);
    const off = (id - 1) * SECTOR_BYTES;
    if (!s) continue;
    const type = (s.sectorType ?? 0) & 0xff;
    let targetId = 0;
    if (type !== 0) {
      const tag = (s.targetTag || '').trim();
      if (!tag) {
        warnings.push(`Sector ${id}: type ${type} has empty target tag`);
      } else {
        targetId = findSectorIdByTag(level, tag);
        if (!targetId) {
          warnings.push(`Sector ${id}: target tag "${tag}" not found`);
        }
      }
    }
    sectorTable[off] = s.floorHeight & 31;
    sectorTable[off + 1] = s.ceilingHeight & 31;
    sectorTable[off + 2] = type;
    sectorTable[off + 3] = targetId & 0xff;
    sectorTable[off + 4] = colorIndex(s.floorColor) & 15;
    sectorTable[off + 5] = colorIndex(s.ceilingColor) & 15;
    sectorTable[off + 6] = s.brightness & 7;
  }

  const mapBytes = new Uint8Array(level.map);

  const gameItems = level.items.filter((it) => isGameItem(it.type));
  const itemTable = new Uint8Array(MAX_ITEMS * ITEM_BYTES);
  for (let i = 0; i < MAX_ITEMS; i++) {
    const off = i * ITEM_BYTES;
    const it = gameItems[i];
    if (!it) {
      itemTable[off] = EMPTY_ITEM_TYPE;
      continue;
    }
    const typeId = ITEM_TYPES.indexOf(it.type);
    itemTable[off] = typeId < 0 ? EMPTY_ITEM_TYPE : typeId;
    itemTable[off + 1] = it.x & 0xff;
    itemTable[off + 2] = it.y & 0xff;
    let bits = 0;
    if (it.skills.easy) bits |= 1;
    if (it.skills.normal) bits |= 2;
    if (it.skills.hard) bits |= 4;
    itemTable[off + 3] = bits;
  }

  const out = new Uint8Array(sectorTable.length + mapBytes.length + itemTable.length);
  out.set(sectorTable, 0);
  out.set(mapBytes, sectorTable.length);
  out.set(itemTable, sectorTable.length + mapBytes.length);
  return { bytes: out, warnings };
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

export async function fetchEpisodeJSON(path = DEFAULT_EPISODE_PATH) {
  const res = await fetch(path, { cache: 'no-store' });
  if (!res.ok) throw new Error(`Could not load ${path} (${res.status})`);
  return episodeFromJSON(await res.json());
}

/** Write episode JSON via PUT (used by editor/serve.py). */
export async function putEpisodeJSON(episode, path = DEFAULT_EPISODE_PATH) {
  const text = JSON.stringify(episodeToJSON(episode), null, 2);
  const res = await fetch(path, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: text,
  });
  if (!res.ok) throw new Error(`Autosave failed (${res.status})`);
}

export async function saveEpisodeJSON(episode, suggestedName = DEFAULT_EPISODE_PATH) {
  // Prefer writing into the project file when the local editor server supports PUT
  try {
    await putEpisodeJSON(episode, DEFAULT_EPISODE_PATH);
    return 'server';
  } catch (_) {
    // Fall through
  }

  const text = JSON.stringify(episodeToJSON(episode), null, 2);
  const blob = new Blob([text], { type: 'application/json' });

  if (window.showSaveFilePicker) {
    try {
      const handle = await window.showSaveFilePicker({
        suggestedName,
        types: [{ description: 'SquareDoom Map', accept: { 'application/json': ['.json'] } }],
      });
      const writable = await handle.createWritable();
      await writable.write(blob);
      await writable.close();
      return 'picker';
    } catch (e) {
      if (e.name === 'AbortError') return null;
    }
  }
  downloadBlob(blob, suggestedName);
  return 'download';
}

export async function loadEpisodeJSON() {
  if (window.showOpenFilePicker) {
    try {
      const [handle] = await window.showOpenFilePicker({
        types: [{ description: 'SquareDoom Map', accept: { 'application/json': ['.json'] } }],
        multiple: false,
      });
      const file = await handle.getFile();
      const text = await file.text();
      return episodeFromJSON(JSON.parse(text));
    } catch (e) {
      if (e.name === 'AbortError') return null;
      // Fall through to <input type="file"> on SecurityError etc.
    }
  }
  return pickJsonFile();
}

export function cookAndDownload(episode, levelName) {
  const level = episode.levels[levelName];
  const { bytes, warnings } = cookLevel(level);
  const blob = new Blob([bytes], { type: 'application/octet-stream' });
  downloadBlob(blob, `${levelName.toLowerCase()}.bin`);
  return warnings;
}

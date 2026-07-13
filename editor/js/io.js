/**
 * Cooked binary layout (no header), per level:
 *   1. Sector table: 255 * 7 bytes (sectors 1..255; unused slots zeroed)
 *      each: floor, ceil, ns, ew, floorColor, ceilingColor, brightness
 *   2. Map: 1024 bytes sector ids
 *   3. Items: 48 * 4 bytes: typeId, x, y, skillBits
 *      skillBits: bit0=easy, bit1=normal, bit2=hard
 *      unused item slots: typeId=0xFF
 * Colors: 0..7 = black,red,green,yellow,blue,magenta,cyan,white
 * typeId: index into ITEM_TYPES (0-based); 0xFF = empty slot
 */

import {
  COLORS,
  ITEM_TYPES,
  CAMERA_TYPE,
  isGameItem,
  LEVEL_NAMES,
  MAP_CELLS,
  MAX_ITEMS,
  MAX_SECTORS,
  colorIndex,
  createEmptyLevel,
  createEpisode,
  defaultSector,
  gameItemCount,
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
      nsTexture: s.nsTexture,
      ewTexture: s.ewTexture,
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
      level.sectors.set(id, {
        floorHeight: clamp(s.floorHeight ?? d.floorHeight, 0, 31),
        ceilingHeight: clamp(s.ceilingHeight ?? d.ceilingHeight, 0, 31),
        nsTexture: clamp(s.nsTexture ?? d.nsTexture, 0, 15),
        ewTexture: clamp(s.ewTexture ?? d.ewTexture, 0, 15),
        floorColor: COLORS.includes(s.floorColor) ? s.floorColor : d.floorColor,
        ceilingColor: COLORS.includes(s.ceilingColor) ? s.ceilingColor : d.ceilingColor,
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
  return episode;
}

export function cookLevel(level) {
  const sectorTable = new Uint8Array(MAX_SECTORS * SECTOR_BYTES);
  for (let id = 1; id <= MAX_SECTORS; id++) {
    const s = level.sectors.get(id);
    const off = (id - 1) * SECTOR_BYTES;
    if (!s) continue;
    sectorTable[off] = s.floorHeight & 31;
    sectorTable[off + 1] = s.ceilingHeight & 31;
    sectorTable[off + 2] = s.nsTexture & 15;
    sectorTable[off + 3] = s.ewTexture & 15;
    sectorTable[off + 4] = colorIndex(s.floorColor);
    sectorTable[off + 5] = colorIndex(s.ceilingColor);
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
  return out;
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

export async function saveEpisodeJSON(episode, suggestedName = 'episode1.json') {
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
      return;
    } catch (e) {
      if (e.name === 'AbortError') return;
    }
  }
  downloadBlob(blob, suggestedName);
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
      throw e;
    }
  }

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
    input.click();
  });
}

export function cookAndDownload(episode, levelName) {
  const level = episode.levels[levelName];
  const bytes = cookLevel(level);
  const blob = new Blob([bytes], { type: 'application/octet-stream' });
  downloadBlob(blob, `${levelName.toLowerCase()}.bin`);
}

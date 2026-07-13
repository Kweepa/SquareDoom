import {
  COLOR_HEX,
  MAP_SIZE,
  WORLD_PER_TILE,
  getCell,
  getCameraEyeHeight,
  getSectorAtWorld,
  isCamera,
} from './model.js';

const PREVIEW_W = 88;
const PREVIEW_H = 69;
const FOV = Math.PI / 2.1;
const MAX_DEPTH = 128;
const HORIZON = PREVIEW_H / 2;
const PROJ = 70;
const ITEM_WORLD_HEIGHT = 4;
const TAN_HALF_FOV = Math.tan(FOV / 2);

/** Enemies keep full preview height; everything else is half size. */
const ENEMY_TYPES = new Set(['soldier', 'imp', 'pinky', 'caco', 'baron']);

// side 0 = north/south wall, side 1 = east/west wall
const WALL_NS = [42, 42, 42];
const WALL_EW = [68, 68, 68];

/** Cache of images with pure black (#000) keyed to transparent. */
const transparentCache = new Map();

function transparentSprite(img) {
  if (!img?.complete || !img.naturalWidth) return null;
  let cached = transparentCache.get(img);
  if (cached) return cached;

  const w = img.naturalWidth;
  const h = img.naturalHeight;
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const ctx = c.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  ctx.drawImage(img, 0, 0);
  const data = ctx.getImageData(0, 0, w, h);
  const px = data.data;
  for (let i = 0; i < px.length; i += 4) {
    if (px[i] === 0 && px[i + 1] === 0 && px[i + 2] === 0) px[i + 3] = 0;
  }
  ctx.putImageData(data, 0, 0);
  transparentCache.set(img, c);
  return c;
}
export class PreviewView {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {{
   *   getLevel: () => any,
   *   getCamera: () => {x:number,y:number,angle:number}|null,
   *   onRotate: (angle: number) => void,
   *   images: Record<string, HTMLImageElement>,
   * }} opts
   */
  constructor(canvas, opts) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.opts = opts;
    this.rotating = false;
    this.lastX = 0;
    this.canvas.width = PREVIEW_W;
    this.canvas.height = PREVIEW_H;

    canvas.addEventListener('pointerdown', (e) => this.#onPointer(e));
    canvas.addEventListener('pointermove', (e) => this.#onPointer(e));
    canvas.addEventListener('pointerup', (e) => this.#onPointer(e));
    canvas.addEventListener('pointerleave', (e) => this.#onPointer(e));
  }

  #onPointer(e) {
    const cam = this.opts.getCamera();
    if (!cam) return;

    if (e.type === 'pointerdown') {
      this.rotating = true;
      this.lastX = e.clientX;
      try {
        e.currentTarget.setPointerCapture(e.pointerId);
      } catch (_) { /* ignore */ }
      return;
    }

    if (e.type === 'pointerup' || e.type === 'pointerleave') {
      this.rotating = false;
      return;
    }

    if (e.type === 'pointermove' && this.rotating) {
      const dx = e.clientX - this.lastX;
      this.lastX = e.clientX;
      // Full preview width ≈ ~180° turn; keep it gentle
      const sensitivity = Math.PI / (this.canvas.getBoundingClientRect().width || PREVIEW_W);
      this.opts.onRotate(cam.angle + dx * sensitivity);
      this.draw();
    }
  }

  draw() {
    const ctx = this.ctx;
    const level = this.opts.getLevel();
    const cam = this.opts.getCamera();

    ctx.fillStyle = '#0a0a0c';
    ctx.fillRect(0, 0, PREVIEW_W, PREVIEW_H);

    if (!cam) return;

    const ox = cam.x + 0.5;
    const oy = cam.y + 0.5;
    const eyeZ = getCameraEyeHeight(level, cam.x, cam.y);

    for (let col = 0; col < PREVIEW_W; col++) {
      const rayAngle = cam.angle - FOV / 2 + (FOV * col) / PREVIEW_W;
      castColumn(ctx, level, ox, oy, eyeZ, cam.angle, rayAngle, col);
    }

    this.#drawItems(ctx, level, cam, ox, oy, eyeZ);
  }

  #drawItems(ctx, level, cam, ox, oy, eyeZ) {
    const sin = Math.sin(cam.angle);
    const cos = Math.cos(cam.angle);
    const sprites = [];

    for (const it of level.items) {
      if (isCamera(it)) continue;
      const ix = it.x + 0.5;
      const iy = it.y + 0.5;
      const dx = ix - ox;
      const dy = iy - oy;
      const depth = dx * sin - dy * cos;
      if (depth < 0.8) continue;
      const lateral = dx * cos + dy * sin;
      sprites.push({ it, depth, lateral });
    }

    sprites.sort((a, b) => b.depth - a.depth);

    for (const { it, depth, lateral } of sprites) {
      const sector = getSectorAtWorld(level, it.x, it.y);
      const floorZ = sector?.floorHeight ?? 0;
      const screenX = PREVIEW_W / 2 + (lateral / depth) * (PREVIEW_W / 2) / TAN_HALF_FOV;
      const screenFloorY = HORIZON + ((eyeZ - floorZ) * PROJ) / depth;
      const sizeScale = ENEMY_TYPES.has(it.type) ? 1 : 0.5;
      const spriteH = Math.max(1, (ITEM_WORLD_HEIGHT * PROJ * sizeScale) / depth);
      const img = this.opts.images[it.type];
      const sprite = transparentSprite(img);
      let spriteW = spriteH * 0.75;
      if (sprite) {
        spriteW = spriteH * (sprite.width / sprite.height);
      }
      const left = Math.round(screenX - spriteW / 2);
      const top = Math.round(screenFloorY - spriteH);
      const w = Math.max(1, Math.round(spriteW));
      const h = Math.max(1, Math.round(spriteH));

      if (left + w < 0 || left > PREVIEW_W || top + h < 0 || top > PREVIEW_H) continue;

      if (sprite) {
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(sprite, left, top, w, h);
      } else {
        ctx.fillStyle = '#c84';
        ctx.fillRect(left, top, w, h);
      }
    }
  }
}

function sectorAtTile(level, tx, ty) {
  const id = getCell(level, tx, ty);
  if (!id || !level.sectors.has(id)) return null;
  return { id, sector: level.sectors.get(id) };
}

/**
 * Multi-sector column cast: at each portal, paint near-sector floor/ceiling
 * into the open clip, draw upper/lower walls if heights change, then narrow
 * the clip. Farther sectors only paint into what's still open.
 */
function castColumn(ctx, level, ox, oy, eyeZ, camAngle, rayAngle, col) {
  const rayDirX = Math.sin(rayAngle);
  const rayDirY = -Math.cos(rayAngle);
  const fish = Math.cos(camAngle - rayAngle);

  let mapX = Math.floor(ox / WORLD_PER_TILE);
  let mapY = Math.floor(oy / WORLD_PER_TILE);

  const deltaDistX = Math.abs(rayDirX) < 1e-8 ? 1e30 : Math.abs(1 / rayDirX);
  const deltaDistY = Math.abs(rayDirY) < 1e-8 ? 1e30 : Math.abs(1 / rayDirY);

  let stepX;
  let stepY;
  let sideDistX;
  let sideDistY;

  if (rayDirX < 0) {
    stepX = -1;
    sideDistX = (ox / WORLD_PER_TILE - mapX) * deltaDistX;
  } else {
    stepX = 1;
    sideDistX = (mapX + 1 - ox / WORLD_PER_TILE) * deltaDistX;
  }
  if (rayDirY < 0) {
    stepY = -1;
    sideDistY = (oy / WORLD_PER_TILE - mapY) * deltaDistY;
  } else {
    stepY = 1;
    sideDistY = (mapY + 1 - oy / WORLD_PER_TILE) * deltaDistY;
  }

  let yTop = 0;
  let yBot = PREVIEW_H;
  let cur = sectorAtTile(level, mapX, mapY);
  let side = 0;

  for (let step = 0; step < MAX_DEPTH && yTop < yBot; step++) {
    let dist;
    if (sideDistX < sideDistY) {
      dist = sideDistX;
      sideDistX += deltaDistX;
      mapX += stepX;
      side = 0;
    } else {
      dist = sideDistY;
      sideDistY += deltaDistY;
      mapY += stepY;
      side = 1;
    }

    const perpTiles = Math.max(0.05, dist * fish);
    const perpDist = perpTiles * WORLD_PER_TILE;
    const outOfBounds = mapX < 0 || mapY < 0 || mapX >= MAP_SIZE || mapY >= MAP_SIZE;
    const next = outOfBounds ? null : sectorAtTile(level, mapX, mapY);

    // Same sector — keep walking
    if (cur && next && cur.id === next.id) continue;

    // Entering geometry from void
    if (!cur && next) {
      cur = next;
      continue;
    }

    const nearFloor = cur?.sector.floorHeight ?? 0;
    const nearCeil = cur?.sector.ceilingHeight ?? 31;
    const nearCeilY = projectY(nearCeil, eyeZ, perpDist);
    const nearFloorY = projectY(nearFloor, eyeZ, perpDist);

    // Near-sector ceiling strip above the portal (front-to-back; only open clip)
    if (cur) {
      const ceilEnd = clampSpan(yTop, yBot, nearCeilY);
      if (ceilEnd > yTop) {
        ctx.fillStyle = COLOR_HEX[cur.sector.ceilingColor] || '#222';
        ctx.fillRect(col, yTop, 1, ceilEnd - yTop);
        yTop = ceilEnd;
      }
    }

    // Near-sector floor strip below the portal
    if (cur) {
      const floorStart = clampSpan(yTop, yBot, nearFloorY);
      if (floorStart < yBot) {
        ctx.fillStyle = COLOR_HEX[cur.sector.floorColor] || '#111';
        ctx.fillRect(col, floorStart, 1, yBot - floorStart);
        yBot = floorStart;
      }
    }

    if (yTop >= yBot) break;

    // Solid wall — fill remaining portal and stop (nothing farther may draw)
    if (!next) {
      if (yBot > yTop) {
        ctx.fillStyle = wallColor(side, perpDist);
        ctx.fillRect(col, yTop, 1, yBot - yTop);
      }
      break;
    }

    const farFloor = next.sector.floorHeight;
    const farCeil = next.sector.ceilingHeight;
    const farCeilY = projectY(farCeil, eyeZ, perpDist);
    const farFloorY = projectY(farFloor, eyeZ, perpDist);

    // Upper wall
    if (farCeil < nearCeil) {
      const wallTop = clampSpan(yTop, yBot, nearCeilY);
      const wallBot = clampSpan(yTop, yBot, farCeilY);
      if (wallBot > wallTop) {
        ctx.fillStyle = wallColor(side, perpDist);
        ctx.fillRect(col, wallTop, 1, wallBot - wallTop);
      }
      yTop = Math.max(yTop, wallBot);
    }

    if (yTop >= yBot) break;

    // Lower wall
    if (farFloor > nearFloor) {
      const wallTop = clampSpan(yTop, yBot, farFloorY);
      const wallBot = clampSpan(yTop, yBot, nearFloorY);
      if (wallBot > wallTop) {
        ctx.fillStyle = wallColor(side, perpDist);
        ctx.fillRect(col, wallTop, 1, wallBot - wallTop);
      }
      yBot = Math.min(yBot, wallTop);
    }

    if (yTop >= yBot) break;

    cur = next;
  }
}

function clampSpan(yTop, yBot, y) {
  return Math.max(yTop, Math.min(yBot, y));
}

function projectY(height, eyeZ, perpDist) {
  return HORIZON - ((height - eyeZ) * PROJ) / Math.max(0.5, perpDist);
}

function wallColor(side, dist) {
  const shade = Math.max(0.45, 1 - dist / 110);
  const base = side === 0 ? WALL_NS : WALL_EW;
  const r = Math.floor(base[0] * shade);
  const g = Math.floor(base[1] * shade);
  const b = Math.floor(base[2] * shade);
  return `rgb(${r},${g},${b})`;
}

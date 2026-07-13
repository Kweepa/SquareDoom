import {
  C64_HEX,
  MAP_SIZE,
  WORLD_PER_TILE,
  getCell,
  getCameraEyeHeight,
  getSectorAtWorld,
  isCamera,
  isDoorSector,
  colorHex,
} from './model.js';

const DEFAULT_RAYS = 40;
const DEFAULT_COL_H = 25;
const FOV = Math.PI / 2.1;
const MAX_DEPTH = 128;
/** Projection scale so default height ≈ previous 70px feel. */
const PROJ_SCALE = 70 / 69;
const ITEM_WORLD_HEIGHT = 4;
const TAN_HALF_FOV = Math.tan(FOV / 2);

/** Enemies keep full preview height; everything else is half size. */
const ENEMY_TYPES = new Set(['soldier', 'imp', 'pinky', 'caco', 'baron']);

// side 0 = north/south wall (orange), side 1 = east/west wall (brown)
const WALL_NS = 8;
const WALL_EW = 9;

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
   * @param {HTMLCanvasElement} canvas Display canvas (scaled up from the render buffer).
   * @param {{
   *   getLevel: () => any,
   *   getCamera: () => {x:number,y:number,angle:number}|null,
   *   onRotate: (angle: number) => void,
   *   onMove: (x: number, y: number) => void,
   *   images: Record<string, HTMLImageElement>,
   *   getRaycasts?: () => number,
   *   getColumnHeight?: () => number,
   * }} opts
   */
  constructor(canvas, opts) {
    this.display = canvas;
    this.frame = canvas.parentElement;
    this.dctx = canvas.getContext('2d', { alpha: false });
    this.buffer = document.createElement('canvas');
    this.ctx = this.buffer.getContext('2d', { alpha: false });
    this.opts = opts;
    this.dragging = false;
    this.lastX = 0;
    this.lastY = 0;
    this.buffer.width = DEFAULT_RAYS;
    this.buffer.height = DEFAULT_COL_H;
    this.ctx.imageSmoothingEnabled = false;
    disableSmoothing(this.dctx);

    canvas.addEventListener('pointerdown', (e) => this.#onPointer(e));
    canvas.addEventListener('pointermove', (e) => this.#onPointer(e));
    canvas.addEventListener('pointerup', (e) => this.#onPointer(e));
    canvas.addEventListener('lostpointercapture', (e) => this.#onPointer(e));

    this._ro = new ResizeObserver(() => this.draw());
    if (this.frame) this._ro.observe(this.frame);
  }

  #onPointer(e) {
    const cam = this.opts.getCamera();
    if (!cam) return;

    if (e.type === 'pointerdown') {
      this.dragging = true;
      this.lastX = e.clientX;
      this.lastY = e.clientY;
      try {
        e.currentTarget.setPointerCapture(e.pointerId);
      } catch (_) { /* ignore */ }
      return;
    }

    if (e.type === 'pointerup' || e.type === 'lostpointercapture') {
      this.dragging = false;
      return;
    }

    if (e.type === 'pointermove' && this.dragging) {
      const dx = e.clientX - this.lastX;
      const dy = e.clientY - this.lastY;
      this.lastX = e.clientX;
      this.lastY = e.clientY;
      const rect = this.display.getBoundingClientRect();
      const w = rect.width || DEFAULT_RAYS;
      const h = rect.height || DEFAULT_COL_H;

      if (dx) {
        const turnSens = Math.PI / w;
        this.opts.onRotate(cam.angle + dx * turnSens);
      }
      if (dy) {
        // Drag up = forward. Facing matches ray dir: (sin θ, −cos θ).
        const walkSens = (WORLD_PER_TILE * 2) / h;
        const forward = -dy * walkSens;
        const nx = cam.x + Math.sin(cam.angle) * forward;
        const ny = cam.y - Math.cos(cam.angle) * forward;
        this.opts.onMove(nx, ny);
      }
      this.draw();
    }
  }

  draw() {
    const ctx = this.ctx;
    const level = this.opts.getLevel();
    const cam = this.opts.getCamera();
    const view = viewParams(
      this.opts.getRaycasts?.() ?? DEFAULT_RAYS,
      this.opts.getColumnHeight?.() ?? DEFAULT_COL_H,
    );

    if (this.buffer.width !== view.w || this.buffer.height !== view.h) {
      this.buffer.width = view.w;
      this.buffer.height = view.h;
    }
    disableSmoothing(ctx);

    ctx.fillStyle = '#0a0a0c';
    ctx.fillRect(0, 0, view.w, view.h);

    if (cam) {
      const ox = cam.x + 0.5;
      const oy = cam.y + 0.5;
      const eyeZ = getCameraEyeHeight(level, cam.x, cam.y);
      // Camera-plane rays (perspective): equal screen-X spacing, not equal angle.
      // dir = facing, plane = right * tan(FOV/2) — avoids fish-eye floor curves.
      const dirX = Math.sin(cam.angle);
      const dirY = -Math.cos(cam.angle);
      const planeX = Math.cos(cam.angle) * TAN_HALF_FOV;
      const planeY = Math.sin(cam.angle) * TAN_HALF_FOV;

      for (let col = 0; col < view.w; col++) {
        const cameraX = (2 * col + 1) / view.w - 1;
        const rayDirX = dirX + planeX * cameraX;
        const rayDirY = dirY + planeY * cameraX;
        castColumn(ctx, level, ox, oy, eyeZ, rayDirX, rayDirY, col, view);
      }

      this.#drawItems(ctx, level, cam, ox, oy, eyeZ, view);
    }

    this.#present(view);
  }

  /** Nearest-neighbor blit buffer → display at frame size (no CSS stretch filtering). */
  #present(view) {
    const frame = this.frame || this.display;
    const rect = frame.getBoundingClientRect();
    const dpr = window.devicePixelRatio || 1;
    const outW = Math.max(1, Math.round(rect.width * dpr));
    const outH = Math.max(1, Math.round(rect.height * dpr));
    if (this.display.width !== outW || this.display.height !== outH) {
      this.display.width = outW;
      this.display.height = outH;
    }
    const dctx = this.dctx;
    disableSmoothing(dctx);
    dctx.fillStyle = '#0a0a0c';
    dctx.fillRect(0, 0, outW, outH);
    dctx.drawImage(this.buffer, 0, 0, view.w, view.h, 0, 0, outW, outH);
  }

  #drawItems(ctx, level, cam, ox, oy, eyeZ, view) {
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
      const screenX = view.w / 2 + (lateral / depth) * (view.w / 2) / TAN_HALF_FOV;
      const screenFloorY = view.horizon + ((eyeZ - floorZ) * view.proj) / depth;
      const sizeScale = ENEMY_TYPES.has(it.type) ? 1 : 0.5;
      const spriteH = Math.max(1, (ITEM_WORLD_HEIGHT * view.proj * sizeScale) / depth);
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

      if (left + w < 0 || left > view.w || top + h < 0 || top > view.h) continue;

      if (sprite) {
        disableSmoothing(ctx);
        ctx.drawImage(sprite, left, top, w, h);
      } else {
        ctx.fillStyle = '#c84';
        ctx.fillRect(left, top, w, h);
      }
    }
  }
}

function viewParams(raycasts, columnHeight) {
  const w = Math.max(8, Math.min(320, Math.round(Number(raycasts) || DEFAULT_RAYS)));
  const h = Math.max(8, Math.min(240, Math.round(Number(columnHeight) || DEFAULT_COL_H)));
  return {
    w,
    h,
    horizon: h / 2,
    proj: h * PROJ_SCALE,
  };
}

function disableSmoothing(ctx) {
  ctx.imageSmoothingEnabled = false;
  ctx.mozImageSmoothingEnabled = false;
  ctx.webkitImageSmoothingEnabled = false;
  ctx.msImageSmoothingEnabled = false;
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
function castColumn(ctx, level, ox, oy, eyeZ, rayDirX, rayDirY, col, view) {
  const posX = ox / WORLD_PER_TILE;
  const posY = oy / WORLD_PER_TILE;

  let mapX = Math.floor(posX);
  let mapY = Math.floor(posY);

  const deltaDistX = Math.abs(rayDirX) < 1e-8 ? 1e30 : Math.abs(1 / rayDirX);
  const deltaDistY = Math.abs(rayDirY) < 1e-8 ? 1e30 : Math.abs(1 / rayDirY);

  let stepX;
  let stepY;
  let sideDistX;
  let sideDistY;

  if (rayDirX < 0) {
    stepX = -1;
    sideDistX = (posX - mapX) * deltaDistX;
  } else {
    stepX = 1;
    sideDistX = (mapX + 1 - posX) * deltaDistX;
  }
  if (rayDirY < 0) {
    stepY = -1;
    sideDistY = (posY - mapY) * deltaDistY;
  } else {
    stepY = 1;
    sideDistY = (mapY + 1 - posY) * deltaDistY;
  }

  let yTop = 0;
  let yBot = view.h;
  let cur = sectorAtTile(level, mapX, mapY);
  let side = 0;

  for (let step = 0; step < MAX_DEPTH && yTop < yBot; step++) {
    if (sideDistX < sideDistY) {
      sideDistX += deltaDistX;
      mapX += stepX;
      side = 0;
    } else {
      sideDistY += deltaDistY;
      mapY += stepY;
      side = 1;
    }

    // Perpendicular distance in tiles (Lodev) — already fish-eye free
    let perpTiles;
    if (side === 0) {
      perpTiles = (mapX - posX + (1 - stepX) / 2) / rayDirX;
    } else {
      perpTiles = (mapY - posY + (1 - stepY) / 2) / rayDirY;
    }
    const perpDist = Math.max(0.05, Math.abs(perpTiles)) * WORLD_PER_TILE;
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
    const nearCeilY = projectY(nearCeil, eyeZ, perpDist, view);
    const nearFloorY = projectY(nearFloor, eyeZ, perpDist, view);

    // Near-sector ceiling strip above the portal (front-to-back; only open clip)
    if (cur) {
      const ceilEnd = clampSpan(yTop, yBot, nearCeilY);
      if (ceilEnd > yTop) {
        ctx.fillStyle = colorHex(cur.sector.ceilingColor);
        ctx.fillRect(col, yTop, 1, ceilEnd - yTop);
        yTop = ceilEnd;
      }
    }

    // Near-sector floor strip below the portal
    if (cur) {
      const floorStart = clampSpan(yTop, yBot, nearFloorY);
      if (floorStart < yBot) {
        ctx.fillStyle = colorHex(cur.sector.floorColor);
        ctx.fillRect(col, floorStart, 1, yBot - floorStart);
        yBot = floorStart;
      }
    }

    if (yTop >= yBot) break;

    // Solid wall — fill remaining portal and stop (nothing farther may draw)
    if (!next) {
      if (yBot > yTop) {
        ctx.fillStyle = wallColor(side);
        ctx.fillRect(col, yTop, 1, yBot - yTop);
      }
      break;
    }

    // Into a door: door ceiling colour. Out of a door / normal: N/S–E/W walls.
    const portalFill = isDoorSector(next.sector)
      ? colorHex(next.sector.ceilingColor)
      : wallColor(side);
    const farFloor = next.sector.floorHeight;
    const farCeil = next.sector.ceilingHeight;
    const farCeilY = projectY(farCeil, eyeZ, perpDist, view);
    const farFloorY = projectY(farFloor, eyeZ, perpDist, view);

    // Upper wall
    if (farCeil < nearCeil) {
      const wallTop = clampSpan(yTop, yBot, nearCeilY);
      const wallBot = clampSpan(yTop, yBot, farCeilY);
      if (wallBot > wallTop) {
        ctx.fillStyle = portalFill;
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
        ctx.fillStyle = portalFill;
        ctx.fillRect(col, wallTop, 1, wallBot - wallTop);
      }
      yBot = Math.min(yBot, wallTop);
    }

    if (yTop >= yBot) break;

    cur = next;
  }
}

function clampSpan(yTop, yBot, y) {
  return Math.max(yTop, Math.min(yBot, Math.round(y)));
}

function projectY(height, eyeZ, perpDist, view) {
  return Math.round(view.horizon - ((height - eyeZ) * view.proj) / Math.max(0.5, perpDist));
}

function wallColor(side) {
  return C64_HEX[side === 0 ? WALL_NS : WALL_EW];
}

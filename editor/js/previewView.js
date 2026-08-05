import {
  C64_HEX,
  ENEMY_TYPES,
  MAP_SIZE,
  WORLD_PER_TILE,
  getCell,
  getCameraEyeHeight,
  getSectorAtWorld,
  isCamera,
  isDoorSector,
  isElevatorSector,
  isSwitch,
  buildSwitchFaceBindings,
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
const CELL_MAX = 8;
/** Soft cap on dither framebuffer pixels (default 40×25×8² = 64k). */
const DITHER_PIX_BUDGET = 320 * 200;

// side 0 = north/south wall (orange), side 1 = east/west wall (brown)
const WALL_NS = 8;
const WALL_EW = 9;
const SKY_COLOR = 3;

/**
 * Wall dither UDGs $00–$0F from ditherchars.asm / lightingdither.png.
 * Index 0 = brightest/closest; 15 = empty (black).
 */
const WALL_GLYPHS = [
  [0xff, 0xef, 0xfe, 0xff, 0xff, 0xbf, 0xfb, 0xff],
  [0xef, 0xee, 0xfe, 0xff, 0xbf, 0xbb, 0xfb, 0xff],
  [0xef, 0xee, 0xee, 0xfe, 0xbf, 0xbb, 0xbb, 0xfb],
  [0xef, 0xee, 0xee, 0xae, 0xba, 0xbb, 0xbb, 0xfb],
  [0xeb, 0xee, 0xee, 0xae, 0xaa, 0xba, 0xbb, 0xbb],
  [0xaa, 0xea, 0xee, 0xae, 0xaa, 0xba, 0xbb, 0xab],
  [0xaa, 0xea, 0xae, 0xaa, 0xaa, 0xba, 0xab, 0xaa],
  [0xa2, 0xea, 0xae, 0xaa, 0x28, 0xba, 0xab, 0x8a],
  [0xaa, 0xaa, 0xa2, 0xaa, 0x2a, 0xa8, 0x8a, 0xaa],
  [0xa8, 0x88, 0x8a, 0xaa, 0xa2, 0x22, 0x2a, 0xaa],
  [0xa8, 0x88, 0x88, 0x8a, 0xa2, 0x22, 0x22, 0x2a],
  [0x28, 0x88, 0x88, 0x88, 0x82, 0x22, 0x22, 0x22],
  [0x08, 0x88, 0x88, 0x80, 0x02, 0x22, 0x22, 0x20],
  [0x00, 0x08, 0x88, 0x80, 0x00, 0x02, 0x22, 0x20],
  [0x00, 0x08, 0x80, 0x00, 0x00, 0x02, 0x20, 0x00],
  [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
];

/** Floor glyphs = walls rotated 90° CW (ditherchars.asm). */
const FLOOR_GLYPHS = [
  [0xff, 0xdf, 0xff, 0xfd, 0xff, 0xbf, 0xff, 0xfb],
  [0xff, 0xcf, 0xff, 0xfc, 0xff, 0x9f, 0xff, 0xf9],
  [0xff, 0x8f, 0xff, 0xf8, 0xff, 0x1f, 0xff, 0xf1],
  [0xff, 0x87, 0xff, 0xf0, 0xff, 0x0f, 0xff, 0xe1],
  [0xff, 0x07, 0xff, 0xe0, 0xff, 0x0e, 0xff, 0xc1],
  [0xff, 0x06, 0xff, 0x60, 0xff, 0x0c, 0xff, 0xc0],
  [0xff, 0x02, 0xff, 0x20, 0xff, 0x04, 0xff, 0x40],
  [0xef, 0x02, 0x7f, 0x20, 0xfe, 0x04, 0xef, 0x40],
  [0xef, 0x00, 0xbf, 0x00, 0xfb, 0x00, 0xdf, 0x00],
  [0x9f, 0x00, 0xf9, 0x00, 0xcf, 0x00, 0xfc, 0x00],
  [0x1f, 0x00, 0xf1, 0x00, 0x8f, 0x00, 0xf8, 0x00],
  [0x1e, 0x00, 0xe1, 0x00, 0x0f, 0x00, 0xf0, 0x00],
  [0x0e, 0x00, 0xe0, 0x00, 0x07, 0x00, 0x70, 0x00],
  [0x0c, 0x00, 0xc0, 0x00, 0x06, 0x00, 0x60, 0x00],
  [0x04, 0x00, 0x40, 0x00, 0x02, 0x00, 0x20, 0x00],
  [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
];

const WALL_LIT = WALL_GLYPHS.map(glyphLitFraction);
const FLOOR_LIT = FLOOR_GLYPHS.map(glyphLitFraction);

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
   *   onEditEnd?: () => void,
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
    this.buffer.width = DEFAULT_RAYS * CELL_MAX;
    this.buffer.height = DEFAULT_COL_H * CELL_MAX;
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
      if (this.dragging) this.opts.onEditEnd?.();
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
    const cell = cellSizeForView(view);
    view.cell = cell;
    const bw = view.w * cell;
    const bh = view.h * cell;

    if (this.buffer.width !== bw || this.buffer.height !== bh) {
      this.buffer.width = bw;
      this.buffer.height = bh;
    }
    disableSmoothing(ctx);

    const img = ctx.createImageData(bw, bh);
    const pix = img.data;
    // Black matches VIC background behind unset dither bits.
    pix.fill(0);
    for (let i = 3; i < pix.length; i += 4) pix[i] = 255;

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

      const switchFaces = buildSwitchFaceBindings(level);
      const switchImg = this.opts.images?.switch ?? null;
      const fb = { pix, stride: bw, cell };

      for (let col = 0; col < view.w; col++) {
        const cameraX = (2 * col + 1) / view.w - 1;
        const rayDirX = dirX + planeX * cameraX;
        const rayDirY = dirY + planeY * cameraX;
        castColumn(fb, level, ox, oy, eyeZ, rayDirX, rayDirY, col, view, switchFaces, switchImg);
      }

      ctx.putImageData(img, 0, 0);
      this.#drawItems(ctx, level, cam, ox, oy, eyeZ, view);
    } else {
      ctx.putImageData(img, 0, 0);
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
    dctx.fillStyle = '#000';
    dctx.fillRect(0, 0, outW, outH);
    dctx.drawImage(
      this.buffer,
      0,
      0,
      view.w * view.cell,
      view.h * view.cell,
      0,
      0,
      outW,
      outH,
    );
  }

  #drawItems(ctx, level, cam, ox, oy, eyeZ, view) {
    const sin = Math.sin(cam.angle);
    const cos = Math.cos(cam.angle);
    const sprites = [];
    const cell = view.cell;

    for (const it of level.items) {
      if (isCamera(it) || isSwitch(it)) continue; // wall-face in castColumn
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
      const left = Math.round(screenX - spriteW / 2) * cell;
      const top = Math.round(screenFloorY - spriteH) * cell;
      const w = Math.max(cell, Math.round(spriteW) * cell);
      const h = Math.max(cell, Math.round(spriteH) * cell);

      if (left + w < 0 || left > view.w * cell || top + h < 0 || top > view.h * cell) continue;

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
    cell: CELL_MAX,
  };
}

function cellSizeForView(view) {
  const cells = view.w * view.h;
  for (let cell = CELL_MAX; cell >= 1; cell >>= 1) {
    if (cells * cell * cell <= DITHER_PIX_BUDGET * 2) return cell;
  }
  return 1;
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

function glyphLitFraction(glyph) {
  let n = 0;
  for (const byte of glyph) {
    for (let i = 0; i < 8; i++) n += (byte >> i) & 1;
  }
  return n / 64;
}

/** Match util.asm bright_to_wdark: 0..15 → 15..0; 16 → full-bright sentinel. */
function brightToWdark(brightness) {
  const b = brightness | 0;
  if (b >= 16) return -1;
  return 15 - Math.max(0, Math.min(15, b));
}

/**
 * Wall pattern index — SEC_WDARK[cur] + min(15, wallz_h), clamped.
 * wallz_h ≈ perpendicular tile depth (fish-scaled mid-product hi).
 */
function wallPatIndex(brightness, perpTiles) {
  const wdark = brightToWdark(brightness);
  if (wdark < 0) return 0;
  const z = Math.min(15, Math.max(0, Math.floor(Math.abs(perpTiles))));
  return Math.min(15, wdark + z);
}

/** Floor/ceil pattern — brightness only (no distance), util.asm bright_to_fpat. */
function floorPatIndex(brightness) {
  const wdark = brightToWdark(brightness);
  return wdark < 0 ? 0 : wdark;
}

function parseHex(hex) {
  const h = hex[0] === '#' ? hex.slice(1) : hex;
  if (h.length === 3) {
    return [
      parseInt(h[0] + h[0], 16),
      parseInt(h[1] + h[1], 16),
      parseInt(h[2] + h[2], 16),
    ];
  }
  return [
    parseInt(h.slice(0, 2), 16),
    parseInt(h.slice(2, 4), 16),
    parseInt(h.slice(4, 6), 16),
  ];
}

function fillDitherSpan(fb, col, y0, y1, hex, glyph, litFrac) {
  if (y1 <= y0) return;
  const { pix, stride, cell } = fb;
  const rgb = parseHex(hex);
  if (cell <= 1) {
    const r = Math.round(rgb[0] * litFrac);
    const g = Math.round(rgb[1] * litFrac);
    const b = Math.round(rgb[2] * litFrac);
    for (let y = y0; y < y1; y++) {
      const i = (y * stride + col) * 4;
      pix[i] = r;
      pix[i + 1] = g;
      pix[i + 2] = b;
      pix[i + 3] = 255;
    }
    return;
  }

  const step = CELL_MAX / cell;
  const x0 = col * cell;
  for (let y = y0; y < y1; y++) {
    const y0p = y * cell;
    for (let py = 0; py < cell; py++) {
      const bits = glyph[(py * step) | 0];
      const row = (y0p + py) * stride + x0;
      for (let px = 0; px < cell; px++) {
        const lit = (bits >> (7 - ((px * step) | 0))) & 1;
        const i = (row + px) * 4;
        if (lit) {
          pix[i] = rgb[0];
          pix[i + 1] = rgb[1];
          pix[i + 2] = rgb[2];
        } else {
          pix[i] = 0;
          pix[i + 1] = 0;
          pix[i + 2] = 0;
        }
        pix[i + 3] = 255;
      }
    }
  }
}

function fillSolidSpan(fb, col, y0, y1, hexOrRgb) {
  if (y1 <= y0) return;
  const { pix, stride, cell } = fb;
  const rgb = Array.isArray(hexOrRgb) ? hexOrRgb : parseHex(hexOrRgb);
  if (cell <= 1) {
    for (let y = y0; y < y1; y++) {
      const i = (y * stride + col) * 4;
      pix[i] = rgb[0];
      pix[i + 1] = rgb[1];
      pix[i + 2] = rgb[2];
      pix[i + 3] = 255;
    }
    return;
  }
  const x0 = col * cell;
  for (let y = y0; y < y1; y++) {
    const y0p = y * cell;
    for (let py = 0; py < cell; py++) {
      const row = (y0p + py) * stride + x0;
      for (let px = 0; px < cell; px++) {
        const i = (row + px) * 4;
        pix[i] = rgb[0];
        pix[i + 1] = rgb[1];
        pix[i + 2] = rgb[2];
        pix[i + 3] = 255;
      }
    }
  }
}

function fillWallSpan(fb, col, y0, y1, hex, pat) {
  const p = pat & 15;
  fillDitherSpan(fb, col, y0, y1, hex, WALL_GLYPHS[p], WALL_LIT[p]);
}

function fillFloorSpan(fb, col, y0, y1, hex, pat) {
  const p = pat & 15;
  fillDitherSpan(fb, col, y0, y1, hex, FLOOR_GLYPHS[p], FLOOR_LIT[p]);
}

/**
 * Multi-sector column cast: at each portal, paint near-sector floor/ceiling
 * into the open clip, draw upper/lower walls if heights change, then narrow
 * the clip. Farther sectors only paint into what's still open.
 */
function castColumn(fb, level, ox, oy, eyeZ, rayDirX, rayDirY, col, view, switchFaces, switchImg) {
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
    const wallU = faceU(posX, posY, perpTiles, rayDirX, rayDirY, side, mapX, mapY, stepX, stepY);
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
    const nearBright = cur?.sector.brightness ?? 15;
    const fpat = floorPatIndex(nearBright);
    // Wall dither from near sector + tile depth (≈ wallz_h).
    const wpat = wallPatIndex(nearBright, perpTiles);

    // Near-sector ceiling strip above the portal (front-to-back; only open clip).
    // When nearCeilY clamps to yBot, still fill and close — leaves no false
    // opening for a solid wall (C64 paint_near must match).
    if (cur) {
      const ceilEnd = clampSpan(yTop, yBot, nearCeilY);
      if (ceilEnd > yTop) {
        const ccol = cur.sector.ceilingColor & 15;
        if (ccol === SKY_COLOR) {
          // Sky: brightest floor UDG (game sky_put); solid cyan stand-in for sky strip.
          fillFloorSpan(fb, col, yTop, ceilEnd, colorHex(SKY_COLOR), 0);
        } else {
          fillFloorSpan(fb, col, yTop, ceilEnd, colorHex(ccol), fpat);
        }
        yTop = ceilEnd;
      }
    }

    // Near-sector floor strip below the portal (only when floor is at/below
    // the horizon — floors above the eye must not yank yBot into the sky).
    if (cur && nearFloorY >= view.horizon) {
      const floorStart = clampSpan(yTop, yBot, nearFloorY);
      if (floorStart < yBot) {
        fillFloorSpan(fb, col, floorStart, yBot, colorHex(cur.sector.floorColor), fpat);
        yBot = floorStart;
      }
    }

    if (yTop >= yBot) break;

    // Solid wall — fill remaining portal and stop (nothing farther may draw)
    if (!next) {
      if (yBot > yTop) {
        const grey = wallColor(side);
        const hitFace = hitFaceNESW(side, stepX, stepY);
        const isSw = isCookedSwitchFace(level, switchFaces, mapX, mapY, hitFace);
        if (isSw && switchImg) {
          paintSwitchColumn(fb, col, yTop, yBot, wallU, switchImg, grey, wpat, nearCeilY, nearFloorY);
        } else {
          fillWallSpan(fb, col, yTop, yBot, grey, wpat);
        }
      }
      break;
    }

    // Upper ledge: door → ceil colour on outer 1/8ths only. Else N/S–E/W grey.
    // Lower ledge: elevator → floor colour. Else grey.
    const grey = wallColor(side);
    const farFloor = next.sector.floorHeight;
    const farCeil = next.sector.ceilingHeight;
    const farCeilY = projectY(farCeil, eyeZ, perpDist, view);
    const farFloorY = projectY(farFloor, eyeZ, perpDist, view);

    // Upper wall
    if (farCeil < nearCeil) {
      const wallTop = clampSpan(yTop, yBot, nearCeilY);
      const wallBot = clampSpan(yTop, yBot, farCeilY);
      if (wallBot > wallTop) {
        // Door: left/right = ceil colour, centre = floor colour (secret doors)
        if (isDoorSector(next.sector)) {
          const jamb = wallU < 1 / 8 || wallU >= 7 / 8;
          const colIdx = jamb ? next.sector.ceilingColor : next.sector.floorColor;
          if ((colIdx & 15) === SKY_COLOR) {
            fillFloorSpan(fb, col, wallTop, wallBot, colorHex(SKY_COLOR), 0);
          } else {
            fillWallSpan(fb, col, wallTop, wallBot, colorHex(colIdx), wpat);
          }
        } else {
          fillWallSpan(fb, col, wallTop, wallBot, grey, wpat);
        }
      }
      yTop = Math.max(yTop, wallBot);
    }

    if (yTop >= yBot) break;

    // Lower wall
    if (farFloor > nearFloor) {
      const wallTop = clampSpan(yTop, yBot, farFloorY);
      const wallBot = clampSpan(yTop, yBot, nearFloorY);
      if (wallBot > wallTop) {
        const hex = isElevatorSector(next.sector)
          ? colorHex(next.sector.floorColor)
          : grey;
        fillWallSpan(fb, col, wallTop, wallBot, hex, wpat);
      }
      // Portal opening is [yTop, farFloorY) even when the raised floor
      // projects above the horizon (looking up stairs).
      yBot = Math.min(yBot, wallTop);
    }

    if (yTop >= yBot) break;

    cur = next;
  }
}

/**
 * Face U in 0..1 = fractional coord of the grid crossing on the non-hit axis.
 * side 0 (vertical gridline): frac(hitY); side 1: frac(hitX).
 */
function faceU(posX, posY, perpTiles, rayDirX, rayDirY, side, mapX, mapY, stepX, stepY) {
  let u;
  if (side === 0) {
    const gridX = stepX > 0 ? mapX : mapX + 1;
    const t = (gridX - posX) / rayDirX;
    u = posY + t * rayDirY;
  } else {
    const gridY = stepY > 0 ? mapY : mapY + 1;
    const t = (gridY - posY) / rayDirY;
    u = posX + t * rayDirX;
  }
  u -= Math.floor(u);
  if (side === 0 && rayDirX > 0) u = 1 - u;
  if (side === 1 && rayDirY < 0) u = 1 - u;
  if (u < 0) u = 0;
  if (u >= 1) u = 0.999;
  return u;
}

/** NESW face of solid cell that was hit: 0=N 1=E 2=S 3=W. */
function hitFaceNESW(side, stepX, stepY) {
  if (side === 0) return stepX < 0 ? 1 : 3; // E if stepping −X, else W
  return stepY < 0 ? 2 : 0; // S if stepping −Y, else N
}

/** Match cooked {sec,dir} against solid cell + hit face (asm switch_face_match). */
function isCookedSwitchFace(level, faces, mapX, mapY, hitFace) {
  const nd = [
    { dx: 0, dy: -1 },
    { dx: 1, dy: 0 },
    { dx: 0, dy: 1 },
    { dx: -1, dy: 0 },
  ][hitFace];
  const sec = getCell(level, mapX + nd.dx, mapY + nd.dy);
  return faces.some((f) => f.sec === sec && f.dir === hitFace);
}

/** Sample 16×16 switch over unclamped wall [wallTopY, wallBotY); V=0 at floor. */
function paintSwitchColumn(fb, col, yTop, yBot, wallU, img, grey, wpat, wallTopY, wallBotY) {
  if (yBot <= yTop) return;
  const wallH = wallBotY - wallTopY;
  if (wallH <= 0) return;
  const pix = switchPixels(img);
  const u = Math.min(15, Math.floor(wallU * 16));
  for (let y = yTop; y < yBot; y++) {
    const fromBottom = wallBotY - 1 - y;
    let v = Math.floor((fromBottom * 16) / wallH);
    if (v < 0) v = 0;
    if (v > 15) v = 15;
    const rgba = pix ? pix[(15 - v) * 16 + u] : null;
    // Clear = alpha or magenta key (matches gen_wall_switch.js); black is opaque
    const clear =
      !rgba ||
      rgba[3] < 128 ||
      (rgba[0] === 255 && rgba[1] === 0 && rgba[2] === 255);
    if (!clear) {
      fillSolidSpan(fb, col, y, y + 1, rgba);
    } else {
      fillWallSpan(fb, col, y, y + 1, grey, wpat);
    }
  }
}

const switchPixCache = new WeakMap();

function switchPixels(img) {
  if (!img?.complete || !img.naturalWidth) return null;
  let cached = switchPixCache.get(img);
  if (cached) return cached;
  const w = img.naturalWidth;
  const h = img.naturalHeight;
  const c = document.createElement('canvas');
  c.width = 16;
  c.height = 16;
  const cctx = c.getContext('2d');
  cctx.imageSmoothingEnabled = false;
  cctx.drawImage(img, 0, 0, w, h, 0, 0, 16, 16);
  const data = cctx.getImageData(0, 0, 16, 16).data;
  const pix = new Array(256);
  for (let i = 0; i < 256; i++) {
    const o = i * 4;
    pix[i] = [data[o], data[o + 1], data[o + 2], data[o + 3]];
  }
  switchPixCache.set(img, pix);
  return pix;
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

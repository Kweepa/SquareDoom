import {
  MAP_SIZE,
  WORLD_PER_TILE,
  getCell,
  tileKey,
  tilesInSector,
  colorHex,
  isDoorSector,
  isWindowSector,
  isSwitch,
  findSectorIdByTag,
  normalizeTrigger,
  worldToTile,
} from './model.js';

export class MapView {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {object} opts
   * @param {() => any} opts.getLevel
   * @param {() => {
   *   tiles: Set<string>,
   *   items: Set<any>,
   *   hoverTile: {tx:number,ty:number}|null,
   *   box: {x0:number,y0:number,x1:number,y1:number}|null,
   * }} opts.getSelection
   * @param {(ev: PointerEvent, info: object) => void} opts.onPointer
   * @param {(type: string, wx: number, wy: number) => void} opts.onDropItem
   * @param {Record<string, HTMLImageElement>} opts.images
   * @param {HTMLElement} [opts.stage]
   */
  constructor(canvas, opts) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.opts = opts;
    this.cell = 18;
    this.stage = opts.stage || canvas.parentElement;
    this._ro = null;
    this.dragGrab = null;

    this.resize();
    this._ro = new ResizeObserver(() => this.resize());
    if (this.stage) this._ro.observe(this.stage);

    canvas.addEventListener('pointerdown', (e) => this.#onPointer(e));
    canvas.addEventListener('pointermove', (e) => this.#onPointer(e));
    canvas.addEventListener('pointerup', (e) => this.#onPointer(e));
    canvas.addEventListener('pointerleave', (e) => this.#onPointer(e));
    canvas.addEventListener('dragover', (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'copy';
    });
    canvas.addEventListener('drop', (e) => {
      e.preventDefault();
      const type = e.dataTransfer.getData('text/item-type') || e.dataTransfer.getData('text/plain');
      if (!type) return;
      const { wx, wy } = this.#eventWorld(e);
      this.opts.onDropItem(type, wx, wy);
    });
  }

  resize() {
    if (!this.stage) return;
    const rect = this.stage.getBoundingClientRect();
    const pad = 2;
    const side = Math.max(64, Math.floor(Math.min(rect.width, rect.height) - pad));
    const cell = Math.max(4, Math.floor(side / MAP_SIZE));
    const px = cell * MAP_SIZE;
    if (cell === this.cell && this.canvas.width === px) return;
    this.cell = cell;
    this.canvas.width = px;
    this.canvas.height = px;
    this.canvas.style.width = `${px}px`;
    this.canvas.style.height = `${px}px`;
    this.draw();
  }

  #eventCanvas(e) {
    const rect = this.canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * this.canvas.width;
    const y = ((e.clientY - rect.top) / rect.height) * this.canvas.height;
    return { x, y };
  }

  #canvasToWorld(x, y) {
    const c = this.cell;
    return {
      wx: Math.max(0, Math.min(255, Math.round((x / c) * WORLD_PER_TILE))),
      wy: Math.max(0, Math.min(255, Math.round((y / c) * WORLD_PER_TILE))),
    };
  }

  #eventCell(e) {
    const { x, y } = this.#eventCanvas(e);
    const tx = Math.max(0, Math.min(MAP_SIZE - 1, Math.floor(x / this.cell)));
    const ty = Math.max(0, Math.min(MAP_SIZE - 1, Math.floor(y / this.cell)));
    return { tx, ty, px: x, py: y };
  }

  #eventWorld(e) {
    const { x, y } = this.#eventCanvas(e);
    return this.#canvasToWorld(x, y);
  }

  #itemDrawPos(it, c) {
    const ix = (it.x / WORLD_PER_TILE) * c;
    const iy = (it.y / WORLD_PER_TILE) * c;
    const spriteSize = Math.max(6, Math.round(c * 0.45));
    return { ix, iy, spriteSize };
  }

  #spriteSize(it, baseSize) {
    const img = this.opts.images[it.type];
    let drawW = baseSize;
    const drawH = baseSize;
    if (img?.complete && img.naturalWidth > 0) {
      drawW = drawH * (img.naturalWidth / img.naturalHeight);
    }
    return { drawW, drawH };
  }

  #hitItem(level, px, py) {
    const markers = level.spawn ? [...level.items, level.spawn] : level.items;
    for (let i = markers.length - 1; i >= 0; i--) {
      const it = markers[i];
      const { ix, iy, spriteSize } = this.#itemDrawPos(it, this.cell);
      const { drawW, drawH } = this.#spriteSize(it, spriteSize);
      const left = ix - drawW / 2;
      const top = iy - drawH / 2;
      if (px >= left && px <= left + drawW && py >= top && py <= top + drawH) return it;
    }
    return null;
  }

  #onPointer(e) {
    const { tx, ty, px, py } = this.#eventCell(e);
    const level = this.opts.getLevel();
    const item = this.#hitItem(level, px, py);

    if (e.type === 'pointerdown' && item) {
      const pos = this.#itemDrawPos(item, this.cell);
      this.dragGrab = { x: px - pos.ix, y: py - pos.iy };
    }
    if (e.type === 'pointerup' || e.type === 'pointerleave') {
      this.dragGrab = null;
    }

    const grab = this.dragGrab ?? { x: 0, y: 0 };
    const { wx, wy } = this.#canvasToWorld(px - grab.x, py - grab.y);

    this.opts.onPointer(e, {
      tx,
      ty,
      wx,
      wy,
      px,
      py,
      item,
      sectorId: getCell(level, tx, ty),
      shift: e.shiftKey,
      alt: e.altKey,
      ctrl: e.ctrlKey || e.metaKey,
    });
  }

  #sectorFill(level, id) {
    if (id === 0) return '#1a1a1e';
    const s = level.sectors.get(id);
    if (!s) return '#333';
    const base = colorHex(s.floorColor) || '#444';
    return mixHex(base, 0.35 + (s.floorHeight / 31) * 0.25 + ((id * 17) % 7) * 0.03);
  }

  draw() {
    const level = this.opts.getLevel();
    const sel = this.opts.getSelection();
    const ctx = this.ctx;
    const c = this.cell;
    if (!c) return;

    ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);

    for (let ty = 0; ty < MAP_SIZE; ty++) {
      for (let tx = 0; tx < MAP_SIZE; tx++) {
        const id = getCell(level, tx, ty);
        ctx.fillStyle = this.#sectorFill(level, id);
        ctx.fillRect(tx * c, ty * c, c, c);
      }
    }

    // Door / window markers mid-tile
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = `${Math.max(4, Math.floor(c * 0.325))}px sans-serif`;
    for (let ty = 0; ty < MAP_SIZE; ty++) {
      for (let tx = 0; tx < MAP_SIZE; tx++) {
        const id = getCell(level, tx, ty);
        if (!id) continue;
        const s = level.sectors.get(id);
        let mark = null;
        if (isDoorSector(s) && !String(s.targetTag || '').trim()) {
          const cc = s.ceilingColor & 15;
          ctx.fillStyle = (cc === 2 || cc === 6 || cc === 7)
            ? colorHex(cc)
            : 'rgba(255,255,255,0.9)';
          mark = 'D';
        } else if (isWindowSector(s)) {
          ctx.fillStyle = 'rgba(255,255,255,0.9)';
          mark = 'W';
        }
        if (mark) ctx.fillText(mark, tx * c + c / 2, ty * c + c / 2);
      }
    }

    ctx.strokeStyle = 'rgba(255,255,255,0.08)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let i = 0; i <= MAP_SIZE; i++) {
      ctx.moveTo(i * c + 0.5, 0);
      ctx.lineTo(i * c + 0.5, MAP_SIZE * c);
      ctx.moveTo(0, i * c + 0.5);
      ctx.lineTo(MAP_SIZE * c, i * c + 0.5);
    }
    ctx.stroke();

    // Lightly hatch all tiles in the selection's shared sector
    const sectorId = sharedSelectionSector(level, sel.tiles);
    if (sectorId) {
      ctx.fillStyle = whiteHatchPattern(ctx);
      for (const { tx, ty } of tilesInSector(level, sectorId)) {
        ctx.fillRect(tx * c, ty * c, c, c);
      }
    }

    // Selected tiles
    if (sel.tiles?.size) {
      ctx.fillStyle = 'rgba(255, 220, 80, 0.28)';
      ctx.strokeStyle = 'rgba(255, 220, 80, 0.95)';
      ctx.lineWidth = Math.max(1, Math.round(c / 9));
      for (const key of sel.tiles) {
        const [tx, ty] = key.split(',').map(Number);
        ctx.fillRect(tx * c, ty * c, c, c);
        ctx.strokeRect(tx * c + 1, ty * c + 1, c - 2, c - 2);
      }
    }

    // Target link arrows for a single selected tile
    if (sel.tiles?.size === 1) {
      const [selKey] = sel.tiles;
      const [stx, sty] = selKey.split(',').map(Number);
      drawTargetArrows(ctx, level, stx, sty, c);
    }

    // Switch → target: single selected switch on a sector with trigger=switch + targetTag
    if (sel.items?.size === 1) {
      const [it] = sel.items;
      if (isSwitch(it)) drawSwitchTargetArrow(ctx, level, it, c);
    }

    // Marquee box
    if (sel.box) {
      const x0 = Math.min(sel.box.x0, sel.box.x1);
      const y0 = Math.min(sel.box.y0, sel.box.y1);
      const x1 = Math.max(sel.box.x0, sel.box.x1);
      const y1 = Math.max(sel.box.y0, sel.box.y1);
      const px = x0 * c;
      const py = y0 * c;
      const pw = (x1 - x0 + 1) * c;
      const ph = (y1 - y0 + 1) * c;
      ctx.fillStyle = 'rgba(120, 180, 255, 0.12)';
      ctx.fillRect(px, py, pw, ph);
      ctx.strokeStyle = 'rgba(120, 180, 255, 0.95)';
      ctx.lineWidth = 1.5;
      ctx.setLineDash([4, 3]);
      ctx.strokeRect(px + 0.5, py + 0.5, pw - 1, ph - 1);
      ctx.setLineDash([]);
    }

    // Hover tile
    if (sel.hoverTile) {
      const { tx, ty } = sel.hoverTile;
      if (!sel.tiles?.has(tileKey(tx, ty))) {
        ctx.strokeStyle = 'rgba(255,255,255,0.45)';
        ctx.lineWidth = 1;
        ctx.strokeRect(tx * c + 0.5, ty * c + 0.5, c - 1, c - 1);
      }
    }

    const markers = level.spawn ? [level.spawn, ...level.items] : level.items;
    for (const it of markers) {
      const { ix, iy, spriteSize } = this.#itemDrawPos(it, c);
      const { drawW, drawH } = this.#spriteSize(it, spriteSize);
      const left = ix - drawW / 2;
      const top = iy - drawH / 2;
      const img = this.opts.images[it.type];
      if (img && img.complete) {
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(img, left, top, drawW, drawH);
      } else {
        ctx.fillStyle = '#fa0';
        ctx.fillRect(left, top, drawW, drawH);
      }
      // Facing tick for spawn / camera (matches preview: sin θ, −cos θ)
      if (it.type === 'spawn' || it.type === 'camera') {
        const ang = it.angle ?? 0;
        const len = Math.max(4, spriteSize * 0.55);
        ctx.strokeStyle = it.type === 'spawn' ? '#0f0' : '#4af';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(ix, iy);
        ctx.lineTo(ix + Math.sin(ang) * len, iy - Math.cos(ang) * len);
        ctx.stroke();
      }
      if (sel.items?.has(it)) {
        ctx.strokeStyle = '#fff';
        ctx.lineWidth = 2;
        ctx.strokeRect(left - 1, top - 1, drawW + 2, drawH + 2);
      }
    }
  }
}

function mixHex(a, t) {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(a);
  if (!m) return a;
  let r = parseInt(m[1], 16);
  let g = parseInt(m[2], 16);
  let b = parseInt(m[3], 16);
  const lift = Math.floor(40 * t);
  r = Math.min(255, r + lift);
  g = Math.min(255, g + lift);
  b = Math.min(255, b + lift);
  return `rgb(${r},${g},${b})`;
}

let _hatchPattern = null;

function whiteHatchPattern(ctx) {
  if (_hatchPattern) return _hatchPattern;
  const size = 6;
  const off = document.createElement('canvas');
  off.width = size;
  off.height = size;
  const o = off.getContext('2d');
  o.strokeStyle = 'rgba(255, 255, 255, 0.45)';
  o.lineWidth = 1;
  o.beginPath();
  o.moveTo(-1, size - 1);
  o.lineTo(size - 1, -1);
  o.moveTo(0, size + 1);
  o.lineTo(size + 1, 0);
  o.stroke();
  _hatchPattern = ctx.createPattern(off, 'repeat');
  return _hatchPattern;
}

/** Sector id shared by every selected tile, or 0 if empty/mixed/void. */
function sharedSelectionSector(level, tiles) {
  if (!tiles?.size) return 0;
  let sectorId = 0;
  let first = true;
  for (const key of tiles) {
    const [tx, ty] = key.split(',').map(Number);
    const id = getCell(level, tx, ty);
    if (first) {
      sectorId = id;
      first = false;
    } else if (id !== sectorId) {
      return 0;
    }
  }
  return sectorId;
}

/** Average tile coords of a sector (for arrow endpoints). */
function sectorCentroid(level, sectorId) {
  const tiles = tilesInSector(level, sectorId);
  if (!tiles.length) return null;
  let sx = 0;
  let sy = 0;
  for (const { tx, ty } of tiles) {
    sx += tx;
    sy += ty;
  }
  return { tx: sx / tiles.length, ty: sy / tiles.length };
}

/**
 * Draw arrows for sector targetTag links when a single tile is selected:
 * - outgoing: selected sector → its targetTag sector
 * - incoming: sectors that target this sector's tag → selected tile
 */
function drawTargetArrows(ctx, level, stx, sty, c) {
  const sectorId = getCell(level, stx, sty);
  if (!sectorId) return;
  const s = level.sectors.get(sectorId);
  if (!s) return;

  /** @type {{ from: {tx:number,ty:number}, to: {tx:number,ty:number} }[]} */
  const arrows = [];
  const selected = { tx: stx, ty: sty };

  const to = resolveTargetCentroid(level, s, sectorId);
  if (to) arrows.push({ from: selected, to });

  const tag = String(s.tag || '').trim();
  if (tag) {
    for (const [id, other] of level.sectors) {
      if (id === sectorId) continue;
      if (String(other.targetTag || '').trim() !== tag) continue;
      const from = sectorCentroid(level, id);
      if (from) arrows.push({ from, to: selected });
    }
  }

  for (const { from, to: dest } of arrows) {
    drawArrow(
      ctx,
      (from.tx + 0.5) * c,
      (from.ty + 0.5) * c,
      (dest.tx + 0.5) * c,
      (dest.ty + 0.5) * c,
    );
  }
}

/**
 * Arrow from the tile under a switch to its target sector, when the sector
 * under the switch has trigger=switch and a resolvable targetTag.
 */
function drawSwitchTargetArrow(ctx, level, it, c) {
  const { tx, ty } = worldToTile(it.x, it.y);
  const sectorId = getCell(level, tx, ty);
  if (!sectorId) return;
  const s = level.sectors.get(sectorId);
  if (!s) return;
  if (normalizeTrigger(s.trigger) !== 'switch') return;
  const to = resolveTargetCentroid(level, s, sectorId);
  if (!to) return;
  drawArrow(
    ctx,
    (tx + 0.5) * c,
    (ty + 0.5) * c,
    (to.tx + 0.5) * c,
    (to.ty + 0.5) * c,
  );
}

/** Centroid of the sector named by s.targetTag, or null if unset/unresolved. */
function resolveTargetCentroid(level, s, fromSectorId) {
  const targetTag = String(s.targetTag || '').trim();
  if (!targetTag) return null;
  const tid = findSectorIdByTag(level, targetTag);
  if (!tid || tid === fromSectorId) return null;
  return sectorCentroid(level, tid);
}

function drawArrow(ctx, x0, y0, x1, y1) {
  const dx = x1 - x0;
  const dy = y1 - y0;
  const len = Math.hypot(dx, dy);
  if (len < 2) return;
  const ux = dx / len;
  const uy = dy / len;

  ctx.save();
  ctx.strokeStyle = 'rgba(80, 200, 255, 0.95)';
  ctx.fillStyle = 'rgba(80, 200, 255, 0.95)';
  ctx.lineWidth = 2;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x0, y0);
  ctx.lineTo(x1, y1);
  ctx.stroke();

  const ah = Math.max(6, Math.min(14, len * 0.22));
  const aw = ah * 0.55;
  ctx.beginPath();
  ctx.moveTo(x1, y1);
  ctx.lineTo(x1 - ux * ah - uy * aw, y1 - uy * ah + ux * aw);
  ctx.lineTo(x1 - ux * ah + uy * aw, y1 - uy * ah - ux * aw);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

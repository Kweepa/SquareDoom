import { COLORS, COLOR_HEX, sectorsEqual } from './model.js';

function numInput(id, label, min, max, value, mixed) {
  const wrap = document.createElement('label');
  wrap.className = 'field';
  wrap.htmlFor = id;
  const span = document.createElement('span');
  span.textContent = label;
  const input = document.createElement('input');
  input.type = 'number';
  input.id = id;
  input.min = String(min);
  input.max = String(max);
  if (mixed) {
    input.placeholder = 'mixed';
    input.value = '';
  } else {
    input.value = String(value);
  }
  wrap.append(span, input);
  return { wrap, input };
}

function colorPicker(id, label, value, mixed) {
  const wrap = document.createElement('div');
  wrap.className = 'field color-field';
  const span = document.createElement('span');
  span.textContent = label + (mixed ? ' (mixed)' : '');
  const row = document.createElement('div');
  row.className = 'color-swatches';
  /** @type {HTMLButtonElement[]} */
  const buttons = [];
  for (const c of COLORS) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'swatch' + (!mixed && c === value ? ' selected' : '');
    btn.title = c;
    btn.dataset.color = c;
    btn.style.background = COLOR_HEX[c];
    buttons.push(btn);
    row.appendChild(btn);
  }
  wrap.append(span, row);
  return { wrap, buttons };
}

function summarizeProps(propList) {
  if (!propList.length) return null;
  const keys = [
    'floorHeight', 'ceilingHeight', 'nsTexture', 'ewTexture',
    'brightness', 'floorColor', 'ceilingColor',
  ];
  const out = { ...propList[0], _mixed: {} };
  for (const key of keys) {
    const first = propList[0][key];
    out._mixed[key] = propList.some((p) => p[key] !== first);
  }
  return out;
}

export class TileEditor {
  /**
   * @param {HTMLElement} root
   * @param {{
   *   getTiles: () => Array<{tx:number,ty:number}>,
   *   getProps: () => Array<object>,
   *   sectorCount: () => number,
   *   onChange: (patch: object) => void,
   *   onClear: () => void,
   *   onSelectSector: () => void,
   * }} opts
   */
  constructor(root, opts) {
    this.root = root;
    this.opts = opts;
    this.render();
  }

  render() {
    const tiles = this.opts.getTiles();
    const propsList = this.opts.getProps();
    this.root.innerHTML = '';
    this.root.classList.add('panel', 'tile-editor');

    const h = document.createElement('h2');
    h.textContent = 'Tile';
    this.root.appendChild(h);

    const countLine = document.createElement('p');
    countLine.className = 'muted';
    countLine.textContent = `Sectors: ${this.opts.sectorCount()}`;
    this.root.appendChild(countLine);

    if (!tiles.length) {
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent = 'Select tiles on the map. Shift+click empty to add.';
      this.root.appendChild(p);
      return;
    }

    const occupied = propsList.length;
    const selLine = document.createElement('p');
    selLine.className = 'muted';
    selLine.textContent = occupied
      ? `${tiles.length} tile${tiles.length === 1 ? '' : 's'} selected`
      : `${tiles.length} empty tile${tiles.length === 1 ? '' : 's'} selected`;
    this.root.appendChild(selLine);

    if (!occupied) {
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent = 'No properties — Shift+click to paint, or select occupied tiles.';
      this.root.appendChild(p);
      this.#actions();
      return;
    }

    const s = summarizeProps(propsList);
    const allSame = propsList.every((p) => sectorsEqual(p, propsList[0]));
    if (!allSame) {
      const note = document.createElement('p');
      note.className = 'muted';
      note.textContent = 'Mixed values — edits apply to all selected tiles.';
      this.root.appendChild(note);
    }

    const floor = numInput('te-floor', 'Floor height', 0, 31, s.floorHeight, s._mixed.floorHeight);
    const ceil = numInput('te-ceil', 'Ceiling height', 0, 31, s.ceilingHeight, s._mixed.ceilingHeight);
    const ns = numInput('te-ns', 'N/S texture', 0, 15, s.nsTexture, s._mixed.nsTexture);
    const ew = numInput('te-ew', 'E/W texture', 0, 15, s.ewTexture, s._mixed.ewTexture);
    const bright = numInput('te-bright', 'Brightness', 0, 7, s.brightness, s._mixed.brightness);
    const floorCol = colorPicker('te-fcol', 'Floor colour', s.floorColor, s._mixed.floorColor);
    const ceilCol = colorPicker('te-ccol', 'Ceiling colour', s.ceilingColor, s._mixed.ceilingColor);

    const bindNum = (input, key) => {
      input.addEventListener('change', () => {
        if (input.value === '') return;
        this.opts.onChange({ [key]: Number(input.value) });
      });
    };
    bindNum(floor.input, 'floorHeight');
    bindNum(ceil.input, 'ceilingHeight');
    bindNum(ns.input, 'nsTexture');
    bindNum(ew.input, 'ewTexture');
    bindNum(bright.input, 'brightness');

    for (const btn of floorCol.buttons) {
      btn.addEventListener('click', () => this.opts.onChange({ floorColor: btn.dataset.color }));
    }
    for (const btn of ceilCol.buttons) {
      btn.addEventListener('click', () => this.opts.onChange({ ceilingColor: btn.dataset.color }));
    }

    this.root.append(
      floor.wrap, ceil.wrap, ns.wrap, ew.wrap, bright.wrap,
      floorCol.wrap, ceilCol.wrap,
    );
    this.#actions();
  }

  #actions() {
    const actions = document.createElement('div');
    actions.className = 'btn-row';

    const selectSector = document.createElement('button');
    selectSector.type = 'button';
    selectSector.textContent = 'Select sector';
    selectSector.title = 'Select all tiles in the sector of the primary selected tile';
    selectSector.addEventListener('click', () => this.opts.onSelectSector());
    actions.appendChild(selectSector);

    const clear = document.createElement('button');
    clear.type = 'button';
    clear.className = 'danger';
    clear.textContent = 'Clear tiles';
    clear.addEventListener('click', () => this.opts.onClear());
    actions.appendChild(clear);

    this.root.appendChild(actions);
  }
}

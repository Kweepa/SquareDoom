import { COLORS, COLOR_HEX } from './model.js';

function numInput(id, label, min, max, value) {
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
  input.value = String(value);
  wrap.append(span, input);
  return { wrap, input };
}

function colorPicker(id, label, value) {
  const wrap = document.createElement('div');
  wrap.className = 'field color-field';
  const span = document.createElement('span');
  span.textContent = label;
  const row = document.createElement('div');
  row.className = 'color-swatches';
  row.dataset.id = id;
  /** @type {HTMLButtonElement[]} */
  const buttons = [];
  for (const c of COLORS) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'swatch' + (c === value ? ' selected' : '');
    btn.title = c;
    btn.dataset.color = c;
    btn.style.background = COLOR_HEX[c];
    buttons.push(btn);
    row.appendChild(btn);
  }
  wrap.append(span, row);
  return { wrap, row, buttons, get: () => row.querySelector('.selected')?.dataset.color || 'black' };
}

export class SectorEditor {
  /**
   * @param {HTMLElement} root
   * @param {{
   *   getSector: () => {id:number, data:any}|null,
   *   onChange: (patch: object) => void,
   *   onMergeIdentical: () => void,
   *   onMergeWithNext: () => void,
   *   onDeleteSector: () => void,
   *   onClearTile: () => void,
   *   mergeArmed: () => boolean,
   * }} opts
   */
  constructor(root, opts) {
    this.root = root;
    this.opts = opts;
    this.render();
  }

  render() {
    const info = this.opts.getSector();
    this.root.innerHTML = '';
    this.root.classList.add('panel', 'sector-editor');

    const h = document.createElement('h2');
    h.textContent = 'Sector';
    this.root.appendChild(h);

    if (!info) {
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent = 'Select a sector on the map.';
      this.root.appendChild(p);
      this.#actions();
      return;
    }

    const { id, data: s } = info;
    const idLine = document.createElement('p');
    idLine.className = 'muted';
    idLine.textContent = `ID ${id}` + (this.opts.mergeArmed() ? ' — click another sector to merge into this' : '');
    this.root.appendChild(idLine);

    const floor = numInput('se-floor', 'Floor height', 0, 31, s.floorHeight);
    const ceil = numInput('se-ceil', 'Ceiling height', 0, 31, s.ceilingHeight);
    const ns = numInput('se-ns', 'N/S texture', 0, 15, s.nsTexture);
    const ew = numInput('se-ew', 'E/W texture', 0, 15, s.ewTexture);
    const bright = numInput('se-bright', 'Brightness', 0, 7, s.brightness);
    const floorCol = colorPicker('se-fcol', 'Floor colour', s.floorColor);
    const ceilCol = colorPicker('se-ccol', 'Ceiling colour', s.ceilingColor);

    const bindNum = (input, key) => {
      input.addEventListener('change', () => {
        const v = Number(input.value);
        this.opts.onChange({ [key]: v });
      });
    };
    bindNum(floor.input, 'floorHeight');
    bindNum(ceil.input, 'ceilingHeight');
    bindNum(ns.input, 'nsTexture');
    bindNum(ew.input, 'ewTexture');
    bindNum(bright.input, 'brightness');

    const bindSwatches = (picker, key) => {
      for (const btn of picker.buttons) {
        btn.addEventListener('click', () => {
          this.opts.onChange({ [key]: btn.dataset.color });
        });
      }
    };
    bindSwatches(floorCol, 'floorColor');
    bindSwatches(ceilCol, 'ceilingColor');

    this.root.append(
      floor.wrap, ceil.wrap, ns.wrap, ew.wrap, bright.wrap,
      floorCol.wrap, ceilCol.wrap,
    );
    this.#actions();
  }

  #actions() {
    const actions = document.createElement('div');
    actions.className = 'btn-row';

    const mk = (label, fn, cls = '') => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = label;
      if (cls) b.className = cls;
      b.addEventListener('click', fn);
      actions.appendChild(b);
      return b;
    };

    mk('Merge identical', () => this.opts.onMergeIdentical());
    mk(
      this.opts.mergeArmed() ? 'Cancel merge' : 'Merge with next',
      () => this.opts.onMergeWithNext(),
      this.opts.mergeArmed() ? 'armed' : '',
    );
    mk('Clear tile', () => this.opts.onClearTile());
    mk('Delete sector', () => this.opts.onDeleteSector(), 'danger');

    this.root.appendChild(actions);
  }
}

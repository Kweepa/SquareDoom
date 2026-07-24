import {
  C64_HEX, C64_NAMES, LEVEL_NAME_LEN, MAX_PLACEABLE_ITEMS,
  TRIGGERS, ACTIONS, normalizeTrigger, normalizeAction, sectorsEqual,
} from './model.js';

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

function textInput(id, label, value, mixed) {
  const wrap = document.createElement('label');
  wrap.className = 'field';
  wrap.htmlFor = id;
  const span = document.createElement('span');
  span.textContent = label;
  const input = document.createElement('input');
  input.type = 'text';
  input.id = id;
  input.autocomplete = 'off';
  input.spellcheck = false;
  if (mixed) {
    input.placeholder = 'mixed';
    input.value = '';
  } else {
    input.value = value ?? '';
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
  for (let i = 0; i < 16; i++) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'swatch' + (!mixed && i === value ? ' selected' : '');
    btn.title = `${i}: ${C64_NAMES[i]}`;
    btn.dataset.color = String(i);
    btn.style.background = C64_HEX[i];
    buttons.push(btn);
    row.appendChild(btn);
  }
  wrap.append(span, row);
  return { wrap, buttons };
}

function summarizeProps(propList) {
  if (!propList.length) return null;
  const keys = [
    'floorHeight', 'ceilingHeight', 'trigger', 'singleShot', 'action',
    'tag', 'targetTag', 'brightness', 'floorColor', 'ceilingColor',
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
   *   itemCount: () => number,
   *   hasItemSelection: () => boolean,
   *   getLevelName: () => string,
   *   onLevelNameChange: (name: string) => void,
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
    countLine.textContent = `Sectors: ${this.opts.sectorCount()} · Items: ${this.opts.itemCount()}/${MAX_PLACEABLE_ITEMS}`;
    this.root.appendChild(countLine);

    if (!tiles.length) {
      if (!this.opts.hasItemSelection()) {
        this.#levelNameFields();
      }
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent = 'Select tiles on the map. Shift+click empty to add; Shift+Alt overwrites.';
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

    if (occupied) {
      const ids = [...new Set(propsList.map((p) => p.id).filter((id) => id > 0))];
      const idLine = document.createElement('p');
      idLine.className = 'muted';
      if (ids.length === 1) {
        idLine.textContent = `Sector id: ${ids[0]}`;
      } else if (ids.length > 1) {
        idLine.textContent = `Sector ids: mixed (${ids.slice().sort((a, b) => a - b).join(', ')})`;
      }
      if (ids.length) this.root.appendChild(idLine);
    }

    if (!occupied) {
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent =
        'No properties — Shift+click empty to paint, Shift+Alt to overwrite, or select occupied tiles.';
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
    const bright = numInput('te-bright', 'Brightness', 0, 16, s.brightness, s._mixed.brightness);

    const mkSelect = (id, label, mixed, options, value, onChange) => {
      const wrap = document.createElement('label');
      wrap.className = 'field';
      wrap.htmlFor = id;
      const span = document.createElement('span');
      span.textContent = mixed ? `${label} (mixed)` : label;
      const sel = document.createElement('select');
      sel.id = id;
      for (const o of options) {
        const opt = document.createElement('option');
        opt.value = o.id;
        opt.textContent = o.name;
        sel.appendChild(opt);
      }
      if (!mixed) sel.value = value;
      else {
        const ph = document.createElement('option');
        ph.value = '';
        ph.textContent = 'mixed';
        ph.disabled = true;
        ph.selected = true;
        sel.prepend(ph);
      }
      sel.addEventListener('change', () => {
        if (sel.value === '') return;
        onChange(sel.value);
      });
      wrap.append(span, sel);
      return wrap;
    };

    const trigWrap = mkSelect(
      'te-trigger',
      'Trigger',
      s._mixed.trigger,
      TRIGGERS,
      normalizeTrigger(s.trigger),
      (v) => this.opts.onChange({ trigger: v }),
    );
    const actWrap = mkSelect(
      'te-action',
      'Action',
      s._mixed.action,
      ACTIONS,
      normalizeAction(s.action),
      (v) => this.opts.onChange({ action: v }),
    );

    const shotWrap = document.createElement('label');
    shotWrap.className = 'field';
    const shotCb = document.createElement('input');
    shotCb.type = 'checkbox';
    shotCb.id = 'te-oneshot';
    if (s._mixed.singleShot) {
      shotCb.indeterminate = true;
    } else {
      shotCb.checked = !!s.singleShot;
    }
    shotCb.addEventListener('change', () => {
      this.opts.onChange({ singleShot: shotCb.checked });
    });
    shotWrap.append(shotCb, document.createTextNode(
      s._mixed.singleShot ? ' Single-shot (mixed)' : ' Single-shot',
    ));

    const tag = textInput('te-tag', 'Sector tag', s.tag || '', s._mixed.tag);
    tag.input.addEventListener('change', () => {
      this.opts.onChange({ tag: tag.input.value });
    });

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
    bindNum(bright.input, 'brightness');

    for (const btn of floorCol.buttons) {
      btn.addEventListener('click', () => this.opts.onChange({ floorColor: Number(btn.dataset.color) }));
    }
    for (const btn of ceilCol.buttons) {
      btn.addEventListener('click', () => this.opts.onChange({ ceilingColor: Number(btn.dataset.color) }));
    }

    this.root.append(floor.wrap, ceil.wrap, bright.wrap, trigWrap, actWrap, shotWrap);

    const target = textInput(
      'te-target',
      s._mixed.targetTag ? 'Target tag (mixed)' : 'Target tag',
      s.targetTag || '',
      s._mixed.targetTag,
    );
    target.input.placeholder = s._mixed.targetTag ? 'mixed' : 'tag of target sector (optional)';
    target.input.addEventListener('change', () => {
      this.opts.onChange({ targetTag: target.input.value });
    });
    this.root.appendChild(target.wrap);

    this.root.append(tag.wrap, floorCol.wrap, ceilCol.wrap);
    this.#actions();
  }

  #levelNameFields() {
    const sub = document.createElement('h2');
    sub.textContent = 'Level';
    this.root.appendChild(sub);

    const field = textInput('te-level-name', 'Name', this.opts.getLevelName() || '', false);
    field.input.maxLength = LEVEL_NAME_LEN;
    field.input.placeholder = 'Level name';
    const commit = () => {
      this.opts.onLevelNameChange(field.input.value);
    };
    field.input.addEventListener('change', commit);
    field.input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        field.input.blur();
      }
    });
    this.root.appendChild(field.wrap);
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

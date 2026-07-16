import {
  ITEM_TYPES,
  CAMERA_TYPE,
  SPAWN_TYPE,
  WORLD_MAX,
  isCamera,
  isSpawn,
} from './model.js';

export class ItemEditor {
  /**
   * @param {HTMLElement} root
   * @param {{
   *   getItems: () => any[],
   *   onChange: (patch: object) => void,
   *   onDelete: () => void,
   * }} opts
   */
  constructor(root, opts) {
    this.root = root;
    this.opts = opts;
    this.render();
  }

  render() {
    const items = this.opts.getItems();
    this.root.innerHTML = '';
    this.root.classList.add('panel', 'item-editor');

    const h = document.createElement('h2');
    h.textContent = 'Item';
    this.root.appendChild(h);

    if (!items.length) {
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent = 'Select items on the map.';
      this.root.appendChild(p);
      return;
    }

    const item = items[0];
    const multi = items.length > 1;
    const onlySpawn = items.length === 1 && isSpawn(item);

    const selLine = document.createElement('p');
    selLine.className = 'muted';
    if (onlySpawn) {
      selLine.textContent = 'Player spawn — preview shows this viewpoint.';
    } else if (multi) {
      selLine.textContent = `${items.length} items selected — edits apply to all`;
    } else if (isCamera(item)) {
      selLine.textContent = 'Editor only — not included in cooked binary.';
    } else {
      selLine.textContent = item.type;
    }
    this.root.appendChild(selLine);

    if (!onlySpawn) {
      const typesSame = items.every((it) => it.type === item.type);
      const typeLab = document.createElement('label');
      typeLab.className = 'field';
      typeLab.innerHTML = '<span>Type</span>';
      const typeSel = document.createElement('select');
      if (!typesSame) {
        const mixed = document.createElement('option');
        mixed.value = '';
        mixed.textContent = '(mixed)';
        mixed.selected = true;
        typeSel.appendChild(mixed);
      }
      // Spawn is level.spawn only — not a convertible item type
      const types = ITEM_TYPES.filter((t) => t !== SPAWN_TYPE).concat(CAMERA_TYPE);
      for (const t of types) {
        const opt = document.createElement('option');
        opt.value = t;
        opt.textContent = t;
        if (typesSame && t === item.type) opt.selected = true;
        typeSel.appendChild(opt);
      }
      typeSel.addEventListener('change', () => {
        if (!typeSel.value) return;
        this.opts.onChange({ type: typeSel.value });
      });
      typeLab.appendChild(typeSel);
      this.root.appendChild(typeLab);
    }

    const xSame = items.every((it) => it.x === item.x);
    const ySame = items.every((it) => it.y === item.y);
    this.#numField('X', 'x', 0, WORLD_MAX, xSame ? item.x : null);
    this.#numField('Y', 'y', 0, WORLD_MAX, ySame ? item.y : null);

    const allViewpoints = items.every((it) => isCamera(it) || isSpawn(it));
    const noViewpoints = items.every((it) => !isCamera(it) && !isSpawn(it));

    if (allViewpoints) {
      const deg = Math.round(((item.angle ?? 0) * 180) / Math.PI);
      const angleSame = items.every(
        (it) => Math.round(((it.angle ?? 0) * 180) / Math.PI) === deg,
      );
      const angleLab = document.createElement('label');
      angleLab.className = 'field';
      const span = document.createElement('span');
      span.textContent = 'Angle (deg)';
      const input = document.createElement('input');
      input.type = 'number';
      input.min = '-180';
      input.max = '180';
      input.step = '1';
      if (angleSame) input.value = String(deg);
      else {
        input.placeholder = 'mixed';
        input.value = '';
      }
      input.addEventListener('change', () => {
        if (input.value === '') return;
        this.opts.onChange({ angle: (Number(input.value) * Math.PI) / 180 });
      });
      angleLab.append(span, input);
      this.root.appendChild(angleLab);
    } else if (noViewpoints) {
      const skills = document.createElement('div');
      skills.className = 'field skills';
      const skillLabel = document.createElement('span');
      skillLabel.textContent = 'Skill';
      skills.appendChild(skillLabel);
      const row = document.createElement('div');
      row.className = 'skill-row';
      for (const key of ['easy', 'normal', 'hard']) {
        const allOn = items.every((it) => it.skills?.[key]);
        const allOff = items.every((it) => !it.skills?.[key]);
        const lab = document.createElement('label');
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.checked = allOn;
        cb.indeterminate = !allOn && !allOff;
        cb.addEventListener('change', () => {
          this.opts.onChange({ skillKey: key, skillValue: cb.checked });
        });
        lab.append(cb, document.createTextNode(key));
        row.appendChild(lab);
      }
      skills.appendChild(row);
      this.root.appendChild(skills);
    }

    if (!onlySpawn) {
      const del = document.createElement('button');
      del.type = 'button';
      del.className = 'danger';
      del.textContent = multi ? 'Delete items' : 'Delete item';
      del.addEventListener('click', () => this.opts.onDelete());
      this.root.appendChild(del);
    }
  }

  #numField(label, key, min, max, value) {
    const lab = document.createElement('label');
    lab.className = 'field';
    const span = document.createElement('span');
    span.textContent = label;
    const input = document.createElement('input');
    input.type = 'number';
    input.min = String(min);
    input.max = String(max);
    if (value == null) {
      input.placeholder = 'mixed';
      input.value = '';
    } else {
      input.value = String(value);
    }
    input.addEventListener('change', () => {
      if (input.value === '') return;
      this.opts.onChange({ [key]: Number(input.value) });
    });
    lab.append(span, input);
    this.root.appendChild(lab);
  }
}

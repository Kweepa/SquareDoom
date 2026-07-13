import { ITEM_TYPES, CAMERA_TYPE, WORLD_MAX, isCamera } from './model.js';

export class ItemEditor {
  /**
   * @param {HTMLElement} root
   * @param {{
   *   getItem: () => any|null,
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
    const item = this.opts.getItem();
    this.root.innerHTML = '';
    this.root.classList.add('panel', 'item-editor');

    const h = document.createElement('h2');
    h.textContent = 'Item';
    this.root.appendChild(h);

    if (!item) {
      const p = document.createElement('p');
      p.className = 'muted';
      p.textContent = 'Select an item on the map.';
      this.root.appendChild(p);
      return;
    }

    if (isCamera(item)) {
      const note = document.createElement('p');
      note.className = 'muted';
      note.textContent = 'Editor only — not included in cooked binary.';
      this.root.appendChild(note);
    }

    const typeLab = document.createElement('label');
    typeLab.className = 'field';
    typeLab.innerHTML = '<span>Type</span>';
    const typeSel = document.createElement('select');
    const types = isCamera(item) ? [CAMERA_TYPE, ...ITEM_TYPES] : [...ITEM_TYPES, CAMERA_TYPE];
    for (const t of types) {
      const opt = document.createElement('option');
      opt.value = t;
      opt.textContent = t;
      if (t === item.type) opt.selected = true;
      typeSel.appendChild(opt);
    }
    typeSel.addEventListener('change', () => this.opts.onChange({ type: typeSel.value }));
    typeLab.appendChild(typeSel);
    this.root.appendChild(typeLab);

    const addNum = (key, label, min, max) => {
      const lab = document.createElement('label');
      lab.className = 'field';
      const span = document.createElement('span');
      span.textContent = label;
      const input = document.createElement('input');
      input.type = 'number';
      input.min = String(min);
      input.max = String(max);
      input.value = String(item[key]);
      input.addEventListener('change', () => {
        this.opts.onChange({ [key]: Number(input.value) });
      });
      lab.append(span, input);
      this.root.appendChild(lab);
    };
    addNum('x', 'X', 0, WORLD_MAX);
    addNum('y', 'Y', 0, WORLD_MAX);

    if (isCamera(item)) {
      const angleLab = document.createElement('label');
      angleLab.className = 'field';
      const span = document.createElement('span');
      span.textContent = 'Angle (deg)';
      const input = document.createElement('input');
      input.type = 'number';
      input.min = '-180';
      input.max = '180';
      input.step = '1';
      input.value = String(Math.round(((item.angle ?? 0) * 180) / Math.PI));
      input.addEventListener('change', () => {
        this.opts.onChange({ angle: (Number(input.value) * Math.PI) / 180 });
      });
      angleLab.append(span, input);
      this.root.appendChild(angleLab);
    } else {
      const skills = document.createElement('div');
      skills.className = 'field skills';
      const skillLabel = document.createElement('span');
      skillLabel.textContent = 'Skill';
      skills.appendChild(skillLabel);
      const row = document.createElement('div');
      row.className = 'skill-row';
      for (const key of ['easy', 'normal', 'hard']) {
        const lab = document.createElement('label');
        const cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.checked = !!item.skills[key];
        cb.addEventListener('change', () => {
          this.opts.onChange({ skills: { ...item.skills, [key]: cb.checked } });
        });
        lab.append(cb, document.createTextNode(key));
        row.appendChild(lab);
      }
      skills.appendChild(row);
      this.root.appendChild(skills);
    }

    const del = document.createElement('button');
    del.type = 'button';
    del.className = 'danger';
    del.textContent = 'Delete item';
    del.addEventListener('click', () => this.opts.onDelete());
    this.root.appendChild(del);
  }
}

import { LEVEL_NAMES } from './model.js';

export class LevelList {
  /**
   * @param {HTMLElement} root
   * @param {{ getActive: () => string, onSelect: (name: string) => void }} opts
   */
  constructor(root, opts) {
    this.root = root;
    this.opts = opts;
    root.classList.add('level-list');
    this.render();
  }

  render() {
    const active = this.opts.getActive();
    this.root.innerHTML = '';
    const title = document.createElement('h2');
    title.textContent = 'Levels';
    this.root.appendChild(title);

    const ul = document.createElement('ul');
    for (const name of LEVEL_NAMES) {
      const li = document.createElement('li');
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.textContent = name;
      btn.className = name === active ? 'active' : '';
      btn.addEventListener('click', () => this.opts.onSelect(name));
      li.appendChild(btn);
      ul.appendChild(li);
    }
    this.root.appendChild(ul);
  }
}

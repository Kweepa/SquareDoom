import { EDITOR_ITEM_TYPES } from './model.js';

export class ItemPalette {
  /**
   * @param {HTMLElement} root
   * @param {Record<string, HTMLImageElement>} images
   */
  constructor(root, images) {
    this.root = root;
    root.classList.add('item-palette');
    root.innerHTML = '';

    for (const type of EDITOR_ITEM_TYPES) {
      const el = document.createElement('div');
      el.className = 'palette-item';
      el.draggable = true;
      el.title = type;
      el.dataset.type = type;

      const img = images[type];
      if (img) {
        const clone = img.cloneNode(true);
        clone.draggable = false;
        el.appendChild(clone);
      } else {
        el.textContent = type.slice(0, 2);
      }

      const label = document.createElement('span');
      label.textContent = type;
      el.appendChild(label);

      el.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/item-type', type);
        e.dataTransfer.setData('text/plain', type);
        e.dataTransfer.effectAllowed = 'copy';
      });

      root.appendChild(el);
    }
  }
}

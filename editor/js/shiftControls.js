/**
 * @param {HTMLElement} root
 * @param {(dx: number, dy: number) => void} onShift
 */
export function initShiftControls(root, onShift) {
  root.className = 'shift-controls panel';
  root.innerHTML = '';

  const h = document.createElement('h2');
  h.textContent = 'Shift map';
  root.appendChild(h);

  const pad = document.createElement('div');
  pad.className = 'shift-pad';

  const mk = (label, dx, dy, cls) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `shift-btn ${cls}`;
    btn.title = label;
    btn.setAttribute('aria-label', label);
    btn.textContent = cls === 'up' ? '↑' : cls === 'down' ? '↓' : cls === 'left' ? '←' : '→';
    btn.addEventListener('click', () => onShift(dx, dy));
    return btn;
  };

  pad.append(
    mk('Shift up', 0, -1, 'up'),
    mk('Shift left', -1, 0, 'left'),
    mk('Shift right', 1, 0, 'right'),
    mk('Shift down', 0, 1, 'down'),
  );
  root.appendChild(pad);

  const hint = document.createElement('p');
  hint.className = 'muted';
  hint.textContent = 'Moves all tiles and items. Off-map content is deleted.';
  root.appendChild(hint);
}

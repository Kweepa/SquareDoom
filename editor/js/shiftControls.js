/**
 * @param {HTMLElement} root
 * @param {(dx: number, dy: number) => void} onShift
 * @param {(delta: number) => void} onHeight
 */
export function initShiftControls(root, onShift, onHeight) {
  root.className = 'shift-controls panel';
  root.innerHTML = '';

  const h = document.createElement('h2');
  h.textContent = 'Shift';
  root.appendChild(h);

  const row = document.createElement('div');
  row.className = 'shift-row';

  const pad = document.createElement('div');
  pad.className = 'shift-pad';

  const mk = (label, dx, dy, cls) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `shift-btn shift-${cls}`;
    btn.title = label;
    btn.setAttribute('aria-label', label);
    btn.textContent = cls === 'up' ? '↑' : cls === 'down' ? '↓' : cls === 'left' ? '←' : '→';
    btn.addEventListener('click', () => onShift(dx, dy));
    return btn;
  };

  pad.append(
    mk('Shift up', 0, -1, 'up'),
    mk('Shift left', -1, 0, 'left'),
    mk('Shift down', 0, 1, 'down'),
    mk('Shift right', 1, 0, 'right'),
  );
  row.appendChild(pad);

  const height = document.createElement('div');
  height.className = 'shift-height';

  const mkH = (label, delta, cls) => {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `shift-btn height ${cls}`;
    btn.title = label;
    btn.setAttribute('aria-label', label);
    btn.textContent = delta > 0 ? '↑' : '↓';
    btn.addEventListener('click', () => onHeight(delta));
    return btn;
  };

  height.append(
    mkH('Raise floor & ceiling', 1, 'raise'),
    mkH('Lower floor & ceiling', -1, 'lower'),
  );
  row.appendChild(height);
  root.appendChild(row);

  const hint = document.createElement('p');
  hint.className = 'muted';
  hint.textContent =
    'Selection if any (tiles + items in them), else whole map. Height arrows move floor & ceiling together.';
  root.appendChild(hint);
}

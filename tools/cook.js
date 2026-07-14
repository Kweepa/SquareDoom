/**
 * Cook episode1.json → levels/e1m1.bin (SoA sector tables).
 */
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { cookLevel, episodeFromJSON } from '../editor/js/io.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const ep = episodeFromJSON(
  JSON.parse(readFileSync(join(root, 'editor', 'episode1.json'), 'utf8')),
);
const levelName = ep.activeLevel || 'E1M1';
const level = ep.levels[levelName];
if (!level) {
  console.error('No level', levelName);
  process.exit(1);
}
const { bytes, warnings } = cookLevel(level);
for (const w of warnings) console.warn(w);
const outPath = join(root, 'levels', `${levelName.toLowerCase()}.bin`);
writeFileSync(outPath, bytes);
console.log('wrote', outPath, bytes.length, 'bytes');

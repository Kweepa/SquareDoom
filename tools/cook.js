/**
 * Cook episode1.json → levels/e1m1.bin … e1m9.bin (map + item layer + sectors).
 */
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { cookLevel, episodeFromJSON } from '../editor/js/io.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const ep = episodeFromJSON(
  JSON.parse(readFileSync(join(root, 'editor', 'episode1.json'), 'utf8')),
);

const names = Object.keys(ep.levels).sort();
if (!names.length) {
  console.error('No levels in episode');
  process.exit(1);
}

let failed = false;
for (const levelName of names) {
  const level = ep.levels[levelName];
  const { bytes, warnings, errors } = cookLevel(level);
  for (const w of warnings) console.warn(levelName, w);
  if (errors?.length) {
    for (const e of errors) console.error(levelName, e);
    failed = true;
    continue;
  }
  const outPath = join(root, 'levels', `${levelName.toLowerCase()}.bin`);
  writeFileSync(outPath, bytes);
  console.log('wrote', outPath, bytes.length, 'bytes');
}
if (failed) process.exit(1);

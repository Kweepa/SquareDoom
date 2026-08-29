#!/usr/bin/env python3
"""Generate shotgun_cock_sprites.asm from shotgun_cock.png (24x42).

Layers (hires, 2x expand): black hi/lo stacked, grey top, highlight bottom,
brown+orange hand mid-crop (rows 9-29 -> Y=184). At SHOTGUN_COCK_SPRITES ($3b80).
"""
from PIL import Image

img = Image.open(r'itemgraphics/multicolour/shotgun_cock.png').convert('RGBA')
W, H = img.size  # 24x42

# Hand: brown 10-30 @ Y=186; orange 9-29 @ Y=184 (keep top orange px)
BROWN_ROW0 = 10
ORANGE_ROW0 = 9
BROWN_Y = 166 + BROWN_ROW0 * 2   # 186
ORANGE_Y = 166 + ORANGE_ROW0 * 2  # 184

def sprite_bytes_rows(mask_fn, row_start):
	"""Pack 21 source rows starting at row_start into one C64 sprite."""
	rows = []
	for y in range(21):
		src_y = y + row_start
		b0 = b1 = b2 = 0
		for x in range(24):
			if src_y < H:
				px = img.getpixel((x, src_y))
				bit = 1 if mask_fn(*px) else 0
			else:
				bit = 0
			if x < 8:
				b0 |= (bit << (7 - x))
			elif x < 16:
				b1 |= (bit << (15 - x))
			else:
				b2 |= (bit << (23 - x))
		rows.append((b0, b1, b2))
	return rows

def emit(name, rows, out):
	all_bytes = []
	for b0, b1, b2 in rows:
		all_bytes += [b0, b1, b2]
	all_bytes.append(0)  # pad to 64
	out.append(name)
	for i in range(0, 64, 8):
		chunk = all_bytes[i:i + 8]
		out.append('\t!byte ' + ','.join('$%02x' % v for v in chunk))

is_black = lambda r, g, b, a: a >= 128 and r < 20 and g < 20 and b < 20
is_darkgrey = lambda r, g, b, a: (
	a >= 128 and (r + g + b) // 3 > 80 and (r + g + b) // 3 <= 120
	and not (r >= 150 and b < 80)
)
is_lightgrey = lambda r, g, b, a: a >= 128 and (r + g + b) // 3 > 120
is_brown = lambda r, g, b, a: a >= 128 and r >= 20 and r < 150 and (r + g + b) // 3 <= 80
is_orange = lambda r, g, b, a: a >= 128 and r >= 150 and b < 80

lines = [
	'; Auto-generated from itemgraphics/multicolour/shotgun_cock.png - do not edit',
	'; Six body layers (low VIC # = front): black hi, black lo, dark grey, highlight, brown, orange.',
	'; Placed at SHOTGUN_COCK_SPRITES ($D640) in VIC bank 3; setup_shotgun_cock redirects SPR_PTR.',
	'; 24x42: blacks 0-20@166 / 21-41@208; grey top; highlight bot;'
	'; hand brown rows %d-%d @ Y=%d; orange rows %d-%d @ Y=%d.'
	% (BROWN_ROW0, BROWN_ROW0 + 20, BROWN_Y, ORANGE_ROW0, ORANGE_ROW0 + 20, ORANGE_Y),
	'!zone shotgun_cock_sprites',
	'',
]
emit('cock_black_hi', sprite_bytes_rows(is_black, 0), lines)
emit('cock_black_lo', sprite_bytes_rows(is_black, 21), lines)
emit('cock_grey', sprite_bytes_rows(is_darkgrey, 0), lines)
emit('cock_highlight', sprite_bytes_rows(is_lightgrey, 21), lines)
emit('cock_brown', sprite_bytes_rows(is_brown, BROWN_ROW0), lines)
emit('cock_orange', sprite_bytes_rows(is_orange, ORANGE_ROW0), lines)

path = 'shotgun_cock_sprites.asm'
with open(path, 'w', newline='\n') as f:
	f.write('\n'.join(lines) + '\n')
print('Wrote', path, 'brown Y=', BROWN_Y, 'orange Y=', ORANGE_Y)

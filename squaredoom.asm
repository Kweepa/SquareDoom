; SquareDoom ??? ACME root (C64)
!cpu 6502
!to "squaredoom.prg", cbm

; Play buffers under KERNAL (contiguous ??? also MENU.PRG overlay target).
; Judd SQTAB lives at $c800 (former FB/pattern slot; always-RAM).
; SID music window $9000???$9fff (4K), flush against level at $a000.
; UI disk loads (logo/text) ??? SCREENBUFFER[0..UI_LOAD_MAX); menu code after that.
UI_LOAD_MAX = 592			; ??? max CRED/HELP/ORDR/ENDG/logo payload (ordr=582)
SCREENBUFFER = $e000			; column-major colours (40??25)
PATTERNBUFFER = SCREENBUFFER + $400	; screen codes; hi = colour hi + 4
; COL_CLIP_* follows immediately after PATTERNBUFFER (see zeropage.asm)

SID_BASE = $9000			; 4K music load window (disk ??? here)
SID_SIZE = $1000
SID_LOAD_ADDR = SID_BASE

CHARSET = $3800
FIST_RIGHT_SPRITES = $2a00	; 8??64 open right hand (7 used)
FIST_PUNCH_SPRITES = $2c00	; 8??64 punch pose (7 used; pad overwritten by saw hi2)
CHAINSAW_BLADE_HI2_SPRITES = FIST_PUNCH_SPRITES + 7 * 64	; $2dc0
CHAINSAW_SPRITES = $2e00	; 8??64-byte chainsaw (no flash; VIC bank 0)
MINIGUN_B_SPRITES = FIST_RIGHT_SPRITES - 3 * 64	; $2940 ??? frame B upper+grey L/R
MINIGUN_SPRITES = $3000	; 6??64 A/shared body (VIC bank 0)
ROCKET_SPRITES = $3180		; 8??64-byte rocket+pink flash (VIC bank 0)
SHOTGUN_SPRITES = $3380	; 6??64-byte shotgun body (VIC bank 0)
PISTOL_SPRITES = $3500		; 6??64-byte pistol body (VIC bank 0)
MUZZLE_FLASH_SPRITES = $3680	; 4??64 shared flash A/B white+red (pistol/sg/mg)
; Packed charset at $3800 (tools/gencharset.js); cock sprites; mid after
; 0???15 walls; 16???63 doomfont punct/HUD/digits + gap packs; 64???89 A???Z; 90???105 floors
MENU_CURSOR = 16		; skull (gap)
MAP_ARROW0 = 17			; arrows 17???20
MAP_SOLID = 21			; filled block (map + logo)
ITEM_PAT = MAP_SOLID		; item soft-sprite fill (solid)
MSG_LET0 = 64			; A???Z (walls own PETSCII letter codes 1???15)
MSG_LETTER0 = MSG_LET0
FLOOR_PAT_BASE = 90		; floor dither 90???105
CHARSET_NUM = 106
CHARSET_END = CHARSET + CHARSET_NUM * 8	; $3b50
SHOTGUN_COCK_SPRITES = $3b80	; 6??64 cock pose (VIC bank 0; after charset pad)
MID_BASE = SHOTGUN_COCK_SPRITES + 6 * 64	; $3d00

MAX_DDA = 32
PROFILE = 0
DBG_FPS = 0
DBG_PORTAL = 0
CENTER_COL = 19
MUZZLE_COL = 20			; pistol muzzle aim column
AIM_COL_SLACK = 2		; TryDamageEnemy also checks MUZZLE??this (18..22)
MAX_SECTORS = 199		; usable ids 1..199
SEC_TABLE_SIZE = 200		; index = sector id; [0] unused

; Memory ceilings:
;   low  ??? sprites before CHARSET; charset $3800..CHARSET_END; cock $3b80; mid $3d00+
;   mid  ??? MID_BASE ??? SID_BASE; enemy mips here
;   SID  ??? $9000???$9fff (4K); level at $a000; high ??? py_tab ??? SQTAB at $c800
MEM_MID_LIMIT = SID_BASE		; mid code/data must end before SID window
MEM_LEVEL = $a000
MEM_HIGH_LIMIT = $c800			; Judd SQTAB occupies $c800???$cfff
; py_tab: 12 page-aligned pages, packed against SQTAB
PY_TAB_PAGES = 12
PY_TAB_SIZE = PY_TAB_PAGES * 256
PY_TAB = MEM_HIGH_LIMIT - PY_TAB_SIZE	; $bc00

!source "zeropage.asm"
!source "basicstub.asm"
!source "warmstart.asm"
!source "maths.asm"
!source "util.asm"
!source "input.asm"
!source "profil.asm"
!source "render.asm"
!source "blit.asm"
; enemy boss-death floors ??? low for mid headroom
!source "enemy_low.asm"
; Automap overlay in low scrap (was high; high now holds py_tab before SQTAB)
!source "mapscreen.asm"

end_low = *
free_low = MINIGUN_B_SPRITES - end_low
!if free_low < 0 {
	!error "Low code overlaps minigun B sprites at $2940; overshoot=", end_low - MINIGUN_B_SPRITES
}
!warn "mem: low  end=$", end_low, " free to minigun B $2940 =", free_low

; Weapon sprite banks in VIC bank 0, before charset
; minigun_weapon.asm: B??3 then *= MINIGUN_SPRITES for A/shared??6
*=MINIGUN_B_SPRITES
!source "minigun_weapon.asm"
*=FIST_RIGHT_SPRITES
!source "fist_righthand.asm"
*=FIST_PUNCH_SPRITES
!source "fist_punch.asm"
; chainsaw_weapon.asm: hi2 (64) then 8 layers ??? starts in punch pad
*=CHAINSAW_BLADE_HI2_SPRITES
!source "chainsaw_weapon.asm"
*=ROCKET_SPRITES
!source "rocket_weapon.asm"
*=SHOTGUN_SPRITES
!source "shotgun_weapon.asm"
*=PISTOL_SPRITES
!source "pistol_sprites.asm"
*=MUZZLE_FLASH_SPRITES
!source "muzzle_flash.asm"
!if * > CHARSET {
	!error "Muzzle sprites overlap charset at $3800; end=$", *
}

; Packed charset image (VIC reads in place); cock sprites; mid follows
*=CHARSET
!source "charset.asm"
!if * != CHARSET_END {
	!error "charset.asm size mismatch: ended at $", *, " expected CHARSET_END $", CHARSET_END
}
*=SHOTGUN_COCK_SPRITES
!source "shotgun_cock_sprites.asm"
!if * != MID_BASE {
	!error "cock sprites size mismatch: ended at $", *, " expected MID_BASE $", MID_BASE
}
*=MID_BASE
!source "weapon.asm"			; mid ??? grew past low free; sprites stay in bank 0
!source "gameloop.asm"
!source "level.asm"
!source "playsound.asm"
!source "process.asm"
!source "player.asm"
!source "enemy_mid.asm"
!source "missile.asm"
!source "hitscan.asm"
!source "debug.asm"
!source "hud.asm"
!source "pickup.asm"
!source "cheats.asm"			; iddqd / idkfa / idclev (after pickup for INFO_*)
!source "logo_defs.asm"			; LOGO_* constants (payload on disk ??? SCREENBUFFER)
!source "loader.asm"			; mid ??? LoadPrg/LoadMenu/LoadLevel; LoadUiFile in MENU.PRG
!source "titleflow.asm"			; resident flow/print/melt; menu UI from MENU.PRG
; Near flats + P + clip in mid (low headroom for PROFILE hooks elsewhere)
!source "render_near.asm"
!source "render_project_y.asm"
!source "render_clip.asm"
; Enemy mips in mid (always-RAM)
!source "enemy_sprites.asm"
; Switch atlas in mid scrap (was high; makes room for py_tab at $bc00)
!source "wall_switch.asm"

end_mid = *
free_mid = MEM_MID_LIMIT - end_mid
!if free_mid < 0 {
	!error "Mid code overlaps SID at $", MEM_MID_LIMIT, "; overshoot=", end_mid - MEM_MID_LIMIT
}
!warn "mem: mid  end=$", end_mid, " free to SID $", MEM_MID_LIMIT, " =", free_mid

; ------------------------------------------------------------------
; SID music window ??? 4K; level PRG loads here (SID + map at $a000)
; ------------------------------------------------------------------
*=SID_BASE
sid_data
	!fill SID_SIZE, 0
!if * != MEM_LEVEL {
	!error "SID window must end at $a000; ended at $", *
}

; ------------------------------------------------------------------
; Level window under BASIC ROM ($A000), RAM with $01=$35 ??? loaded from disk
; Layout: map first ($a000, 32-byte aligned for maprow+mapx), then 7??200
; sector attr tables, spawn, items, sector_max, enemies, items, secrets, par
; ------------------------------------------------------------------
LEVEL_BYTES = 2641
*=MEM_LEVEL
level_data
	!fill LEVEL_BYTES, 0

MAP_SIZE = 32
MAP_CELLS = 1024
MAX_ITEMS = 48
ITEM_BYTES = 4			; SoA: 4 arrays ?? MAX_ITEMS
SPAWN_BYTES = 3
STATS_BYTES = 4			; num_enemies, num_items, num_secrets, par_time
MAX_SWITCH_FACES = 8
SWITCH_FACE_BYTES = 1 + MAX_SWITCH_FACES * 2	; n + sec[8] + dir[8]

; SEC_TYPE packed: action[4:0] | trigger[6:5] | single_shot[7]
ACT_MASK = $1f
TRIG_MASK = $60
TRIG_SHIFT = 5
TRIG_NONE = 0
TRIG_WALK = 1
TRIG_USE = 2
TRIG_SWITCH = 3
SHOT_BIT = $80			; bmi after lda SEC_TYPE,x

ACT_NONE = 0
ACT_WINDOW = 1			; walk-blocked; hitscan/missiles pass
ACT_OPEN_DOOR = 2		; raise ceil +5, reclose 5s
ACT_OPEN_DOOR_FOREVER = 3
ACT_OPEN_DOOR_30S = 4
ACT_LOWER_FLOOR = 5		; min adjacent + return 5s
ACT_RAISE_FLOOR = 6		; max adjacent, permanent
ACT_RAISE_STAIRS = 7
ACT_CONTINUE_STAIRS = 8
ACT_END_LEVEL = 9
ACT_LOWER_FLOOR_FOREVER = 10	; min adjacent, permanent
ACT_OPEN_DOOR_10S = 11		; raise ceil +5, reclose 10s
ACT_LOWER_FLOOR_15S = 12	; min adjacent + return 15s
ACT_DAMAGE_FLOOR = 13		; 5 HP / second while standing
ACT_FLASH_LIGHTS = 14		; SEC_BRIGHT ??? 16, 1 Hz (max 2 sectors)
ACT_OPEN_MONSTER_CLOSET = 15	; raise floor+ceil +6, permanent
ACT_SECRET = 16			; walk-into oneshot ??? inc secrets found

; level_item_meta: skill bits (switches use meta=0)

; Map first so level_map is 32-byte aligned ($a000) for maprowlo+mapx
level_map = level_data
; Attribute tables (index = sector id; [0] unused)
SEC_FLOOR  = level_map + MAP_CELLS
SEC_CEIL   = SEC_FLOOR + SEC_TABLE_SIZE
SEC_TYPE   = SEC_CEIL + SEC_TABLE_SIZE
SEC_TARGET = SEC_TYPE + SEC_TABLE_SIZE
SEC_FCOL   = SEC_TARGET + SEC_TABLE_SIZE
SEC_CCOL   = SEC_FCOL + SEC_TABLE_SIZE
SEC_BRIGHT = SEC_CCOL + SEC_TABLE_SIZE

level_spawn = SEC_BRIGHT + SEC_TABLE_SIZE	; x, y, angle (playera)
; Items SoA (contiguous)
level_item_type = level_spawn + SPAWN_BYTES	; 48: typeId or $FF empty
level_item_x = level_item_type + MAX_ITEMS
level_item_y = level_item_x + MAX_ITEMS
level_item_meta = level_item_y + MAX_ITEMS	; skill bits
level_items = level_item_type

; Cooked switch faces: count + switch-sector id + solid NESW face (0..3)
level_switch_n = level_item_meta + MAX_ITEMS
level_switch_sec = level_switch_n + 1
level_switch_dir = level_switch_sec + MAX_SWITCH_FACES
SWITCH_FACE_N = level_switch_n
SWITCH_FACE_SEC = level_switch_sec
SWITCH_FACE_DIR = level_switch_dir

level_sector_max = level_switch_dir + MAX_SWITCH_FACES
level_num_enemies = level_sector_max + 1
level_num_items = level_num_enemies + 1
level_num_secrets = level_num_items + 1
level_par_time = level_num_secrets + 1
!if level_par_time + 1 - level_data != LEVEL_BYTES {
	!error "LEVEL_BYTES mismatch vs layout"
}

!source "tables.asm"
!source "sky.asm"
!source "recip.asm"
!source "item_bitmaps.asm"
!source "pcsfreq.asm"			; high scrap (keeps kernal blob ??? $F950..$FFFF)

!zone 0

end_high = *
free_high = PY_TAB - end_high
!if free_high < 0 {
	!error "High data overlaps py_tab at $", PY_TAB, "; overshoot=", end_high - PY_TAB
}
!warn "mem: high end=$", end_high, " free to py_tab $", PY_TAB, " =", free_high

; py_tab packed against SQTAB ($bc00???$c7ff)
*=PY_TAB
!source "pytab.asm"
!if * != MEM_HIGH_LIMIT {
	!error "py_tab must end at $c800; ended at $", *
}

!if SEC_WDARK_END > $10000 {
	!error "Under-KERNAL BSS past $10000; SEC_WDARK_END=$", SEC_WDARK_END
}
!if MENU_LIMIT > $fffa {
	!error "MENU_LIMIT past vectors; COL_CLIP_END=$", COL_CLIP_END
}

; dpsounds + levelstats: load image in SQTAB slot ($c800); warmstart copies to
; kernal scrap ($F950+) before init_sqtabs rebuilds SQTAB over the blob.
; Assembled with runtime addresses via !pseudopc (PRG must not span $d000 I/O).
*=MEM_HIGH_LIMIT
kernal_blob
!pseudopc SEC_WDARK_END {
	!source "dpsounds.asm"
	!source "levelstats.asm"
end_kernal = *
}
kernal_blob_end = *
KERNAL_BLOB_SIZE = kernal_blob_end - kernal_blob
!if KERNAL_BLOB_SIZE > $800 {
	!error "kernal blob exceeds SQTAB slot; size=", KERNAL_BLOB_SIZE
}
!if end_kernal < SEC_WDARK_END {
	!error "Kernal scrap wrapped past $FFFF; end=$", end_kernal
}
!if end_kernal > $fffa {
	!error "Kernal scrap overlaps hardware vectors ($FFFA+); end=$", end_kernal
}
!if CASS_LEVELSTATS_END > CASS_BUF_END {
	!error "cassette BSS overflow"
}
free_kernal = $fffa - end_kernal	; bytes free before hardware vectors
; Play buffers $e000..COL_CLIP_END-1; MENU.PRG at MENU_BASE..MENU_LIMIT-1
free_menu = MENU_LIMIT - MENU_BASE	; MENU.PRG size budget
free_total = free_low + free_mid + free_high + free_kernal
!warn "mem: kernal data $", SEC_WDARK_END, "..$", end_kernal - 1, " free before $FFFA =", free_kernal, " MENU budget =", free_menu
!warn "mem: TOTAL free =", free_total, " (low+mid+high+kernal-scrap)"
!warn "mem: SID  $", SID_BASE, "..$", SID_BASE + SID_SIZE - 1, " (4K music window)"

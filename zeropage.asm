!zone zeropage

; World 8.8 (1.0 = 1 world unit; 8 units = 1 tile)
playerx		= $02			; frac
playerx_h	= $03			; world X 0..255
playery		= $04
playery_h	= $05			; world Y 0..255
playera		= $06
eyeheight	= $07

col		= $08
angle		= $09
clip_n		= $0a			; cast_column: clip stack byte offset (n×4)
item_sin	= $0b			; render_items: sintab[playera] (hoisted once/frame)
; $0b was dyindex (unused after rebuild_col_rays X/Y split)
xstep		= $0c
ystep		= $0d

; 16-bit TheKeep dd (fixsec); sdx/sdy 16-bit
; After column cast, ddx_* reused as item U-DDA accumulator (item_u).
ddx_l		= $0e
ddx_h		= $0f
item_u_l	= ddx_l			; enemy column U-DDA (8.8); bmp_x = item_u_h
item_u_h	= ddx_h
ddy_l		= $10
ddy_h		= $11
sdx_l		= $12
sdx_h		= $13
sdy_l		= $14
sdy_h		= $15

mapx		= $16
mapy		= $17
side		= $18
ytop		= $19
ybot		= $1a
cur_id		= $1b
next_id		= $1c

wallz_l		= $1d
wallz_h		= $1e
texstep_l	= $1f
texstep_h	= $20
acc_l		= $21
acc_h		= $22

tmp0		= $23
tmp1		= $24
tmp2		= $25
tmp3		= $26
tmp4		= $27
tmp5		= $28
ptr_l		= $29
ptr_h		= $2a
scr_ptr		= ptr_l			; Deathchase-style alias ($0400 cell)

near_floor	= $2b
near_ceil	= $2c
far_floor	= $2d
far_ceil	= $2e
near_fcol	= $2f
near_ccol	= $30
wall_col	= $31
turn		= $32

; Judd/Arndt square-table pointers (lo set per mul_8x8; hi set in init)
sq1_l		= $33
sq1_h		= $34
sq2_l		= $35
sq2_h		= $36
sq3_l		= $37
sq3_h		= $38
sq4_l		= $39
sq4_h		= $3a

aux_l		= $3b
aux_h		= $3c
col_ptr		= aux_l			; Deathchase-style alias ($d800 cell)
rcr_abase	= $3d			; rebuild_col_rays: playera − 64 (north-aligned base)

fracx		= $3e
fracy		= $3f
item_dx		= fracy			; render_items geometry phase: signed world dx
item_mip	= fracy			; render_items setup phase: selected mip index
item_vshift	= fracy			; render_items column phase: log2(mip height)
span_a		= $40
span_b		= $41
fill_row	= $42
py_row		= $43

; Walk wish 8.8 (dt-scaled); save_* = pre-move XY for collision resolve
wish_x_l	= $44
wish_x_h	= $45
wish_y_l	= $46
wish_y_h	= $47
save_xl		= $48
save_xh		= $49
old_floor	= $7a			; SEC_FLOOR at move start (step-up / portal gate)
item_cos	= $7b			; render_items: costab[playera] (hoisted once/frame)
old_ceil	= $ae			; SEC_CEIL at move start (portal clearance)

; Status bar (drawn into FB row 24 when hud_dirty; blit copies it)
health		= $7c
armor		= $7d
keys		= $7e			; bit0=red bit1=yellow bit2=blue
hud_dirty	= $a8			; redraw HUD sides into FB; blit clears after HUD cols
key_use		= $7f			; 1 = K held (use / open door)
key_fire	= $84			; 1 = I held (shoot)
muzzle_ms_l	= $80			; muzzle flash ms remaining (16-bit)
muzzle_ms_h	= $81
random8		= $82			; GetRandom8 state (Deathchase LCG)
spr_en		= $83			; mirror of $d015 (write-only)
fire_rpt_l	= $85			; ms until next shot while held
fire_rpt_h	= $86

; Info line (top row, 4s); info_len = cols to reserve (ytop=1)
; info_kind (BSS in pickup.asm): 0 = pickup prefix+name, 1 = raw string
info_ms_l	= $87
info_ms_h	= $88
info_len	= $89			; 0 = no message
info_name_l	= $8a			; ptr to name/raw string (screen codes, 0-term)
info_name_h	= $8b
has_backpack	= $8c			; 1 after backpack pickup

; CIA1 Timer A input sampler (~20 binary-ms @ 50 Hz); IRQ bumps, main snapshots under SEI
in_turn_l	= $8d			; J held ms this frame
in_turn_r	= $8e			; L held ms
in_fwd		= $8f			; W
; $90–$AF / $B7–$BC — KERNAL-owned during OPEN/LOAD (ST…EAL, SETNAM/SETLFS).
; LoadPrg pre-clears $90–$98 (stray ST bit6/7 aborts LOAD; LDTND≥$0A kills OPEN).
; Do not place anything that must survive LOAD here. Survivors → $FB+.
; $99–$AE ok only under $01=$35 after load (re-inited / transient).
sky_col_base	= $97			; (playera*5/8) mod 40; rebuilt with column rays
seen_gen	= $98			; re-inited after level load; SEC_SEEN generation stamp
in_wpn_pistol	= $99			; OR-latch: 2 held
in_wpn_shotgun	= $9a			; OR-latch: 3 held
key_wpn_pistol	= $9b
key_wpn_shotgun	= $9c
; Menu/UI string pointer (re-set after UI load; clobbered during LOAD)
ui_str_l	= $9d
ui_str_h	= $9e
; Input hold times — clobbered during LOAD; fine after input_irq_init
in_back		= $a2			; S (also jiffy lo while KERNAL IRQ owns machine)
in_strafel	= $a3			; A
in_strafer	= $a4			; D
in_use		= $a5			; OR-latch: K held any sample
in_fire		= $a6			; OR-latch: I held any sample
vel_ms		= $a7			; hold-ms fed to turn_deliver / scale_vel
; SFX playback pointer (IRQ-safe; not shared with render temps)
sound_ptr_l	= $a9
sound_ptr_h	= $aa
wpn_fire_ms_l	= $ab
wpn_fire_ms_h	= $ac
near_fpat	= $ad			; floor/ceil dither screen code for paint_near

; KERNAL-safe survivors ($FB–$FE; unused by IEC/LOAD)
cur_weapon	= $fb			; 0=fist 1=chainsaw 2=pistol 3=shotgun 4=minigun 5=rocket
ui_buf_id	= $fc			; asset in SCREENBUFFER; $ff = unknown/none
sky_ptr_l	= $fd			; sky_cols + sky_col*12 for this screen column
sky_ptr_h	= $fe

; Base of current column in transposed SCREENBUFFER (25 bytes)
col_base_l	= $4a
col_base_h	= $4b
; Matching column base in PATTERNBUFFER (= SCREENBUFFER+$400)
pat_base_l	= $76
pat_base_h	= $77
fill_pat	= $78			; screen code written with colour fills
wall_pat	= $79			; min(15, wallz_h) for wall strips
wall_u		= $9f			; face U 0..255 (calc_wall_u; door jambs / switch)

dda_steps	= $4c			; DDA spill; item draw: mirror flag (item_mirror)
item_mirror	= dda_steps		; nonzero → flip bmp_x this sprite
item_ybot	= $4d			; item draw: exclusive bottom of clipped column span
						; (was xsgn; free after SMC ±X tile advance)

; CIA profiler snap
prof_snap_l	= $4e
prof_snap_h	= $4f

; TheKeep-style marching pointer into level_map
; After column cast, tile_* reused as hoisted enemy mip base (pre bmp_x).
tile_l		= $50
tile_h		= $51
item_mip_base_l	= tile_l
item_mip_base_h	= tile_h

; Profiler scratch — must NOT share tmp0..tmp5 (paint_portal keeps
; live values in tmp4/tmp5 across project_y calls).
prof_now_l	= $52
prof_now_h	= $53
prof_dt_l	= $54
prof_dt_h	= $55

; Player tile/frac cached once per frame (columns restore mapx/mapy from these)
plr_mapx	= $56
plr_mapy	= $57
plr_id		= $58
plr_tile_l	= $59
plr_tile_h	= $5a
fracx_inv	= $5d			; fracx ^ $FF (TheKeep +X/+Y distance factor)
fracy_inv	= $5e
last_playera	= $5f			; $FF = force rebuild_col_rays

; COL_CLIP_ENTRIES + col*CLIP_COL_BYTES — set once per column (reset / bind)
clip_base_l	= $5b
clip_base_h	= $5c

!if DBG_PORTAL = 1 {
dbg_n		= $a0			; # portal dump lines this frame (0..24)
dbg_far_y	= $a1			; raw project_y(far_floor); $FF if none
}

; Same-flat paint_near skip (per column) + fill_span ends + frame span count
; last_near_flatgrp: SEC_FLATGRP of last paint_near. Aliased last_near_* below
; are item-draw scratch after columns (must not overlap during cast_column).
last_near_flatgrp = $60
last_near_floor	= $60			; item scratch (alias; after all columns)
last_near_ceil	= $61			; item scratch
last_near_fcol	= $62			; item scratch
last_near_ccol	= $63			; item scratch
last_near_ok	= $64			; 0 = no flats cached this column
span_lo		= $65			; fill_span count (PROFILE=1 only)
span_hi		= $66
fill_y0		= $67			; fill_span start (inclusive)
fill_y1		= $68			; fill_span end (exclusive)

; Incremental fish-scaled distance (wz += dd*w each DDA step)
wz_x_l		= $69
wz_x_h		= $6a
wz_y_l		= $6b
wz_y_h		= $6c
ddwx_l		= $6d			; mid(ddx * fish)
ddwx_h		= $6e
ddwy_l		= $6f
ddwy_h		= $70

; Frame-time move/turn (binary ms: dt = frame_cy >> 10)
save_yl		= $71
save_yh		= $72
dt_ms		= $73			; last frame period ≈ ms, 1..255
turn_acc_l	= $74			; angle×1024 remainder
turn_acc_h	= $75

; ------------------------------------------------------------------
; Under-KERNAL / always-RAM play BSS ($01=$35 for $E000+)
; Judd SQTAB at $c800 (always RAM; former screen-buffer slot).
; SID music window at $9000–$9fff (4K), flush against level at $a000.
; SidTracker player ZP (kept via sidreloc -k): $f0–$f7.
; Contiguous play buffers at $e000 (menu overlay = buffers after UI_LOAD_MAX):
;   SCREENBUFFER $e000, PATTERNBUFFER $e400, COL_CLIP, then COL rays / rest
; dpsounds/levelstats run from SEC_WDARK_END (copied from $c800 load image).
; ------------------------------------------------------------------
SQTAB1		= $c800
SQTAB2		= $c800 + $200
SQTAB3		= $c800 + $400
SQTAB4		= $c800 + $600

; Per-column portal clip stack — packed after PATTERNBUFFER
CLIP_MAX	= 14				; measured peak through E1; push silently drops when full
CLIP_ENTRY	= 4
CLIP_COL_BYTES	= CLIP_MAX * CLIP_ENTRY	; 56 — whole column Y-reachable from clip_base
COL_NUM		= 40
COL_CLIP_N	= PATTERNBUFFER + $400	; $e800 — 40 bytes: entry count per column
COL_CLIP_ENTRIES = COL_CLIP_N + COL_NUM	; 40 × CLIP_COL_BYTES interleaved stack
COL_CLIP_END	= COL_CLIP_ENTRIES + COL_NUM * CLIP_COL_BYTES

; MENU.PRG: UI loads clobber SCREENBUFFER[0..UI_LOAD_MAX); code starts after
MENU_BASE	= SCREENBUFFER + UI_LOAD_MAX
MENU_LIMIT	= COL_CLIP_END
run_menu	= MENU_BASE		; jmp stub → run_menu_body
show_text_screen = MENU_BASE + 3	; jmp stub → show_text_screen_body

; Per-column ray cache (rebuilt when playera changes), 10×40 = 400 bytes
COL_DDX_L	= COL_CLIP_END
COL_DDX_H	= COL_DDX_L + COL_NUM
COL_DDY_L	= COL_DDX_H + COL_NUM
COL_DDY_H	= COL_DDY_L + COL_NUM
COL_XSTEP	= COL_DDY_H + COL_NUM
COL_YSTEP	= COL_XSTEP + COL_NUM
; mid(ddx/ddy * fish) — fish is per-column fixed
COL_DDWX_L	= COL_YSTEP + COL_NUM
COL_DDWX_H	= COL_DDWX_L + COL_NUM
COL_DDWY_L	= COL_DDWX_H + COL_NUM
COL_DDWY_H	= COL_DDWY_L + COL_NUM
COL_END		= COL_DDWY_H + COL_NUM	; first byte after ray cache

PROF_BSS	= COL_END		; CIA cascade / PROFILE buckets (must be ≥ COL_END)
PROF_BSS_SIZE	= $27			; 7×3 buckets + frame/cascade + py counters
PROF_END	= PROF_BSS + PROF_BSS_SIZE

; Door / sector processes (SoA, max 8)
PROC_NUM	= 8
PROC_FREE	= 0
PROC_TIMER	= 1
PROC_RAISE_CEIL	= 2
PROC_LOWER_CEIL	= 3
PROC_RAISE_FLOOR = 4
PROC_LOWER_FLOOR = 5

PROC_KIND	= PROF_END		; 0 = free
PROC_A		= PROC_KIND + PROC_NUM	; sector id
PROC_B		= PROC_A + PROC_NUM	; target height / next kind
PROC_C		= PROC_B + PROC_NUM	; timer/accum lo
PROC_D		= PROC_C + PROC_NUM	; timer/accum hi
PROC_E		= PROC_D + PROC_NUM	; return height when timer → RAISE/LOWER_FLOOR
PROC_END	= PROC_E + PROC_NUM

; Per-frame sector visibility (entry == seen_gen means seen this frame)
SEC_SEEN	= PROC_END		; SEC_TABLE_SIZE bytes, index = sector id
SEC_SEEN_END	= SEC_SEEN + SEC_TABLE_SIZE

; Item render sort + collect cache (index = sort slot 0..n-1)
; Cache avoids redoing map_sector_id + item_calc_depth in item_draw_one.
ITEM_SORT_DEPTH	= SEC_SEEN_END		; 48 bytes depth (8-bit)
ITEM_SORT_SLOT	= ITEM_SORT_DEPTH + 48
ITEM_SORT_SEC	= ITEM_SORT_SLOT + 48	; sector id
ITEM_SORT_DX	= ITEM_SORT_SEC + 48	; fracy = dx (signed)
ITEM_SORT_DY	= ITEM_SORT_DX + 48	; fracx = dy (signed)
ITEM_SORT_WZ_L	= ITEM_SORT_DY + 48	; depth16 lo (512/tile)
ITEM_SORT_WZ_H	= ITEM_SORT_WZ_L + 48	; depth16 hi
ITEM_SORT_END	= ITEM_SORT_WZ_H + 48

; Enemy mobj SoA (VicDoom-style; index 0..MAX_MOBJ-1; last two = missiles)
MAX_MOBJ		= 32
MOBJ_PLAYER_ROCKET = MAX_MOBJ - 2
MOBJ_MISSILE	= MAX_MOBJ - 1
ITEM_PLAYER_ROCKET = 46		; reserved (= MAX_ITEMS-2)
ITEM_MISSILE	= 47			; reserved last item slot (= MAX_ITEMS-1)

MOBJ_ALLOC	= ITEM_SORT_END		; 21
MOBJ_MOVEDIR	= MOBJ_ALLOC + MAX_MOBJ
MOBJ_FLAGS	= MOBJ_MOVEDIR + MAX_MOBJ
MOBJ_REACT	= MOBJ_FLAGS + MAX_MOBJ
MOBJ_MOVECNT	= MOBJ_REACT + MAX_MOBJ
MOBJ_HEALTH	= MOBJ_MOVECNT + MAX_MOBJ
MOBJ_INFO	= MOBJ_HEALTH + MAX_MOBJ	; 0=pos..4=baron, 5=impshot
MOBJ_STATE	= MOBJ_INFO + MAX_MOBJ
MOBJ_XFRAC	= MOBJ_STATE + MAX_MOBJ
MOBJ_YFRAC	= MOBJ_XFRAC + MAX_MOBJ
MOBJ_OBJ	= MOBJ_YFRAC + MAX_MOBJ	; item slot for this mobj
MOBJ_FOR_ITEM	= MOBJ_OBJ + MAX_MOBJ	; 48: mobj idx or $FF
ITEM_CORPSE_TEX	= MOBJ_FOR_ITEM + 48	; 48: $FF live, else enemy spr idx
; Per-column aim (filled far→near during item draw; nearer overwrites)
COL_AIM_SLOT	= ITEM_CORPSE_TEX + 48	; 40: item slot or $FF empty
COL_AIM_Z	= COL_AIM_SLOT + COL_NUM	; 40: depth (wallz_h) for melee range
aim_item	= COL_AIM_Z + COL_NUM	; current billboard slot for aim ($FF none)
MOBJ_END	= aim_item + 1

; Per-sector flat group id (identical floor/ceil/fcol/ccol → same id)
SEC_FLATGRP	= MOBJ_END		; SEC_TABLE_SIZE bytes, index = sector id
SEC_FLATGRP_END	= SEC_FLATGRP + SEC_TABLE_SIZE

; Persistent automap fog: ever marked by mark_seen this level
SEC_VISITED	= SEC_FLATGRP_END	; SEC_TABLE_SIZE bytes, index = sector id
SEC_VISITED_END	= SEC_VISITED + SEC_TABLE_SIZE

; SidTracker music player ZP (sidreloc -k keeps these; do not reuse)
music_zp0	= $f0
music_zp1	= $f1
music_zp2	= $f2
music_zp3	= $f3
music_zp4	= $f4
music_zp5	= $f5
music_zp6	= $f6
music_zp7	= $f7
; Music filter/volume shadows (prepare_music redirects STA $D417/$D418 here)
; Defined in playsound.asm: sid_filt_shadow=$02f8 sid_vol_shadow=$02f9
; (kept off $0314–$0333 KERNAL soft-vector page)

sg_cock_ms_l	= $b0			; shotgun cock animation ms remaining (lo)
sg_cock_ms_h	= $b1			; shotgun cock animation ms remaining (hi)

; Per-sector wall darken for set_wall_pat (from SEC_BRIGHT; $FF = full bright)
SEC_WDARK	= SEC_VISITED_END	; SEC_TABLE_SIZE bytes, index = sector id
SEC_WDARK_END	= SEC_WDARK + SEC_TABLE_SIZE
; Switch faces are cooked into level_data (level_switch_*) — not BSS.

; ---------------------------------------------------------------------------
; Uninitialized scrap (not in PRG). Stack keeps $01A0..$01FF (~96 bytes).
; Cassette buffer is free while KERNAL is out ($01=$35).
; ---------------------------------------------------------------------------
UNDER_STACK	= $0100
UNDER_STACK_END	= $01a0
CASS_BUF	= $033c
CASS_BUF_END	= $03fc

; Level-stats counters / roll-in temps (zeroed by init_level_stats)
num_kills	= CASS_BUF
num_items_got	= CASS_BUF + 1
num_secrets_got	= CASS_BUF + 2
map_time_ms	= CASS_BUF + 3		; 2 bytes
map_time_sec	= CASS_BUF + 5		; 2 bytes
roll_target	= CASS_BUF + 7
roll_cur	= CASS_BUF + 8		; 2 bytes
roll_time_l	= CASS_BUF + 10
roll_time_h	= CASS_BUF + 11
roll_row	= CASS_BUF + 12		; row for active roll_in (not shared pr_row)
CASS_LEVELSTATS_END = CASS_BUF + 13
!if CASS_LEVELSTATS_END > CASS_BUF_END {
	!error "levelstats BSS past cassette buffer"
}

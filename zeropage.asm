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
dxindex		= $0a
dyindex		= $0b
xstep		= $0c
ystep		= $0d

; 16-bit TheKeep dd (fixsec); sdx/sdy 16-bit
ddx_l		= $0e
ddx_h		= $0f
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
mul_fac		= $3d

fracx		= $3e
fracy		= $3f
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
old_floor	= $7a			; SEC_FLOOR at move start (step-up gate)

; Status bar (drawn post-blit on row 24)
ammo		= $7b			; 0–255, shown as 3 digits
health		= $7c
armor		= $7d
keys		= $7e			; bit0=red bit1=yellow bit2=blue
key_use		= $7f			; 1 = K held (use / open door)

; Base of current column in transposed framebuffer (25 bytes)
col_base_l	= $4a
col_base_h	= $4b
; Matching column base in LIGHTFRAME ($CC00 = FRAMEBUFFER+$400)
pat_base_l	= $76
pat_base_h	= $77
fill_pat	= $78			; screen code written with colour fills
wall_pat	= $79			; min(7, wallz_h) for wall strips

dda_steps	= $4c
dda_peak	= $4d

; CIA profiler snap
prof_snap_l	= $4e
prof_snap_h	= $4f

; TheKeep-style marching pointer into level_map
tile_l		= $50
tile_h		= $51

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

!if DBG_PORTAL = 1 {
dbg_n		= $5b			; # portal dump lines this frame (0..24)
dbg_far_y	= $5c			; raw project_y(far_floor); $FF if none
}

; Same-flat paint_near skip (per column) + fill_span ends + frame span count
last_near_floor	= $60
last_near_ceil	= $61
last_near_fcol	= $62
last_near_ccol	= $63
last_near_ok	= $64			; 0 = no flats cached this column
span_lo		= $65
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

; Under-KERNAL RAM ($01=$35): runtime tables / BSS (not in PRG image)
; Judd square tabs $e000–$e7ff; COL ray cache; profiler BSS
SQTAB1		= $e000
SQTAB2		= $e200
SQTAB3		= $e400
SQTAB4		= $e600

; Per-column ray cache (rebuilt when playera changes), 10×40 = 400 bytes
COL_NUM		= 40
COL_DDX_L	= $e800
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
PROF_BSS_SIZE	= $20			; reserved (PROFILE=0/1 scratch)
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
PROC_END	= PROC_D + PROC_NUM

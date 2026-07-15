!zone zeropage

; World-byte position (1 unit = 1/8 tile). Lows unused / kept 0.
playerx		= $02			; unused (was 8.8 frac)
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

; Walk deltas (signed) added into world-byte player*_h
wish_x		= $44
wish_y		= $45
save_xh		= $47
save_yh		= $49

; Base of current column in transposed framebuffer (25 bytes)
col_base_l	= $4a
col_base_h	= $4b

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

; Per-column ray cache (rebuilt when playera changes). $2f00–$2fef
COL_DDX_L	= $2f00
COL_DDX_H	= $2f28
COL_DDY_L	= $2f50
COL_DDY_H	= $2f78
COL_XSTEP	= $2fa0
COL_YSTEP	= $2fc8
; mid(ddx/ddy * fish) — fish is per-column fixed
COL_DDWX_L	= $3000
COL_DDWX_H	= $3028
COL_DDWY_L	= $3050
COL_DDWY_H	= $3078

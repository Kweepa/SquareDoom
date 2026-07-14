!zone zeropage

playerx		= $02
playerx_h	= $03
playery		= $04
playery_h	= $05
playera		= $06
eyeheight	= $07

col		= $08
angle		= $09
dxindex		= $0a
dyindex		= $0b
xstep		= $0c
ystep		= $0d

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

; This-frame walk deltas (signed 8-bit, added into 8.8 player pos)
wish_x		= $44
wish_y		= $45
save_xl		= $46
save_xh		= $47
save_yl		= $48
save_yh		= $49

; Base of current column in transposed framebuffer (25 bytes)
col_base_l	= $4a
col_base_h	= $4b

dda_steps	= $4c
dda_peak	= $4d

; CIA profiler snap
prof_snap_l	= $4e
prof_snap_h	= $4f

; Keep-style marching pointer into level_map
tile_l		= $50
tile_h		= $51

; Profiler scratch — must NOT share tmp0..tmp5 (paint_portal keeps
; live values in tmp4/tmp5 across project_y calls).
prof_now_l	= $52
prof_now_h	= $53
prof_dt_l	= $54
prof_dt_h	= $55

!if DBG_PORTAL = 1 {
dbg_n		= $56			; # portal dump lines this frame (0..24)
dbg_far_y	= $57			; raw project_y(far_floor); $FF if none
}

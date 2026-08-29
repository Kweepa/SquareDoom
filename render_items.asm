!zone render_items

; ============================================================================
; render_items.asm — billboard items into SCREENBUFFER after column cast
; ============================================================================
; Collect items in seen sectors, depth-sort far→near, project, draw clipped
; against COL_CLIP_* stack (open=depth·$ff; occ=(depth·$ff)>>3).
; Column-major item mips (byte colour, $ff=clear).
; Live enemies stamp COL_AIM_SLOT/Z per column (nearer overwrites).
; ============================================================================

ITEM_DEPTH_MIN = 1			; editor uses ~0.8 world units
ITEM_AXIS_MAX = 120			; cull if |dx| or |dy| > 15 tiles (8-bit safe)
ITEM_GATHER_HALF = 8			; 16×16 AABB
ITEM_TYPE_ENEMY_LO = 1
ITEM_TYPE_ENEMY_HI = 5
ITEM_TYPE_EMPTY = $ff
ITEM_TYPE_SPAWN = 0
ITEM_TYPE_BARREL = 6
ITEM_TYPE_SWITCH = 27
ITEM_TYPE_FIREBALL = 28
ITEM_TYPE_PLASMABALL = 29
ITEM_TYPE_ROCKET = 30
ITEM_TYPE_EXPLOSION = 31
ITEM_TYPE_POSCORPSE = 21
TEX_ANIMATE = 64

; Scratch after column loop (column temps free):
;   item_slot = current billboard item index (not ZP — once per item)
;   wall_col = typeId
;   wallz_h = item depth (8-bit); wz_y = depth16 → clip want16 in wz_x
;   near_floor / near_ceil = floor height / sector
;   far_ceil = sprite H; last_near_ok = sprite W
;   near_fcol = unclamped sprite top (V map; fill_y0 may be clamped)
;   last_near_fcol = screen centre col
;   last_near_ccol = sort index / draw scratch
;   span_a = visible count during collect/sort
;   item_sin/cos = playera trig (once/frame); ITEM_SORT_* cache per visible
;   item_u / wish_x(ustep) / item_mip_base / item_mirror — enemy column DDA

; Current vis index during collect/draw (keep off ZP; turn $32 is player yaw)
; item_slot — cassette scrap BSS (zeropage.asm)

; ---------------------------------------------------------------------------
; render_items
; ---------------------------------------------------------------------------
render_items
!if PROFILE = 1 {
	jsr prof_snap
}
	; playera fixed for the whole pass — hoist sin/cos once
	ldy playera
	lda sintab,y
	sta item_sin
	lda costab,y
	sta item_cos
	; Clear per-column aim ($FF = no live enemy this frame)
	ldx #COL_NUM-1
	lda #$ff
.ri_clr_aim
	sta COL_AIM_SLOT,x
	dex
	bpl .ri_clr_aim
	lda #0
	sta span_a
	jsr items_cull_near
	jsr items_cull_mobjs
	jsr items_cull_fx
	lda span_a
	beq .ri_done
	sta fill_row			; preserve count (item_draw_one reuses span_*)
	jsr item_sort_depth
	lda #0
	sta last_near_ccol
.ri_dlp
	lda last_near_ccol
	cmp fill_row
	bcs .ri_done
	jsr item_draw_one
	inc last_near_ccol
	jmp .ri_dlp
.ri_done
!if PROFILE = 1 {
	ldy #PROF_ITEMS
	jmp prof_add_bucket
}
	rts

; A = signed sintab/costab (−64..64) → (A*7)>>6 tile steps (−7..7)
item_dir_tiles
	sta tmp2
	bpl .idt_pos
	eor #$ff
	clc
	adc #1
.idt_pos
	sta tmp3
	lda #0
	sta tmp1
	lda tmp3
	sta tmp0
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1
	asl tmp0
	rol tmp1			; *8
	sec
	lda tmp0
	sbc tmp3
	sta tmp0
	lda tmp1
	sbc #0
	sta tmp1			; *7
	ldx #6
.idt_lsr
	lsr tmp1
	ror tmp0
	dex
	bne .idt_lsr
	lda tmp0
	bit tmp2
	bpl .idt_out
	eor #$ff
	clc
	adc #1
.idt_out
	rts

item_clamp31
	bmi .ic31_0
	cmp #MAP_SIZE
	bcc .ic31_ok
	lda #MAP_SIZE-1
.ic31_ok
	rts
.ic31_0
	lda #0
	rts

; AABB around player + 7 tiles forward (fwd = sin, −cos)
items_cull_near
	lda playerx_h
	lsr
	lsr
	lsr
	sta tmp4
	ldy playera
	lda sintab,y
	jsr item_dir_tiles
	clc
	adc tmp4
	jsr item_clamp31
	sta tmp4				; cx
	lda playery_h
	lsr
	lsr
	lsr
	sta tmp5
	ldy playera
	lda costab,y
	jsr neg_a
	jsr item_dir_tiles
	clc
	adc tmp5
	jsr item_clamp31
	sta tmp5				; cy
	lda tmp4
	sec
	sbc #ITEM_GATHER_HALF
	jsr item_clamp31
	sta last_near_ok			; x0
	lda tmp4
	clc
	adc #ITEM_GATHER_HALF - 1
	jsr item_clamp31
	sta far_ceil				; x1
	lda tmp5
	sec
	sbc #ITEM_GATHER_HALF
	jsr item_clamp31
	sta last_near_fcol			; y0
	lda tmp5
	clc
	adc #ITEM_GATHER_HALF - 1
	jsr item_clamp31
	sta last_near_ccol			; y1
	lda last_near_fcol
	sta mapy
.icn_y
	lda last_near_ok
	sta mapx
.icn_x
	jsr item_layer_id
	beq .icn_nx
	sta wall_col
	jsr item_tile_xy
	jsr map_sector_id
	sta near_ceil
	lda mapx
	ora #VIS_LAYER
	sta item_slot
	lda mapy
	sta span_b				; ty for ITEM_SORT_SEC
	jsr item_vis_push
.icn_nx
	lda span_a
	cmp #MAX_ITEMS
	bcs .icn_done
	lda mapx
	cmp far_ceil
	bcs .icn_yn
	inc mapx
	jmp .icn_x
.icn_yn
	lda mapy
	cmp last_near_ccol
	bcs .icn_done
	inc mapy
	jmp .icn_y
.icn_done
	rts

items_cull_mobjs
	ldx #0
.icm_lp
	lda MOBJ_ALLOC,x
	beq .icm_nx
	stx item_slot
	lda MOBJ_X,x
	sta tmp0
	lda MOBJ_Y,x
	sta tmp1
	jsr vis_mobj_type
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	stx fill_y0
	jsr map_sector_id
	sta near_ceil
	sta span_b
	jsr item_vis_push
	ldx fill_y0
.icm_nx
	inx
	cpx #MAX_MOBJ
	bcc .icm_lp
	rts

; X = mobj → wall_col
vis_mobj_type
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .vmt_proj
	clc
	adc #1
	sta wall_col
	lda ITEM_CORPSE_TEX,x
	cmp #$ff
	beq .vmt_rts
	cmp #ITEM_TYPE_POSCORPSE		; 21 — defined in pickup? use 21
	bcc .vmt_rts
	sta wall_col
.vmt_rts
	rts
.vmt_proj
	cpx #MOBJ_PLAYER_ROCKET
	beq .vmt_rok
	lda MOBJ_FLAGS,x
	and #MF_PLASMA
	bne .vmt_pl
	lda #ITEM_TYPE_FIREBALL
	sta wall_col
	rts
.vmt_pl
	lda #ITEM_TYPE_PLASMABALL
	sta wall_col
	rts
.vmt_rok
	lda #ITEM_TYPE_ROCKET
	sta wall_col
	rts

items_cull_fx
	ldx #0
.icf_lp
	lda FX_KIND,x
	cmp #FX_EXPL
	bne .icf_nx
	lda FX_TX,x
	sta mapx
	lda FX_TY,x
	sta mapy
	txa
	ora #VIS_FX
	sta item_slot
	jsr item_tile_xy
	lda #ITEM_TYPE_EXPLOSION
	sta wall_col
	stx fill_y0
	jsr map_sector_id
	sta near_ceil
	lda mapy
	sta span_b
	jsr item_vis_push
	ldx fill_y0
.icf_nx
	inx
	cpx #FX_MAX
	bcc .icf_lp
	rts

; wall_col, tmp0/tmp1, near_ceil, item_slot, span_b=SEC ready
item_vis_push
	lda span_a
	cmp #MAX_ITEMS
	bcs .ivp_full
	jsr item_calc_depth
	bcs .ivp_full
	ldy span_a
	sta ITEM_SORT_DEPTH,y
	lda item_slot
	sta ITEM_SORT_SLOT,y
	lda span_b
	sta ITEM_SORT_SEC,y
	lda item_dx
	sta ITEM_SORT_DX,y
	lda fracx
	sta ITEM_SORT_DY,y
	lda wz_y_l
	sta ITEM_SORT_WZ_L,y
	lda wz_y_h
	sta ITEM_SORT_WZ_H,y
	iny
	sty span_a
.ivp_full
	rts

; ---------------------------------------------------------------------------
; item_calc_depth — wall_col, tmp0=ix, tmp1=iy, near_ceil=sector
; Exit: C=1 skip; C=0 A=depth (1..255)
; Also sets near_floor=floor
; Leaves item_dx=dx, fracx=dy (signed 8-bit) for item_calc_screen
; ---------------------------------------------------------------------------
item_calc_depth
	lda tmp0			; ix
	sta tmp2
	lda playerx_h
	jsr item_uabs8		; |ix-px|
	cmp #ITEM_AXIS_MAX+1
	bcc .icd_dx_ok
	jmp .icd_bad
.icd_dx_ok
	lda wall_col
	cmp #ITEM_TYPE_ROCKET
	beq .icd_rok_dx
	cmp #ITEM_TYPE_FIREBALL
	beq .icd_msl_dx
	cmp #ITEM_TYPE_PLASMABALL
	beq .icd_msl_dx
	; Items/enemies: center at n+0.5 (constant frac $80)
	lda #$80
	cmp playerx
	lda tmp0
	sbc playerx_h
	sta item_dx			; signed world dx (|dx|≤120)
	jmp .icd_dy
.icd_msl_dx
	lda MOBJ_XFRAC + MOBJ_MISSILE
	jmp .icd_dx8
.icd_rok_dx
	; dx = hi((item_x:MOBJ_XFRAC) - (playerx_h:playerx))
	lda MOBJ_XFRAC + MOBJ_PLAYER_ROCKET
.icd_dx8
	cmp playerx
	lda tmp0
	sbc playerx_h
	sta item_dx
.icd_dy
	lda tmp1			; iy
	sta tmp2
	lda playery_h
	jsr item_uabs8		; |iy-py|
	cmp #ITEM_AXIS_MAX+1
	bcc .icd_dy_ok
	jmp .icd_bad
.icd_dy_ok
	lda wall_col
	cmp #ITEM_TYPE_ROCKET
	beq .icd_rok_dy
	cmp #ITEM_TYPE_FIREBALL
	beq .icd_msl_dy
	cmp #ITEM_TYPE_PLASMABALL
	beq .icd_msl_dy
	lda #$80
	cmp playery
	lda tmp1
	sbc playery_h
	sta fracx			; dy
	jmp .icd_ang
.icd_msl_dy
	lda MOBJ_YFRAC + MOBJ_MISSILE
	jmp .icd_dy8
.icd_rok_dy
	lda MOBJ_YFRAC + MOBJ_PLAYER_ROCKET
.icd_dy8
	cmp playery
	lda tmp1
	sbc playery_h
	sta fracx
.icd_ang
	; sin/cos already in item_sin/cos (hoisted in render_items)
	lda item_sin
	sta last_near_floor		; sin (item_calc_screen / smul)
	lda item_cos
	sta last_near_ceil		; cos
	lda #0
	sta wallz_l
	sta wallz_h
	; depth = dx*sin - dy*cos
	lda item_dx
	ldy last_near_floor
	jsr smul_wz_add
	lda fracx
	ldy last_near_ceil
	jsr smul_wz_sub
	; Stash full-precision depth16 (512/tile) for the clip want — the >>6
	; below quantizes to 1/8 tile, too coarse against 16-bit wall Z.
	; wz_y is wall-cast scratch, free during item drawing.
	lda wallz_l
	sta wz_y_l
	lda wallz_h
	sta wz_y_h
	; depth16 >> 6 via <<2 take high byte (negatives rejected; ≥$4000 → 255)
	lda wallz_h
	bmi .icd_bad
	cmp #$40
	bcs .icd_clamp
	asl wallz_l
	rol
	asl wallz_l
	rol					; A = depth16 >> 6
	beq .icd_bad
	sta wallz_l
	bne .icd_ok
.icd_clamp
	lda #255
	sta wallz_l
.icd_ok
	ldx near_ceil
	lda SEC_FLOOR,x
	sta near_floor
	lda wallz_l
	clc
	rts
.icd_bad
	sec
	rts

; |tmp2 - A| → A (unsigned world distance on 0..255 map)
item_uabs8
	sta tmp3
	lda tmp2
	cmp tmp3
	bcs .iu_ge
	lda tmp3
	sec
	sbc tmp2
	rts
.iu_ge
	sbc tmp3
	rts

; ---------------------------------------------------------------------------
; item_calc_screen — after item_calc_depth; uses item_dx/fracx and cached sin/cos
; Exit: last_near_fcol = centre screen column (may be off 0..39)
; ---------------------------------------------------------------------------
item_calc_screen
	lda #0
	sta aux_l
	sta aux_h
	; lateral = dx*cos + dy*sin
	lda item_dx
	ldy last_near_ceil		; cos
	jsr smul_aux_add
	lda fracx
	ldy last_near_floor		; sin
	jsr smul_aux_add
	; signed >>6: two asr steps via cmp #$80 / ror would be 6×;
	; equivalent low byte = bits 6..13 after <<2 (works for two's-complement)
	lda aux_h
	asl aux_l
	rol
	asl aux_l
	rol					; A = lateral >> 6 (signed low byte)
	; centre col = MUZZLE_COL + lateral*32/z  (match hitscan aim; was #19)
	ldx wallz_h
	jsr mul_recip_z
	clc
	adc #MUZZLE_COL
	sta last_near_fcol
	rts

; ---------------------------------------------------------------------------
smul_wz_add
	jsr smul_8x8
	clc
	lda wallz_l
	adc tmp0
	sta wallz_l
	lda wallz_h
	adc tmp1
	sta wallz_h
	rts
smul_wz_sub
	jsr smul_8x8
	sec
	lda wallz_l
	sbc tmp0
	sta wallz_l
	lda wallz_h
	sbc tmp1
	sta wallz_h
	rts
smul_aux_add
	jsr smul_8x8
	clc
	lda aux_l
	adc tmp0
	sta aux_l
	lda aux_h
	adc tmp1
	sta aux_h
	rts

; A=sx Y=sy → tmp0:tmp1 signed product
smul_8x8
	sta tmp2
	sty tmp3
	lda #0
	sta tmp4
	lda tmp2
	bpl .sm_a
	eor #$ff
	clc
	adc #1
	sta tmp2
	inc tmp4
.sm_a
	lda tmp3
	bpl .sm_b
	eor #$ff
	clc
	adc #1
	sta tmp3
	inc tmp4
.sm_b
	ldy tmp3
	lda tmp2
	jsr mul_8x8
	stx tmp0
	sta tmp1
	lda tmp4
	and #1
	beq .sm_ok
	lda tmp0
	eor #$ff
	clc
	adc #1
	sta tmp0
	lda tmp1
	eor #$ff
	adc #0
	sta tmp1
.sm_ok
	rts

; aux_h:aux_l / A → A unsigned quot (8-bit)
udiv16x8
	sta tmp5
	beq .ud_z
	ldx #0
.ud_lp
	lda aux_h
	bne .ud_sub
	lda aux_l
	cmp tmp5
	bcc .ud_done
.ud_sub
	sec
	lda aux_l
	sbc tmp5
	sta aux_l
	lda aux_h
	sbc #0
	sta aux_h
	inx
	bne .ud_lp
	ldx #255
.ud_done
	txa
	rts
.ud_z
	lda #0
	rts

; ---------------------------------------------------------------------------
item_sort_depth
	ldx #1
.is_o
	cpx span_a
	bcc .is_go
	rts
.is_go
	lda ITEM_SORT_DEPTH,x
	sta tmp0
	lda ITEM_SORT_SLOT,x
	sta tmp1
	lda ITEM_SORT_SEC,x
	sta tmp2
	lda ITEM_SORT_DX,x
	sta tmp3
	lda ITEM_SORT_DY,x
	sta tmp4
	lda ITEM_SORT_WZ_L,x
	sta tmp5
	lda ITEM_SORT_WZ_H,x
	sta aux_l
	txa
	tay
.is_i
	dey
	lda ITEM_SORT_DEPTH,y
	cmp tmp0
	bcs .is_after
	sta ITEM_SORT_DEPTH+1,y
	lda ITEM_SORT_SLOT,y
	sta ITEM_SORT_SLOT+1,y
	lda ITEM_SORT_SEC,y
	sta ITEM_SORT_SEC+1,y
	lda ITEM_SORT_DX,y
	sta ITEM_SORT_DX+1,y
	lda ITEM_SORT_DY,y
	sta ITEM_SORT_DY+1,y
	lda ITEM_SORT_WZ_L,y
	sta ITEM_SORT_WZ_L+1,y
	lda ITEM_SORT_WZ_H,y
	sta ITEM_SORT_WZ_H+1,y
	tya
	bne .is_i
	beq .is_put
.is_after
	iny
.is_put
	lda tmp0
	sta ITEM_SORT_DEPTH,y
	lda tmp1
	sta ITEM_SORT_SLOT,y
	lda tmp2
	sta ITEM_SORT_SEC,y
	lda tmp3
	sta ITEM_SORT_DX,y
	lda tmp4
	sta ITEM_SORT_DY,y
	lda tmp5
	sta ITEM_SORT_WZ_L,y
	lda aux_l
	sta ITEM_SORT_WZ_H,y
	inx
	jmp .is_o

; ---------------------------------------------------------------------------
; item_draw_one — last_near_ccol = vis index
; Uses ITEM_SORT_* cache keyed by vis (collect already validated).
; ---------------------------------------------------------------------------
item_draw_one
	lda #$ff
	sta aim_item
	ldx last_near_ccol
	lda ITEM_SORT_DEPTH,x
	sta wallz_h
	lda ITEM_SORT_SLOT,x
	sta item_slot
	lda ITEM_SORT_DX,x
	sta item_dx
	lda ITEM_SORT_DY,x
	sta fracx
	lda ITEM_SORT_WZ_L,x
	sta wz_y_l
	lda ITEM_SORT_WZ_H,x
	sta wz_y_h
	lda item_slot
	bmi .id_hi
	tax
	jsr vis_mobj_type
	ldx last_near_ccol
	lda ITEM_SORT_SEC,x
	sta near_ceil
	jmp .id_gotsec
.id_hi
	and #$40
	bne .id_fx
	lda item_slot
	and #31
	sta mapx
	ldx last_near_ccol
	lda ITEM_SORT_SEC,x
	sta mapy
	jsr item_layer_id
	sta wall_col
	jsr map_sector_id
	sta near_ceil
	jmp .id_gotsec
.id_fx
	lda item_slot
	and #15
	tax
	lda FX_TX,x
	sta mapx
	lda FX_TY,x
	sta mapy
	lda #ITEM_TYPE_EXPLOSION
	sta wall_col
	jsr map_sector_id
	sta near_ceil
.id_gotsec
	ldx near_ceil
	lda SEC_FLOOR,x
	sta near_floor
	; sin/cos for item_calc_screen (same as collect; last_near_* reused)
	lda item_sin
	sta last_near_floor
	lda item_cos
	sta last_near_ceil
	jsr item_calc_screen
	; screen H = (64 or 128)/z via recip_hi (≈256/z) shifts
	ldx wallz_h
	lda recip_hi,x			; ~256/z
	lsr					; ~128/z
	sta tmp0
	lda wall_col
	cmp #ITEM_TYPE_ENEMY_LO
	bcc .id_half
	cmp #ITEM_TYPE_ENEMY_HI+1
	bcs .id_half
	lda tmp0				; enemies: worldH 4 × proj 32
	bpl .id_h0
.id_half
	lda tmp0
	lsr					; pickups: half-height
	bpl .id_h0
.id_h0
	cmp #1
	bcs .id_h1
	lda #1
.id_h1
	; VicDoom clamps object H at 127 — keep tall for UV when feet go
	; off-screen; only the draw span is clipped to 0..25 below.
	cmp #128
	bcc .id_h2
	lda #127
.id_h2
	sta far_ceil			; screen H (enemies; items overwrite below)
	lda item_slot
	bmi .id_w_sq
	tax
	jsr enemy_get_texture
	bcc .id_w_sq
	sta far_floor			; tex (+ TEX_ANIMATE); mip path
	lda far_ceil
	lsr				; W = H/2 (16∶32 aspect)
	bne .id_w1
	lda #1
.id_w1
	sta last_near_ok			; keep projected W (horizontal scale OK)
	jmp .id_feet
.id_w_sq
	lda #0
	sta far_floor			; 0 = item path (1:1 or stretch)
	lda wall_col
	cmp #ITEM_TYPE_EXPLOSION
	beq .id_large
	; Items: pick mip from projected size, then draw 1:1 (never >8×8)
	lda far_ceil
	ldx #0
	cmp #8
	bcs .id_item_mip			; ≥8 → mip0 (8×8)
	ldx #1
	cmp #4
	bcs .id_item_mip			; ≥4 → mip1 (4×4)
	ldx #2
	cmp #2
	bcs .id_item_mip			; ≥2 → mip2 (2×2)
	ldx #3				; else mip3 (1×1)
.id_item_mip
	stx item_mip				; selected mip index (kept through feet/span)
	lda item_mip_w,x
	sta far_ceil			; screen H = mip H
	sta last_near_ok			; screen W = mip W
	jmp .id_feet
.id_large
	; explosion: S = min(2*H, 16); mip from S; DDA stretch to S×S
	lda far_ceil
	asl					; 2H
	cmp #17
	bcc .id_large_s
	lda #16
.id_large_s
	sta far_ceil
	sta last_near_ok
	ldx #0
	cmp #8
	bcs .id_large_mip			; ≥8 → mip0
	ldx #1
	cmp #4
	bcs .id_large_mip			; ≥4 → mip1
	ldx #2
	cmp #2
	bcs .id_large_mip			; ≥2 → mip2
	ldx #3				; else mip3
.id_large_mip
	stx item_mip
	; fall through — screen W/H stay S
.id_feet
	; Feet: missiles use flight Z (hitscan-style height); else sector floor
	lda wall_col
	cmp #ITEM_TYPE_FIREBALL
	beq .id_feet_msl
	cmp #ITEM_TYPE_PLASMABALL
	beq .id_feet_msl
	cmp #ITEM_TYPE_ROCKET
	beq .id_feet_rok
	bne .id_feet_fl
.id_feet_msl
	lda missile_z
	jmp .id_feet_h
.id_feet_rok
	lda procket_z
	jmp .id_feet_h
.id_feet_fl
	lda near_floor
.id_feet_h
	sta tmp2
	lda eyeheight
	sec
	sbc tmp2
	sta tmp2				; signed (eye − feet); *32/z via recip
	ldx wallz_h
	jsr mul_recip_z
	clc
	adc #HORIZON+1			; exclusive bot: last pixel on floor row
	sta fill_y1
	sec
	sbc far_ceil			; top = bot - H (may be <0 or >24)
	sta fill_y0
	sta near_fcol			; unclamped top for V map (clip_col clobbers tmp2)
	; Slight off-screen centres OK; span tests drop fully off-FOV.
	; Behind camera is depth-rejected in item_calc_depth.
	lda last_near_fcol
	cmp #56
	bcc .id_cx_ok			; 0..55
	cmp #$f0
	bcs .id_cx_ok			; $F0..$FF ≈ -16..-1
	rts
.id_cx_ok
	; signed left = centre - W/2 ; right = left + W
	lda last_near_ok
	lsr
	sta tmp0
	lda last_near_fcol
	sec
	sbc tmp0
	sta fracx			; signed orig left (tex map)
	sta span_a			; draw left (may clamp)
	clc
	adc last_near_ok
	sta span_b			; signed right exclusive
	; frustum: skip if right <= 0 or left >= 40
	lda span_b
	beq .id_rts
	bmi .id_rts			; right <= 0
	lda span_a
	bmi .id_clamp_l			; left < 0 → clamp draw start
	cmp #40
	bcc .id_rchk			; left in 0..39
	rts				; left >= 40, fully off right
.id_clamp_l
	lda #0
	sta span_a
.id_rchk
	lda span_b
	cmp #41
	bcc .id_yclamp
	lda #40
	sta span_b
.id_yclamp
	lda span_a
	cmp span_b
	bcc .id_vspan
	rts
.id_vspan
	; Clamp draw span only — near_fcol keeps true top for UV.
	; Negative fill_y1 = sprite fully above view; must not unsigned-clamp to 25
	; (that blew 1:1 items into a full-column OOB texture walk).
	lda fill_y1
	bmi .id_rts
	lda fill_y0
	bmi .id_clamp_top
	cmp #25
	bcs .id_rts			; fully below view
	bcc .id_topok
.id_clamp_top
	lda #0
	sta fill_y0
.id_topok
	lda fill_y1
	cmp #25
	bcc .id_botok
	lda #25
	sta fill_y1
.id_botok
	lda fill_y0
	cmp fill_y1
	bcc .id_span_ok
.id_rts
	rts
.id_span_ok
	; 1:1 / item path: never draw more rows than mip H (far_ceil)
	lda far_floor
	bne .id_vok			; enemies: projected H is intentional
	lda fill_y1
	sec
	sbc fill_y0
	cmp far_ceil
	beq .id_vok
	bcc .id_vok
	rts				; span > mip H — reject bogus clamp inflate
.id_vok
	lda far_floor
	bne .id_emip
	; Item mip was selected above; last_near_ceil = mip_w (1:1 or stretch)
	ldx item_mip
	lda item_mip_w,x
	sta last_near_ceil			; mip_w (scratch for draw)
	bne .id_clp_go
.id_emip
	; Enemy mip from projected W (thresholds; U scales to mip_w)
	lda last_near_ok
	ldx #0
	cmp #13
	bcs .id_mip_got			; ≥ 13 → mip0
	ldx #1
	cmp #7
	bcs .id_mip_got			; ≥ 7 → mip1
	ldx #2
	cmp #4
	bcs .id_mip_got			; ≥ 4 → mip2
	ldx #3
	cmp #2
	bcs .id_mip_got			; ≥ 2 → mip3
	ldx #4				; else mip4
.id_mip_got
	stx item_mip
	lda enemy_mip_w,x
	sta last_near_ceil			; mip_w (scratch for draw)
.id_clp_go
item_draw_clp_go
	; Enemies / stretch items need recip[W]/recip[H]; 1:1 items skip
	lda far_floor
	beq .id_clp_item
	jmp .id_enemy_setup
.id_clp_item
	; Hoist item mip base before the shared byte becomes item_vshift below.
	lda wall_col
	asl
	asl
	clc
	adc item_mip
	tax
	lda item_mip_base_lo,x
	sta item_mip_base_l
	lda item_mip_base_hi,x
	sta item_mip_base_h
	lda wall_col
	cmp #ITEM_TYPE_EXPLOSION
	beq .id_item_stretch_setup
	jmp .id_clp_no_recip
.id_item_stretch_setup
	; Same ustep/vstep as enemies; item mip base + $ff clear in column draw
	ldx last_near_ok			; screen W (=S)
	lda recip_lo,x
	sta wish_x_l
	lda recip_hi,x
	sta wish_x_h
	ldx far_ceil				; screen H (=S)
	lda recip_lo,x
	sta wish_y_l
	lda recip_hi,x
	sta wish_y_h
	ldy last_near_ceil			; mip_w
	lda wish_x_l
	jsr mul_8x8
	sta tmp0
	ldy last_near_ceil
	lda wish_x_h
	jsr mul_8x8
	sta tmp1
	clc
	txa
	adc tmp0
	sta wish_x_l			; ustep_l
	lda tmp1
	adc #0
	sta wish_x_h			; ustep_h
	lda span_a
	sec
	sbc fracx
	sta tmp2
	beq .id_is_uz
	tay
	lda wish_x_l
	jsr mul_8x8
	stx item_u_l
	sta tmp0
	ldy tmp2
	lda wish_x_h
	jsr mul_8x8
	clc
	txa
	adc tmp0
	sta item_u_h
	jmp .id_is_uok
.id_is_uz
	sta item_u_l
	sta item_u_h
.id_is_uok
	lda #0
	sta item_mirror
	ldx item_mip
	lda item_mip_h,x
	sta wallz_l
	jsr item_vdda_texstep
	jmp .id_clp_no_recip
.id_enemy_setup
	ldx last_near_ok			; projected W
	lda recip_lo,x
	sta wish_x_l
	lda recip_hi,x
	sta wish_x_h
	ldx far_ceil				; projected H
	lda recip_lo,x
	sta wish_y_l
	lda recip_hi,x
	sta wish_y_h
	; --- once/sprite enemy hoists ---
	; ustep = mip_w * recip[W] >> 8 → wish_x (replaces recip; no more udiv)
	ldy last_near_ceil			; mip_w
	lda wish_x_l
	jsr mul_8x8
	sta tmp0				; hi(mip*rl)
	ldy last_near_ceil
	lda wish_x_h
	jsr mul_8x8
	sta tmp1				; hi(mip*rh)
	clc
	txa
	adc tmp0
	sta wish_x_l			; ustep_l
	lda tmp1
	adc #0
	sta wish_x_h			; ustep_h
	; seed item_u = (span_a - fracx) * ustep  (ox ≥ 0 after left clamp)
	lda span_a
	sec
	sbc fracx
	sta tmp2
	beq .id_u_z
	tay
	lda wish_x_l
	jsr mul_8x8
	stx item_u_l
	sta tmp0
	ldy tmp2
	lda wish_x_h
	jsr mul_8x8
	clc
	txa
	adc tmp0
	sta item_u_h
	jmp .id_u_ok
.id_u_z
	sta item_u_l
	sta item_u_h
.id_u_ok
	; mirror flag (anim_frame abs — once/sprite, not per column)
	lda #0
	sta item_mirror
	lda far_floor
	and #TEX_ANIMATE
	beq .id_mir_done
	lda anim_frame
	and #2
	beq .id_mir_done
	inc item_mirror
.id_mir_done
	; mip base pointer (frame*5+mip); per column only adds bmp_x*mip_h
	lda far_floor
	and #$bf
	sta tmp0
	asl
	asl
	clc
	adc tmp0
	clc
	adc item_mip
	tax
	lda enemy_mip_base_lo,x
	sta item_mip_base_l
	lda enemy_mip_base_hi,x
	sta item_mip_base_h
	; V texstep once; mip_h kept in wallz_l (tmp5 dies across clip_col_find)
	ldx item_mip
	lda enemy_mip_h,x
	sta wallz_l
	jsr item_vdda_texstep
.id_clp_no_recip
	; Column draw only needs log2(mip_h), not the mip index. Converting once
	; lets every column use the shared offset table instead of a shift loop.
	ldx item_mip
	lda far_floor
	beq .id_load_item_vshift
	lda enemy_mip_vshift,x
	bne .id_vshift_ready
.id_load_item_vshift
	lda item_mip_vshift,x
.id_vshift_ready
	sta item_vshift
	; Live enemy or barrel: lock aim_item (vis index) for COL_AIM stamps
	lda wall_col
	cmp #ITEM_TYPE_BARREL
	bne .id_aim_en
	lda last_near_ccol
	sta aim_item
	jmp .id_clp_start
.id_aim_en
	cmp #ITEM_TYPE_ENEMY_LO
	bcc .id_clp_start
	cmp #ITEM_TYPE_ENEMY_HI+1
	bcs .id_clp_start
	lda item_slot
	bmi .id_clp_start
	tax
	lda MOBJ_HEALTH,x
	beq .id_clp_start
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT		; exclude missiles (baron = 4 is damageable)
	bcs .id_clp_start
	lda last_near_ccol
	sta aim_item
.id_clp_start
	; want16 = depth16 · 255/512 into wz_x — stack Z ≈ 255·perp tiles,
	; depth16 (wz_y) = 512·perp tiles. 255/512 = 1/2 − 1/512.
	lda span_a
	sta col
	lda wz_y_h
	lsr
	sta wz_x_h
	lda wz_y_l
	ror
	sta wz_x_l
	lda wz_y_h
	lsr
	sta tmp0			; depth16 >> 9
	sec
	lda wz_x_l
	sbc tmp0
	sta wz_x_l
	lda wz_x_h
	sbc #0
	sta wz_x_h
	; Bind clip once; advance clip_base by CLIP_COL_BYTES each column
	jsr clip_col_bind
.id_clp
	lda col
	cmp span_b
	bcc .id_cin
	rts
.id_cin
	jsr clip_col_find
	bcs .id_cnx
	lda fill_y0
	cmp tmp0
	bcs .id_yt
	lda tmp0
.id_yt
	sta py_row
	lda fill_y1
	cmp tmp1
	bcc .id_yb
	lda tmp1
.id_yb
	sta item_ybot
	lda py_row
	cmp item_ybot
	bcc .id_spanok
.id_cnx
	; Advance U-DDA for enemies + stretch items (also on clip-miss columns)
	lda far_floor
	bne .id_cnx_uadv
	lda wall_col
	cmp #ITEM_TYPE_EXPLOSION
	beq .id_cnx_uadv
	bne .id_cnx_nou
.id_cnx_uadv
	clc
	lda item_u_l
	adc wish_x_l			; ustep
	sta item_u_l
	lda item_u_h
	adc wish_x_h
	sta item_u_h
.id_cnx_nou
	; Next column's clip stack (CLIP_COL_BYTES interleaved stride)
	clc
	lda clip_base_l
	adc #CLIP_COL_BYTES
	sta clip_base_l
	lda clip_base_h
	adc #0
	sta clip_base_h
	inc col
	jmp .id_clp
.id_spanok
	; Live enemy: stamp this drawn column (aim_item set at loop entry)
	lda aim_item
	cmp #$ff
	beq .id_draw
	ldy col
	sta COL_AIM_SLOT,y
	lda wallz_h
	sta COL_AIM_Z,y
.id_draw
	jsr set_col_base
	lda far_floor
	beq .id_draw_item
	jmp .id_e32
.id_draw_item
	lda wall_col
	cmp #ITEM_TYPE_EXPLOSION
	beq .id_e_stretch
	jmp .id_e8

; --- Stretch item column (U/V DDA; item mips, $ff = clear) ---
.id_e_stretch
	lda item_u_h			; bmp_x
	cmp last_near_ceil
	bcc .ids_xok
	lda last_near_ceil
	sec
	sbc #1
.ids_xok
	sta last_near_floor		; bmp_x
	; ptr = hoisted mip base + bmp_x * mip_h
	lda item_mip_base_l
	sta ptr_l
	lda item_mip_base_h
	sta ptr_h
	lda item_vshift
	bne .ids_off_calc
	sta aux_l			; 1-pixel mip: offset is always zero
	sta aux_h
	beq .ids_off_ready
.ids_off_calc
	asl
	asl
	asl
	asl
	ora last_near_floor
	tax
	lda mip_col_off_lo,x
	sta aux_l
	lda mip_col_off_hi,x
	sta aux_h
.ids_off_ready
	clc
	lda ptr_l
	adc aux_l
	sta ptr_l
	lda ptr_h
	adc aux_h
	sta ptr_h
	lda wallz_l
	sta tmp5
	jsr item_vdda_seed
	ldy py_row
.ids_rlp
	cpy item_ybot
	bcc .ids_row
	jmp .id_cnx
.ids_row
	sty tmp4
	lda acc_h				; bmp_y
	cmp tmp5
	bcc .ids_yok
	lda tmp5
	sec
	sbc #1
.ids_yok
	tay
	lda (ptr_l),y
	cmp #$ff				; $ff = clear
	beq .ids_skip
	ldy tmp4
	sta (col_base_l),y
	lda #ITEM_PAT
	sta (pat_base_l),y
.ids_skip
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	ldy tmp4
	iny
	jmp .ids_rlp

; --- Enemy column (U-DDA + hoisted invariants) ---
.id_e32
	lda item_u_h			; bmp_x
	cmp last_near_ceil
	bcc .id32_xok
	lda last_near_ceil
	sec
	sbc #1
.id32_xok
	ldx item_mirror
	beq .id32_nomir
	sta tmp0
	lda last_near_ceil
	sec
	sbc #1
	sec
	sbc tmp0
.id32_nomir
	sta last_near_floor		; bmp_x
	; ptr = hoisted mip base + bmp_x * mip_h
	lda item_mip_base_l
	sta ptr_l
	lda item_mip_base_h
	sta ptr_h
	lda item_vshift
	bne .id32_off_calc
	sta aux_l
	sta aux_h
	beq .id32_off_ready
.id32_off_calc
	asl
	asl
	asl
	asl
	ora last_near_floor
	tax
	lda mip_col_off_lo,x
	sta aux_l
	lda mip_col_off_hi,x
	sta aux_h
.id32_off_ready
	clc
	lda ptr_l
	adc aux_l
	sta ptr_l
	lda ptr_h
	adc aux_h
	sta ptr_h
	; Seed V acc only (texstep already set); wallz_l = mip_h
	lda wallz_l
	sta tmp5
	jsr item_vdda_seed
	ldy py_row
.id32_rlp
	cpy item_ybot
	bcc .id32_row
	jmp .id_cnx
.id32_row
	sty tmp4
	lda acc_h				; bmp_y
	cmp tmp5
	bcc .id32_yok
	lda tmp5
	sec
	sbc #1
.id32_yok
	tay
	lda (ptr_l),y
	beq .id32_skip
	ldy tmp4
	sta (col_base_l),y
	lda #ITEM_PAT
	sta (pat_base_l),y
.id32_skip
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	ldy tmp4
	iny
	jmp .id32_rlp

; --- Item column (1:1; ptr -= near_fcol so Y indexes both tex and screen) ---
.id_e8
	lda col
	sec
	sbc fracx
	bmi .id8_x0
	cmp last_near_ceil			; mip_w
	bcc .id8_xok
	lda last_near_ceil
	sec
	sbc #1
	bpl .id8_xok
.id8_x0
	lda #0
.id8_xok
	sta last_near_floor			; bmp_x
	lda item_mip_base_l
	sta ptr_l
	lda item_mip_base_h
	sta ptr_h
	lda item_vshift
	bne .id8_off_calc
	sta aux_l			; 1-pixel mip: offset is always zero
	sta aux_h
	beq .id8_off_ready
.id8_off_calc
	asl
	asl
	asl
	asl
	ora last_near_floor
	tax
	lda mip_col_off_lo,x
	sta aux_l
	lda mip_col_off_hi,x
	sta aux_h
.id8_off_ready
	clc
	lda ptr_l
	adc aux_l
	sta ptr_l
	lda ptr_h
	adc aux_h
	sta ptr_h
	; Fold near_fcol into ptr so screen Y indexes texture too
	lda near_fcol
	bpl .id8_psub
	; near_fcol negative (sprite top above screen): ptr += |near_fcol|
	eor #$ff
	clc
	adc #1
	clc
	adc ptr_l
	sta ptr_l
	lda ptr_h
	adc #0
	sta ptr_h
	jmp .id8_loop
.id8_psub
	sec
	lda ptr_l
	sbc near_fcol
	sta ptr_l
	lda ptr_h
	sbc #0
	sta ptr_h
.id8_loop
	ldy py_row
.id_rlp
	cpy item_ybot
	bcs .id_cnx_jmp
	lda (ptr_l),y
	cmp #$ff				; $ff = clear (black $00 is opaque)
	beq .id_skip
	sta (col_base_l),y
	lda #ITEM_PAT
	sta (pat_base_l),y
.id_skip
	iny
	jmp .id_rlp
.id_cnx_jmp
	jmp .id_cnx

; ---------------------------------------------------------------------------
; item_vdda_texstep — A = mip_h; wish_y = recip[H]
; Exit: texstep = mip_h/H in 8.8. Clobbers tmp0/tmp1, X, Y.
; ---------------------------------------------------------------------------
item_vdda_texstep
	tay
	lda wish_y_l
	jsr mul_8x8
	sta tmp0
	; Y still mip_h? mul_8x8 doesn't preserve Y — reload
	ldy wallz_l			; mip_h (caller stored)
	lda wish_y_h
	jsr mul_8x8
	sta tmp1
	clc
	txa
	adc tmp0
	sta texstep_l
	lda tmp1
	adc #0
	sta texstep_h
	rts

; ---------------------------------------------------------------------------
; item_vdda_seed — texstep set; py_row / near_fcol set; tmp5 = mip_h
; Exit: acc = v at py_row (8.8). Clobbers tmp0/tmp2, X, Y.
; ---------------------------------------------------------------------------
item_vdda_seed
	lda py_row
	sec
	sbc near_fcol
	sta tmp2
	beq .ivs_z
	tay
	lda texstep_l
	jsr mul_8x8
	stx acc_l
	sta tmp0
	ldy tmp2
	lda texstep_h
	jsr mul_8x8
	clc
	txa
	adc tmp0
	sta acc_h
	rts
.ivs_z
	sta acc_l
	sta acc_h
	rts

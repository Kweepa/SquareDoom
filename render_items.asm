!zone render_items

; ============================================================================
; render_items.asm — billboard items into FRAMEBUFFER after column cast
; ============================================================================
; Collect items in seen sectors, depth-sort far→near, project, draw clipped
; against COL_CLIP_* stack. Column-major item mips (byte colour, 0=clear).
; ============================================================================

ITEM_DEPTH_MIN = 1			; editor uses ~0.8 world units
ITEM_AXIS_MAX = 120			; cull if |dx| or |dy| > 15 tiles (8-bit safe)
ITEM_TYPE_ENEMY_LO = 1
ITEM_TYPE_ENEMY_HI = 5
ITEM_TYPE_EMPTY = $ff
ITEM_TYPE_SPAWN = 0
ITEM_TYPE_FIREBALL = 23
TEX_ANIMATE = 64

; Scratch after column loop (column temps free):
;   turn = item slot
;   wall_col = typeId
;   wallz_h = depth
;   near_floor / near_ceil = floor height / sector
;   far_ceil = sprite H; last_near_ok = sprite W
;   near_fcol = unclamped sprite top (V map; fill_y0 may be clamped)
;   last_near_fcol = screen centre col
;   last_near_ccol = sort index / draw scratch
;   span_a = visible count during collect/sort

; ---------------------------------------------------------------------------
; render_items
; ---------------------------------------------------------------------------
render_items
!if PROFILE = 1 {
	jsr prof_snap
}
	; Clear muzzle aim markers ($FF = not on MUZZLE_COL this frame)
	ldx #0
	lda #$ff
.ri_clr_aim
	sta MOBJ_AIMY,x
	inx
	cpx #MAX_MOBJ
	bne .ri_clr_aim
	lda #0
	sta span_a
	ldx #0
.ri_col
	txa
	asl
	asl
	tay
	lda level_items,y
	cmp #ITEM_TYPE_EMPTY
	beq .ri_nx
	cmp #ITEM_TYPE_SPAWN
	beq .ri_nx
	iny
	lda level_items,y
	lsr
	lsr
	lsr
	sta mapx
	iny
	lda level_items,y
	lsr
	lsr
	lsr
	sta mapy
	stx turn
	jsr map_sector_id
	beq .ri_nx2
	tay
	lda SEC_SEEN,y
	beq .ri_nx2
	sty near_ceil
	ldx turn
	jsr item_calc_depth
	bcs .ri_nx2
	; A = depth
	ldy span_a
	sta ITEM_SORT_DEPTH,y
	lda turn
	sta ITEM_SORT_SLOT,y
	iny
	sty span_a
	cpy #MAX_ITEMS
	bcs .ri_go
.ri_nx2
	ldx turn
.ri_nx
	inx
	cpx #MAX_ITEMS
	bcc .ri_col
.ri_go
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
	tax
	lda ITEM_SORT_SLOT,x
	sta turn
	lda ITEM_SORT_DEPTH,x
	sta wallz_h
	jsr item_draw_one
	inc last_near_ccol
	jmp .ri_dlp
.ri_done
!if PROFILE = 1 {
	ldy #PROF_ITEMS
	jmp prof_add_bucket
}
	rts

; ---------------------------------------------------------------------------
; item_calc_depth — X=slot, near_ceil=sector
; Exit: C=1 skip; C=0 A=depth (1..255)
; Also sets wall_col=typeId, near_floor=floor
; Leaves fracy=dx, fracx=dy (signed 8-bit) for item_calc_screen
; ---------------------------------------------------------------------------
item_calc_depth
	txa
	asl
	asl
	tay
	lda level_items,y
	sta wall_col
	iny
	lda level_items,y
	sta tmp0			; ix
	iny
	lda level_items,y
	sta tmp1			; iy
	lda tmp0			; ix
	sta tmp2
	lda playerx_h
	jsr item_uabs8		; |ix-px|
	cmp #ITEM_AXIS_MAX+1
	bcs .icd_bad
	lda tmp0
	sec
	sbc playerx_h
	sta fracy			; dx (signed; |dx|≤120)
	lda tmp1			; iy
	sta tmp2
	lda playery_h
	jsr item_uabs8		; |iy-py|
	cmp #ITEM_AXIS_MAX+1
	bcs .icd_bad
	lda tmp1
	sec
	sbc playery_h
	sta fracx			; dy
	ldy playera
	lda sintab,y
	sta last_near_floor		; sin
	tya
	clc
	adc #64
	tay
	lda sintab,y
	sta last_near_ceil		; cos
	lda #0
	sta wallz_l
	sta wallz_h
	; depth = dx*sin - dy*cos
	lda fracy
	ldy last_near_floor
	jsr smul_wz_add
	lda fracx
	ldy last_near_ceil
	jsr smul_wz_sub
	ldx #6
.icd_shr
	lda wallz_h
	cmp #$80
	ror wallz_h
	ror wallz_l
	dex
	bne .icd_shr
	lda wallz_h
	bmi .icd_bad
	bne .icd_clamp
	lda wallz_l
	beq .icd_bad
	cmp #ITEM_DEPTH_MIN
	bcc .icd_bad
	jmp .icd_ok
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
	sec
	sbc tmp3
	rts

; ---------------------------------------------------------------------------
; item_calc_screen — after item_calc_depth; uses fracy/x, sin/cos in last_near_*
; Exit: last_near_fcol = centre screen column (may be off 0..39)
; ---------------------------------------------------------------------------
item_calc_screen
	lda #0
	sta aux_l
	sta aux_h
	; lateral = dx*cos + dy*sin
	lda fracy
	ldy last_near_ceil		; cos
	jsr smul_aux_add
	lda fracx
	ldy last_near_floor		; sin
	jsr smul_aux_add
	ldx #6
.ics_shr
	lda aux_h
	cmp #$80
	ror aux_h
	ror aux_l
	dex
	bne .ics_shr
	; (lateral << 5) / depth
	lda aux_l
	sta tmp0
	lda aux_h
	sta tmp1
	ldx #5
.ics_asl
	asl tmp0
	rol tmp1
	dex
	bne .ics_asl
	lda wallz_h			; depth
	jsr sdiv16x8			; A = quot
	clc
	adc #19
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

; (tmp1:tmp0) / A → A signed quot
sdiv16x8
	sta tmp5
	lda #0
	sta tmp4
	lda tmp1
	bpl .sd_abs
	inc tmp4
	lda tmp0
	eor #$ff
	clc
	adc #1
	sta tmp0
	lda tmp1
	eor #$ff
	adc #0
	sta tmp1
.sd_abs
	lda tmp5
	beq .sd_z
	ldx #0
.sd_lp
	lda tmp1
	bne .sd_sub
	lda tmp0
	cmp tmp5
	bcc .sd_done
.sd_sub
	sec
	lda tmp0
	sbc tmp5
	sta tmp0
	lda tmp1
	sbc #0
	sta tmp1
	inx
	cpx #127				; cap |quot| — 19±127 can't wrap the centre col
	bne .sd_lp
.sd_done
	txa
	ldy tmp4
	beq .sd_out
	eor #$ff
	clc
	adc #1
.sd_out
	rts
.sd_z
	lda #0
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
	cpx #0
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
	ldx span_a
	dex
	beq .is_done
	stx tmp0
.is_o
	lda #0
	sta tmp1
	ldx #0
.is_i
	cpx tmp0
	bcs .is_n
	lda ITEM_SORT_DEPTH,x
	cmp ITEM_SORT_DEPTH+1,x
	bcs .is_ok
	ldy ITEM_SORT_DEPTH+1,x
	sta ITEM_SORT_DEPTH+1,x
	tya
	sta ITEM_SORT_DEPTH,x
	lda ITEM_SORT_SLOT,x
	ldy ITEM_SORT_SLOT+1,x
	sta ITEM_SORT_SLOT+1,x
	tya
	sta ITEM_SORT_SLOT,x
	inc tmp1
.is_ok
	inx
	jmp .is_i
.is_n
	lda tmp1
	beq .is_done
	dec tmp0
	bne .is_o
.is_done
	rts

; ---------------------------------------------------------------------------
; item_draw_one — turn=slot, wallz_h=depth (from sort)
; ---------------------------------------------------------------------------
item_draw_one
	ldx turn
	txa
	asl
	asl
	tay
	lda level_items,y
	sta wall_col
	iny
	lda level_items,y
	lsr
	lsr
	lsr
	sta mapx
	iny
	lda level_items,y
	lsr
	lsr
	lsr
	sta mapy
	jsr map_sector_id
	bne .id_gotsec
	rts
.id_gotsec
	sta near_ceil
	tay
	lda SEC_SEEN,y
	bne .id_seen
	rts
.id_seen
	lda SEC_FLOOR,y
	sta near_floor
	ldx turn
	jsr item_calc_depth
	bcc .id_dpthok
	rts
.id_dpthok
	sta wallz_h
	jsr item_calc_screen
	lda wall_col
	cmp #ITEM_TYPE_ENEMY_LO
	bcc .id_half
	cmp #ITEM_TYPE_ENEMY_HI+1
	bcs .id_half
	lda #128			; worldH 4 × proj 32
	bne .id_hd
.id_half
	lda #64				; half-height pickups
.id_hd
	sta aux_l
	lda #0
	sta aux_h
	lda wallz_h
	jsr udiv16x8
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
	sta far_ceil			; screen H (survives sdiv/udiv)
	ldx turn
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
	sta far_floor			; 0 = item mip path
	lda far_ceil
	cmp #17				; items max 16×16 on screen
	bcc .id_item_sz
	lda #16
.id_item_sz
	sta far_ceil
	sta last_near_ok			; square W = H
.id_feet
	; Feet: fireball uses missile_z (hitscan-style height); else sector floor
	lda wall_col
	cmp #ITEM_TYPE_FIREBALL
	bne .id_feet_fl
	lda missile_z
	jmp .id_feet_h
.id_feet_fl
	lda near_floor
.id_feet_h
	sta tmp2
	lda eyeheight
	sec
	sbc tmp2
	sta tmp2
	lda #0
	sta aux_l
	sta aux_h
	lda tmp2
	ldy #32
	jsr smul_aux_add
	jsr sdiv_aux_depth
	clc
	adc #HORIZON
	clc
	adc #1				; exclusive bot: last pixel on floor row
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
	; Clamp draw span only — near_fcol keeps true top for UV
	lda fill_y0
	bpl .id_topok
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
	bcc .id_vok
.id_rts
	rts
.id_vok
	lda far_floor
	bne .id_emip
	; Item mip from projected W
	lda last_near_ok
	ldx #0
	cmp #8
	bcs .id_imip_got			; ≥8 → mip0
	ldx #1
	cmp #4
	bcs .id_imip_got			; ≥4 → mip1
	ldx #2
	cmp #2
	bcs .id_imip_got			; ≥2 → mip2
	ldx #3				; else mip3 (W==1)
.id_imip_got
	stx fracy				; mip index (udiv16x8 clobbers tmp5)
	lda item_mip_w,x
	sta last_near_ceil			; mip_w (scratch for draw)
	jmp .id_clp_go
.id_emip
	; Enemy mip from projected W (thresholds; U scales to mip_w)
	lda last_near_ok
	ldx #0
	cmp #16
	bcs .id_mip_got			; ≥16 → mip0
	ldx #1
	cmp #8
	bcs .id_mip_got			; ≥8 → mip1
	ldx #2
	cmp #4
	bcs .id_mip_got			; ≥4 → mip2
	ldx #3
	cmp #2
	bcs .id_mip_got			; ≥2 → mip3
	ldx #4				; else mip4
.id_mip_got
	stx fracy				; mip index (udiv16x8 clobbers tmp5)
	lda enemy_mip_w,x
	sta last_near_ceil			; mip_w (scratch for draw)
.id_clp_go
	lda span_a
	sta col
.id_clp
	lda col
	cmp span_b
	bcc .id_cin
	rts
.id_cin
	cmp #40
	bcs .id_cnx
	lda near_ceil
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
	sta dda_steps
	lda py_row
	cmp dda_steps
	bcc .id_spanok
.id_cnx
	inc col
	jmp .id_clp
.id_spanok
	; Muzzle column: record mid Y of drawn span for live enemies
	lda col
	cmp #MUZZLE_COL
	bne .id_draw
	ldx turn
	lda wall_col
	cmp #ITEM_TYPE_ENEMY_LO
	bcc .id_draw
	cmp #ITEM_TYPE_ENEMY_HI+1
	bcs .id_draw
	lda MOBJ_FOR_ITEM,x
	cmp #$ff
	beq .id_draw
	tay
	lda MOBJ_ALLOC,y
	beq .id_draw
	lda MOBJ_HEALTH,y
	beq .id_draw
	lda MOBJ_INFO,y
	cmp #4				; skip impshot
	bcs .id_draw
	lda py_row
	clc
	adc dda_steps
	lsr					; mid Y of drawn column
	sta MOBJ_AIMY,y
	lda wallz_h
	sta MOBJ_AIMZ,y
.id_draw
	jsr set_col_base
	lda far_floor
	bne .id_e32
	jmp .id_e8

; --- Enemy column (mip-aware; source W×H from tables) ---
.id_e32
	; bmp_x = (col - orig_left) * mip_w / W
	lda fracx
	bpl .id32_oxp
	lda #0
	sec
	sbc fracx
	clc
	adc col
	jmp .id32_ox
.id32_oxp
	lda col
	sec
	sbc fracx
.id32_ox
	sta aux_l
	lda #0
	sta aux_h
	ldx fracy
	lda enemy_mip_ushift,x
	beq .id32_ux0
	tax
.id32_uxlp
	asl aux_l
	rol aux_h
	dex
	bne .id32_uxlp
.id32_ux0
	lda last_near_ok
	jsr udiv16x8
	cmp last_near_ceil		; >= mip_w → clamp
	bcc .id32_xok
	lda last_near_ceil
	sec
	sbc #1
.id32_xok
	sta last_near_floor		; bmp_x
	; mirror walk if TEX_ANIMATE and (anim_frame & 2)
	lda far_floor
	and #TEX_ANIMATE
	beq .id32_nomir
	lda anim_frame
	and #2
	beq .id32_nomir
	lda last_near_ceil
	sec
	sbc #1				; mip_w - 1
	sec
	sbc last_near_floor
	sta last_near_floor
.id32_nomir
	; ptr = enemy_mip_base[frame*5+mip] + bmp_x * mip_h
	lda far_floor
	and #$bf				; clear TEX_ANIMATE → frame
	sta tmp0
	asl
	asl					; *4
	clc
	adc tmp0				; *5
	clc
	adc fracy				; + mip
	tax
	lda enemy_mip_base_lo,x
	sta ptr_l
	lda enemy_mip_base_hi,x
	sta ptr_h
	lda last_near_floor		; bmp_x * mip_h
	sta aux_l
	lda #0
	sta aux_h
	ldx fracy
	lda enemy_mip_vshift,x
	beq .id32_vx0
	tax
.id32_vxlp
	asl aux_l
	rol aux_h
	dex
	bne .id32_vxlp
.id32_vx0
	clc
	lda ptr_l
	adc aux_l
	sta ptr_l
	lda ptr_h
	adc aux_h
	sta ptr_h
	ldy py_row
.id32_rlp
	cpy dda_steps
	bcc .id32_row
	jmp .id_cnx
.id32_row
	sty tmp4
	tya
	sec
	sbc near_fcol			; unclamped top (signed byte OK)
	sta aux_l
	lda #0
	sta aux_h
	; * mip_h / H
	ldx fracy
	lda enemy_mip_vshift,x
	beq .id32_vy0
	tax
.id32_vylp
	asl aux_l
	rol aux_h
	dex
	bne .id32_vylp
.id32_vy0
	lda far_ceil
	jsr udiv16x8
	ldx fracy
	cmp enemy_mip_h,x
	bcc .id32_yok
	lda enemy_mip_h,x
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
	ldy tmp4
	iny
	jmp .id32_rlp

; --- Item column (mip-aware; source W×H from item_mip_* tables) ---
.id_e8
	; bmp_x = (col - orig_left) * mip_w / W
	lda fracx
	bpl .id8_oxp
	lda #0
	sec
	sbc fracx
	clc
	adc col
	jmp .id8_ox
.id8_oxp
	lda col
	sec
	sbc fracx
.id8_ox
	sta aux_l
	lda #0
	sta aux_h
	ldx fracy
	lda item_mip_ushift,x
	beq .id8_ux0
	tax
.id8_uxlp
	asl aux_l
	rol aux_h
	dex
	bne .id8_uxlp
.id8_ux0
	lda last_near_ok
	jsr udiv16x8
	cmp last_near_ceil		; >= mip_w → clamp
	bcc .id8_xok
	lda last_near_ceil
	sec
	sbc #1
.id8_xok
	sta last_near_floor		; bmp_x
	; ptr = item_mip_base[type*4+mip] + bmp_x * mip_h
	lda wall_col
	asl
	asl					; *4
	clc
	adc fracy				; + mip
	tax
	lda item_mip_base_lo,x
	sta ptr_l
	lda item_mip_base_hi,x
	sta ptr_h
	lda last_near_floor
	sta aux_l
	lda #0
	sta aux_h
	ldx fracy
	lda item_mip_vshift,x
	beq .id8_vx0
	tax
.id8_vxlp
	asl aux_l
	rol aux_h
	dex
	bne .id8_vxlp
.id8_vx0
	clc
	lda ptr_l
	adc aux_l
	sta ptr_l
	lda ptr_h
	adc aux_h
	sta ptr_h
	ldy py_row
.id_rlp
	cpy dda_steps
	bcc .id_row
	jmp .id_cnx
.id_row
	sty tmp4
	tya
	sec
	sbc near_fcol
	sta aux_l
	lda #0
	sta aux_h
	ldx fracy
	lda item_mip_vshift,x
	beq .id8_vy0
	tax
.id8_vylp
	asl aux_l
	rol aux_h
	dex
	bne .id8_vylp
.id8_vy0
	lda far_ceil
	jsr udiv16x8
	ldx fracy
	cmp item_mip_h,x
	bcc .id8_yok
	lda item_mip_h,x
	sec
	sbc #1
.id8_yok
	tay
	lda (ptr_l),y
	beq .id_skip
	ldy tmp4
	sta (col_base_l),y
	lda #ITEM_PAT
	sta (pat_base_l),y
.id_skip
	ldy tmp4
	iny
	jmp .id_rlp

sdiv_aux_depth
	lda aux_l
	sta tmp0
	lda aux_h
	sta tmp1
	lda wallz_h
	jmp sdiv16x8

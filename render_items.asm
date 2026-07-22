!zone render_items

; ============================================================================
; render_items.asm — billboard items into FRAMEBUFFER after column cast
; ============================================================================
; Collect items in seen sectors, depth-sort far→near, project, draw clipped
; against COL_CLIP_* stack. Column-major item mips (byte colour, 0=clear).
; Live enemies stamp COL_AIM_SLOT/Z per column (nearer overwrites).
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
;   item_slot = current billboard item index (not ZP — once per item)
;   wall_col = typeId
;   wallz_h = depth
;   near_floor / near_ceil = floor height / sector
;   far_ceil = sprite H; last_near_ok = sprite W
;   near_fcol = unclamped sprite top (V map; fill_y0 may be clamped)
;   last_near_fcol = screen centre col
;   last_near_ccol = sort index / draw scratch
;   span_a = visible count during collect/sort

; Current item index during collect/draw (keep off ZP; turn $32 is player yaw)
item_slot	!byte 0

; ---------------------------------------------------------------------------
; render_items
; ---------------------------------------------------------------------------
render_items
!if PROFILE = 1 {
	jsr prof_snap
}
	; Clear per-column aim ($FF = no live enemy this frame)
	ldx #0
	lda #$ff
.ri_clr_aim
	sta COL_AIM_SLOT,x
	inx
	cpx #COL_NUM
	bne .ri_clr_aim
	lda #0
	sta span_a
	ldx #0
.ri_col
	lda level_item_type,x
	cmp #ITEM_TYPE_EMPTY
	beq .ri_nx
	cmp #ITEM_TYPE_SPAWN
	beq .ri_nx
	lda level_item_x,x
	lsr
	lsr
	lsr
	sta mapx
	lda level_item_y,x
	lsr
	lsr
	lsr
	sta mapy
	stx item_slot
	jsr map_sector_id
	beq .ri_nx2
	tay
	lda SEC_SEEN,y
	beq .ri_nx2
	sty near_ceil
	ldx item_slot
	jsr item_calc_depth
	bcs .ri_nx2
	; A = depth
	ldy span_a
	sta ITEM_SORT_DEPTH,y
	lda item_slot
	sta ITEM_SORT_SLOT,y
	iny
	sty span_a
	cpy #MAX_ITEMS
	bcs .ri_go
.ri_nx2
	ldx item_slot
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
	sta item_slot
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
	lda level_item_type,x
	sta wall_col
	lda level_item_x,x
	sta tmp0			; ix
	lda level_item_y,x
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
	; centre col = 19 + lateral*32/z  (Larsson recip: mul_recip_z)
	; |lateral| fits signed 8-bit after >>6 (axis≤120, |sin|≤64)
	lda aux_l
	ldx wallz_h
	jsr mul_recip_z
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
; item_draw_one — item_slot set, wallz_h=depth (from sort)
; ---------------------------------------------------------------------------
item_draw_one
	lda #$ff
	sta aim_item
	ldx item_slot
	lda level_item_type,x
	sta wall_col
	lda level_item_x,x
	lsr
	lsr
	lsr
	sta mapx
	lda level_item_y,x
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
	ldx item_slot
	jsr item_calc_depth
	bcc .id_dpthok
	rts
.id_dpthok
	sta wallz_h
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
	jmp .id_h0
.id_half
	lda tmp0
	lsr					; pickups: half-height
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
	sta far_ceil			; screen H
	ldx item_slot
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
	sta tmp2				; signed (eye − feet); *32/z via recip
	ldx wallz_h
	jsr mul_recip_z
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
	stx fracy				; mip index
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
	stx fracy				; mip index
	lda enemy_mip_w,x
	sta last_near_ceil			; mip_w (scratch for draw)
.id_clp_go
	; Cache recip[W]/recip[H] once per sprite (Larsson); U/V use mul not div.
	; wish_* are move scratch — free during item draw.
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
	; Live enemy: lock aim_item (MOBJ_OBJ is authoritative via mobj_for_slot)
	ldx item_slot
	lda wall_col
	cmp #ITEM_TYPE_ENEMY_LO
	bcc .id_clp_start
	cmp #ITEM_TYPE_ENEMY_HI+1
	bcs .id_clp_start
	jsr mobj_for_slot
	bcs .id_clp_start
	lda MOBJ_HEALTH,y
	beq .id_clp_start
	lda MOBJ_INFO,y
	cmp #4
	bcs .id_clp_start
	lda item_slot
	sta aim_item
.id_clp_start
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
	bcc .id_found
	jmp .id_cnx
.id_found
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
	jsr udiv_aux_rec_w			; (ox * mip_w) / W
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
	; V DDA: step = mip_h/H in 8.8; acc seeded at py_row
	ldx fracy
	lda enemy_mip_h,x
	jsr item_vdda_setup			; texstep=step, acc=v; tmp5=mip_h
	ldy py_row
.id32_rlp
	cpy dda_steps
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
	jsr udiv_aux_rec_w			; (ox * mip_w) / W
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
	ldx fracy
	lda item_mip_h,x
	jsr item_vdda_setup
	ldy py_row
.id_rlp
	cpy dda_steps
	bcc .id_row
	jmp .id_cnx
.id_row
	sty tmp4
	lda acc_h
	cmp tmp5
	bcc .id8_yok
	lda tmp5
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
	clc
	lda acc_l
	adc texstep_l
	sta acc_l
	lda acc_h
	adc texstep_h
	sta acc_h
	ldy tmp4
	iny
	jmp .id_rlp

; ---------------------------------------------------------------------------
; item_vdda_setup — A = mip_h; wish_y = recip[H]; py_row / near_fcol set
; Exit: texstep = mip_h/H in 8.8, acc = v at py_row (8.8), tmp5 = mip_h
; Clobbers: tmp0..tmp2, X, Y
; ---------------------------------------------------------------------------
item_vdda_setup
	sta tmp5				; mip_h for clamp
	tay
	lda wish_y_l
	jsr mul_8x8				; mip_h * recip_lo
	sta tmp0				; hi
	ldy tmp5
	lda wish_y_h
	jsr mul_8x8				; mip_h * recip_hi
	sta tmp1				; hi(mip*rh)
	clc
	txa					; lo(mip*rh)
	adc tmp0				; + hi(mip*rl) → (mip*recip)>>8
	sta texstep_l
	lda tmp1
	adc #0
	sta texstep_h
	; acc = (py_row - near_fcol) * step  (low 16 of 8×16)
	lda py_row
	sec
	sbc near_fcol
	sta tmp2				; dy (unsigned distance from sprite top)
	beq .ivs_z
	tay
	lda texstep_l
	jsr mul_8x8
	stx acc_l
	sta tmp0				; hi(dy*step_l)
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

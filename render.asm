!zone render

; TheKeep secant-DDA + texstep summing for portal heights.
; Bugfixes vs earlier TheKeep port:
;  - lookang−64 maps editor north onto TheKeep axes
;  - target = |Δh|, texstep = wallz>>2 (×4/×8 targets made full-screen flats)
;  - overflow ends ray on both axes
;  - paints into transposed FRAMEBUFFER; blit_fb_to_color copies to $D800
;
; PROFILE=1 HUD: F S D W N L P — see render_*.asm per letter.

WALL_NS = 8
WALL_EW = 9
HORIZON = 12
; target = |Δh|; texstep = wallz>>2 (TheKeep). mid-product wallz ≈ tiles·fish
; screen rows ≈ Δh·4/tiles ≈ editor Δh·PROJ/(tiles·8)
TEXSTEP_SHIFT = 2

render
	lda #0
	sta dda_peak
	sta span_lo
	sta span_hi
!if DBG_PORTAL = 1 {
	sta dbg_n
	lda #255
	sta dbg_far_y
}
!if PROFILE = 1 {
	jsr prof_reset_frame
}
	jsr setup_player_tile
	lda playera
	cmp last_playera
	beq .rays_ok
	sta last_playera
	jsr rebuild_col_rays
.rays_ok
	lda #0
	sta col
.col_loop
	jsr set_col_base
	jsr cast_column
	inc col
	lda col
	cmp #40
	bcc .col_loop
	jsr blit_fb_to_color
	jsr prof_frame_sample
	jsr prof_print
!if DBG_PORTAL = 1 {
	jsr dbg_portal_flush
}
	jmp print_dda_peak

; C=1 stop column — orchestrates W / N / L
on_cell
	lda next_id
	cmp cur_id
	bne .chg
	clc
	rts
.chg
	jsr calc_wallz
!if PROFILE = 1 {
	ldy #PROF_WALLZ
	jsr prof_add_bucket
}
	lda cur_id
	beq .void_enter
	; Same floor/ceil/colours as last paint_near → skip fills (untextured).
	; If portal needs a ledge, still refresh span_a/b at this wallz.
	lda last_near_ok
	beq .do_near
	ldx cur_id
	lda SEC_FLOOR,x
	cmp last_near_floor
	bne .do_near
	lda SEC_CEIL,x
	cmp last_near_ceil
	bne .do_near
	lda SEC_FCOL,x
	cmp last_near_fcol
	bne .do_near
	lda SEC_CCOL,x
	cmp last_near_ccol
	bne .do_near
	lda next_id
	beq .after_near			; solid — spans unused
	tax
	lda SEC_CEIL,x
	cmp near_ceil
	bcc .near_spans			; upper ledge
	lda SEC_FLOOR,x
	cmp near_floor
	bcc .after_near			; contained
	beq .after_near
.near_spans
	jsr refresh_near_spans
	jmp .after_near
.do_near
	jsr load_near_sector
	jsr paint_near
	lda near_floor
	sta last_near_floor
	lda near_ceil
	sta last_near_ceil
	lda near_fcol
	sta last_near_fcol
	lda near_ccol
	sta last_near_ccol
	lda #1
	sta last_near_ok
.after_near
!if PROFILE = 1 {
	ldy #PROF_NEAR
	jsr prof_add_bucket
}
	lda ytop
	cmp ybot
	bcc .edge
!if DBG_PORTAL = 1 {
	jsr dbg_portal_log
}
	sec
	rts
.void_enter
	lda next_id
	beq .stop
	sta cur_id
	clc
	rts
.edge
	lda next_id
	bne .portal
	jsr wall_colour_ns_ew
	lda wall_col
	jsr fill_col_span
	lda ybot			; close clip — prevent fill_open_remainder wiping the wall
	sta ytop
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
!if DBG_PORTAL = 1 {
	jsr dbg_portal_log
}
	sec
	rts
.portal
	jsr paint_portal
!if PROFILE = 1 {
	ldy #PROF_LEDGE
	jsr prof_add_bucket
}
!if DBG_PORTAL = 1 {
	jsr dbg_portal_log
}
	lda ytop
	cmp ybot
	bcc .cont
	sec
	rts
.cont
	lda next_id
	sta cur_id
	clc
	rts
.stop
	; void→void: nothing to draw; close clip if somehow open
	lda ybot
	sta ytop
	sec
	rts

!source "render_setup.asm"
!source "render_dda.asm"
!source "render_wallz.asm"
!source "render_near.asm"
!source "render_ledge.asm"
!source "render_project_y.asm"

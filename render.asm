!zone render

; ============================================================================
; render.asm — frame driver + sector-edge orchestration
; ============================================================================
; TheKeep-style secant DDA with portal height clipping into transposed
; colour ($C800→$D800) and lighting ($CC00→$0400) framebuffers.
;
; Sources (PROFILE HUD letter when PROFILE=1):
;   render_setup.asm      S — player tile + ray cache
;   render_dda.asm        D — column DDA (also closes S after preamble)
;   render_wallz.asm      W — texstep from incremental wz
;   render_near.asm       N — near ceil/floor strips
;   render_ledge.asm      L — portal ledges + solid wall colour
;   render_project_y.asm  P — world height → screen row (mid region + py_tab)
;   render_items.asm      I — item billboards
;
; Clip: open window is [ytop, ybot). Front-to-back: near flats then ledges
; then continue or stop. Bugfixes vs early TheKeep port: lookang−64 north
; mapping; texstep = wallz>>2; s overflow ends ray; paint into FRAMEBUFFER.
;
; ============================================================================

WALL_NS = 8
WALL_EW = 9
HORIZON = 12
; target = |Δh|; texstep = wallz>>2 (TheKeep). mid-product wallz ≈ tiles·fish
; screen rows ≈ Δh·4/tiles ≈ editor Δh·PROJ/(tiles·8)
TEXSTEP_SHIFT = 2

; ---------------------------------------------------------------------------
; render — one full frame (setup → 40 columns → blit → HUD)
; ---------------------------------------------------------------------------
render
	lda #0
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
	jsr clear_sector_seen
	jsr setup_player_tile
	; Ray cache depends only on look angle — rebuild when playera moves
	lda playera
	cmp last_playera
	beq .rays_ok
	sta last_playera
	jsr rebuild_col_rays
.rays_ok
	lda #0
	sta col
.col_loop
	jsr set_col_base		; FRAMEBUFFER column base for fills
	jsr cast_column
	inc col
	lda col
	cmp #40
	bcc .col_loop
	jsr render_items
	jsr draw_info_msg
	jsr blit_fb_to_color
	jsr blit_fb_to_chars
	jsr draw_hud
	jsr show_weapon			; HUD sprites after first (and every) blit
	jsr prof_frame_sample
	jsr prof_print
!if DBG_PORTAL = 1 {
	jmp dbg_portal_flush
}
	rts

; ---------------------------------------------------------------------------
; on_cell — sector id change on the current column ray
;
; Entry: cur_id / next_id / side / sdx|sdy (and wz) already set.
; Exit:  C=1 stop column; C=0 continue DDA with cur_id := next_id (or void).
;
; Order: calc_wallz → (optional) paint_near → solid wall | paint_portal.
; Same-flat skip: if cur flats match last paint_near this column, skip fills
; (still refresh span_a/b if a ledge needs them at this wallz).
; ---------------------------------------------------------------------------
on_cell
	lda next_id
	cmp cur_id
	bne .chg
	clc				; same sector — DDA caller already advances
	rts
.chg
	jsr calc_wallz			; W: side's wz → texstep for project_y
	jsr set_wall_pat		; wall_pat = min(15, wallz_h)
!if PROFILE = 1 {
	ldy #PROF_WALLZ
	jsr prof_add_bucket
}
	lda cur_id
	beq .void_enter			; leaving void: just adopt next_id
	; Same-flat skip: identical flat group already painted this column
	lda last_near_ok
	beq .do_near
	ldx cur_id
	lda SEC_FLATGRP,x
	cmp last_near_flatgrp
	bne .do_near
	lda next_id
	beq .after_near			; solid wall — span_a/b unused
	tax
	lda SEC_CEIL,x
	cmp near_ceil
	bcc .near_spans			; upper ledge needs fresh nearCeilY
	lda SEC_FLOOR,x
	cmp near_floor
	bcc .after_near			; contained far — no ledge
	beq .after_near
.near_spans
	jsr refresh_near_spans		; project only; flats already on screen
	jmp .after_near
.do_near
	jsr load_near_sector
	jsr paint_near			; N: ceil/floor strips + span_a/b
	ldx cur_id
	lda SEC_FLATGRP,x
	sta last_near_flatgrp
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
	sec				; clip closed — end column
	rts
.void_enter
	lda next_id
	beq .stop			; void→void / oob
	sta cur_id
	tax
	jsr mark_seen
	lda cur_id
	jsr clip_col_push
	clc
	rts
.edge
	lda next_id
	bne .portal
	; Solid wall (next_id=0): flood remaining clip, then force-close
	jsr wall_colour_ns_ew
	lda wall_pat
	sta fill_pat
	lda wall_col
	jsr fill_col_span
	lda ybot
	sta ytop			; prevent fill_open_remainder wipe
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
	lda wall_pat
	sta fill_pat
	jsr paint_portal			; L: upper/lower ledges + ybot shrink
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
	sec				; portal closed the clip
	rts
.cont
	lda next_id
	sta cur_id			; enter far sector; DDA keeps walking
	tax
	jsr mark_seen
	lda cur_id
	jsr clip_col_push
	clc
	rts
.stop
	lda ybot
	sta ytop
	sec
	rts

!source "render_setup.asm"
!source "render_dda.asm"
!source "render_wallz.asm"
!source "render_near.asm"
!source "render_ledge.asm"
!source "render_items.asm"

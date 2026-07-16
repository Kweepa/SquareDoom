; Weapon HUD sprites — table-driven layers + muzzle flash
!zone weapon

; Six hi-res layers @ $3680–$37FF, double-size (XY expand):
;   sprites 0–1 = muzzle flash (highest VIC priority)
;   sprites 2–3 = weapon metal
;   sprites 4–5 = hand
PISTOL_SPR_PTR0 = PISTOL_SPRITES / 64	; $da
WPN_ENABLE_IDLE = $3c			; sprites 2–5 only (flash off)
WPN_ENABLE_ALL = $3f			; + flash 0–1
WPN_EXPAND = $3f			; XY expand for all six
MUZZLE_MS = 300
FIRE_REPEAT_DELAY = 600			; ms between shots while held

; Per-sprite colour / X / Y (screen coords; expand already factored into offsets).
; Index = VIC sprite # = layer order in pistol_sprites.asm.
; Future weapons: add parallel tables and point init at the active set.
pistol_spr_col
	!byte 1, 2			; flash white, red
	!byte 0, 11			; weapon black, dark grey
	!byte 9, 8			; hand brown, orange
pistol_spr_x
	!byte 166, 166			; flash (+6 from hand)
	!byte 160, 160			; weapon
	!byte 160, 160			; hand
pistol_spr_y
	!byte 162, 162			; flash (weapon Y − 24)
	!byte 186, 186			; weapon (hand Y − 22)
	!byte 208, 208			; hand (bottom centre)

init_weapon
	lda #WPN_ENABLE_IDLE
	sta spr_en
	sta $d015
	lda #WPN_EXPAND
	sta $d01d
	sta $d017
	lda #0
	sta $d01c			; hi-res
	sta $d010			; X MSB clear (all X < 256)
	sta muzzle_ms_l
	sta muzzle_ms_h
	sta fire_rpt_l
	sta fire_rpt_h

	ldx #0
	ldy #0				; Y = VIC X/Y register pair index (0,2,4…)
.set
	lda pistol_spr_col,x
	sta $d027,x
	txa
	clc
	adc #PISTOL_SPR_PTR0
	sta $07f8,x
	lda pistol_spr_x,x
	sta $d000,y
	lda pistol_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #6
	bcc .set
	rts

; Spend 1 ammo, show muzzle flash, try hit on MUZZLE_COL. C=0 ok, C=1 no ammo.
.fire_shot
	lda ammo
	beq .fs_empty
	sec
	sbc #1
	sta ammo
	lda #<MUZZLE_MS
	sta muzzle_ms_l
	lda #>MUZZLE_MS
	sta muzzle_ms_h
	lda spr_en
	ora #$03
	sta spr_en
	sta $d015
	; Pistol damage: (GetRandom8>>4)+1
	jsr GetRandom8
	lsr
	lsr
	lsr
	lsr
	clc
	adc #1
	jsr TryDamageEnemy
	clc
	rts
.fs_empty
	sec
	rts

; Call once per frame after read_input.
; While I held: fire when fire_rpt is 0, then wait FIRE_REPEAT_DELAY ms.
; Note: $d015 is write-only — use spr_en mirror.
update_muzzle_flash
	; --- muzzle flash sprite timeout ---
	lda muzzle_ms_l
	ora muzzle_ms_h
	beq .mf_keys
	lda spr_en
	ora #$03
	sta spr_en
	sta $d015
	sec
	lda muzzle_ms_l
	sbc dt_ms
	sta muzzle_ms_l
	lda muzzle_ms_h
	sbc #0
	sta muzzle_ms_h
	bcs .mf_keys
	lda #0
	sta muzzle_ms_l
	sta muzzle_ms_h
	lda spr_en
	and #$fc
	sta spr_en
	sta $d015

.mf_keys
	lda key_fire
	beq .mf_up
	lda fire_rpt_l
	ora fire_rpt_h
	beq .mf_shot			; ready — fire now
	sec
	lda fire_rpt_l
	sbc dt_ms
	sta fire_rpt_l
	lda fire_rpt_h
	sbc #0
	sta fire_rpt_h
	bcs .mf_done
.mf_shot
	jsr .fire_shot
	bcs .mf_stop_rpt		; out of ammo
	lda #<FIRE_REPEAT_DELAY
	sta fire_rpt_l
	lda #>FIRE_REPEAT_DELAY
	sta fire_rpt_h
.mf_done
	rts
.mf_stop_rpt
	lda #0
	sta fire_rpt_l
	sta fire_rpt_h
	rts

.mf_up
	lda #0
	sta fire_rpt_l
	sta fire_rpt_h
	rts

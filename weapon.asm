; Weapon HUD sprites — table-driven layers + muzzle flash; switch via SMC
!zone weapon

; Contiguous banks in VIC bank 0 (see squaredoom.asm):
;   shotgun $3480: 8 sprites (own flash + 6 body)
;   pistol  $3680: 6 sprites (flash + 4 body)
PISTOL_SPR_PTR0 = PISTOL_SPRITES / 64
SHOTGUN_SPR_PTR0 = SHOTGUN_SPRITES / 64
PISTOL_ENABLE_IDLE = $3c		; sprites 2–5
SHOTGUN_ENABLE_IDLE = $fc		; sprites 2–7
MUZZLE_MS = 300

; $00 until first blit, then $ff — AND with spr_en before writing $d015
wpn_visible	!byte 0

; Per-weapon fire interval (ms while held)
wpn_fire_ms_lo
	!byte <600, <900
wpn_fire_ms_hi
	!byte >600, >900

wpn_setup_lo
	!byte <setup_pistol, <setup_shotgun
wpn_setup_hi
	!byte >setup_pistol, >setup_shotgun
wpn_damage_lo
	!byte <damage_pistol, <damage_shotgun
wpn_damage_hi
	!byte >damage_pistol, >damage_shotgun

; SMC stubs — +1/+2 patched by switch_weapon
wpn_setup
	jmp setup_pistol
wpn_damage
	jmp damage_pistol

; Per-sprite colour / X / Y (screen coords; expand already factored into offsets).
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

shotgun_spr_col
	!byte 1, 2			; flash white, red
	!byte 11			; highlight (over metal)
	!byte 0, 0, 0		; barrel / bodyleft / bodyright
	!byte 9, 8			; hand brown, orange
shotgun_spr_x
	!byte 160, 160			; flash
	!byte 160	    		; highlight
	!byte 160, 140, 188		; body
	!byte 140, 140			; hand
shotgun_spr_y
	!byte 162, 162			; flash
	!byte 208		    	; highlight
	!byte 186, 208, 208		; body
	!byte 208, 208			; hand

; X = weapon id (0=pistol, 1=shotgun). No-op if already active.
switch_weapon
	cpx cur_weapon
	beq .sw_done
	stx cur_weapon
	lda wpn_setup_lo,x
	sta wpn_setup + 1
	lda wpn_setup_hi,x
	sta wpn_setup + 2
	lda wpn_damage_lo,x
	sta wpn_damage + 1
	lda wpn_damage_hi,x
	sta wpn_damage + 2
	lda wpn_fire_ms_lo,x
	sta wpn_fire_ms_l
	lda wpn_fire_ms_hi,x
	sta wpn_fire_ms_h
	lda #0
	sta muzzle_ms_l
	sta muzzle_ms_h
	sta fire_rpt_l
	sta fire_rpt_h
	jsr wpn_setup
.sw_done
	rts

init_weapon
	lda #0
	sta wpn_visible			; hide until first render blit
	lda #$ff
	sta cur_weapon			; force setup
	ldx #0
	jmp switch_weapon

; Hide HUD weapon sprites (menus / intermission)
hide_weapon
	lda #0
	sta wpn_visible
	sta $d015
	rts

; After first blit — allow $d015 writes and enable current spr_en.
; Also refresh weapon highlight colour from player sector brightness.
show_weapon
	lda #$ff
	sta wpn_visible
	lda spr_en
	sta $d015
	ldx player_sector
	lda SEC_BRIGHT,x
	cmp #17
	bcc .sw_hi
	lda #16
.sw_hi
	tax
	lda bright_to_wpn_hi,x
	ldx cur_weapon
	bne .sw_sg
	sta $d02a			; pistol sprite 3 (weapon light)
	rts
.sw_sg
	sta $d029			; shotgun sprite 2 (highlight)
	rts

; SEC_BRIGHT 0..16 → weapon highlight C64 colour
bright_to_wpn_hi
	!byte 11,11,11,11,11		; 0–4 darkest
	!byte 12,12,12,12,12		; 5–9
	!byte 15,15,15,15,15,15		; 10–15 lightest grey
	!byte 1				; 16 full bright white

; A = enable mask → spr_en; $d015 only if wpn_visible.
.wpn_en
	sta spr_en
	and wpn_visible
	sta $d015
	rts

setup_pistol
	lda #PISTOL_ENABLE_IDLE
	jsr .wpn_en
	lda #$3f			; XY expand sprites 0–5
	sta $d01d
	sta $d017
	lda #0
	sta $d01c
	sta $d010
	ldx #0
	ldy #0
.sp_set
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
	bcc .sp_set
	rts

setup_shotgun
	lda #SHOTGUN_ENABLE_IDLE
	jsr .wpn_en
	lda #$ff			; XY expand all eight
	sta $d01d
	sta $d017
	lda #0
	sta $d01c
	sta $d010
	ldx #0
	ldy #0
.ss_set
	lda shotgun_spr_col,x
	sta $d027,x
	txa
	clc
	adc #SHOTGUN_SPR_PTR0
	sta $07f8,x
	lda shotgun_spr_x,x
	sta $d000,y
	lda shotgun_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .ss_set
	rts

damage_pistol
	jsr GetRandom8
	lsr
	lsr
	lsr
	lsr
	clc
	adc #1
	jmp TryDamageEnemy

damage_shotgun
	jsr GetRandom8
	lsr
	lsr
	lsr
	clc
	adc #3
	jmp TryDamageEnemy

; Spend 1 ammo, show muzzle flash, damage via SMC. C=0 ok, C=1 no ammo.
.fire_shot
	lda ammo
	beq .fs_empty
	sec
	sbc #1
	sta ammo
	lda #1
	sta hud_dirty
	lda #<MUZZLE_MS
	sta muzzle_ms_l
	lda #>MUZZLE_MS
	sta muzzle_ms_h
	lda spr_en
	ora #$03
	jsr .wpn_en
	lda cur_weapon
	bne .fs_sg
	lda #SOUND_PISTOL
	bne .fs_snd
.fs_sg
	lda #SOUND_SHOTGN
.fs_snd
	jsr play_sound
	jsr wpn_damage
	clc
	rts
.fs_empty
	lda #SOUND_OOF
	jsr play_sound
	sec
	rts

; Call once per frame after render (COL_AIM_* set in render_items).
; While SPACE held: fire when fire_rpt is 0, then wait wpn_fire_ms.
; Note: $d015 is write-only — use spr_en mirror; gated by wpn_visible.
update_muzzle_flash
	; --- muzzle flash sprite timeout ---
	lda muzzle_ms_l
	ora muzzle_ms_h
	beq .mf_keys
	lda spr_en
	ora #$03
	jsr .wpn_en
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
	jsr .wpn_en

.mf_keys
	lda key_fire
	beq .mf_up
	lda fire_rpt_l
	ora fire_rpt_h
	beq .mf_shot
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
	bcs .mf_stop_rpt
	lda wpn_fire_ms_l
	sta fire_rpt_l
	lda wpn_fire_ms_h
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

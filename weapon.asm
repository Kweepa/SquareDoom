; Weapon HUD sprites — table-driven layers + muzzle flash; switch via SMC
!zone weapon

; Contiguous banks in VIC bank 0 (see squaredoom.asm):
;   minigun $3000: 8 sprites (flash + 2 hi + 2 light + 2 dark)
;   rocket  $3200: 8 sprites (pink flash×2 + 2 hi + 4 dark)
;   shotgun $3400: 8 sprites (own flash + 6 body)
;   pistol  $3600: 8 sprites (flash + gun×3 + hand×3)
MINIGUN_SPR_PTR0 = MINIGUN_SPRITES / 64
ROCKET_SPR_PTR0 = ROCKET_SPRITES / 64
SHOTGUN_SPR_PTR0 = SHOTGUN_SPRITES / 64
PISTOL_SPR_PTR0 = PISTOL_SPRITES / 64
EIGHT_ENABLE_IDLE = $fc		; sprites 2–7 (all HUD weapons)
MUZZLE_MS = 300

; Screen layout (XY expand): sprite px ×2.
; Bottom dark/hand row Y=208; adjacent X = 112 / 160; centred hi X = 136.
; Pistol gun = hand − 22 (11 sprite px); minigun light/hi top = dark − 14;
; rocket top row = dark − 28; rocket pink flash = body top − 18.

; $00 until first blit, then $ff — AND with spr_en before writing $d015
wpn_visible	!byte 0

; Per-weapon fire interval (ms while held)
wpn_fire_ms_lo
	!byte <600, <900, <100, <1200
wpn_fire_ms_hi
	!byte >600, >900, >100, >1200

wpn_setup_lo
	!byte <setup_pistol, <setup_shotgun, <setup_minigun, <setup_rocket
wpn_setup_hi
	!byte >setup_pistol, >setup_shotgun, >setup_minigun, >setup_rocket
wpn_damage_lo
	!byte <damage_pistol, <damage_shotgun, <damage_minigun, <damage_rocket
wpn_damage_hi
	!byte >damage_pistol, >damage_shotgun, >damage_minigun, >damage_rocket

; SMC stubs — +1/+2 patched by switch_weapon
wpn_setup
	jmp setup_pistol
wpn_damage
	jmp damage_pistol

; Per-sprite colour / X / Y (screen coords; expand already factored into offsets).
pistol_spr_col
	!byte 1, 2			; flash white, red
	!byte 15, 11, 0		; gun hilight / dark grey / black
	!byte 8, 9, 0		; hand orange / brown / black
pistol_spr_x
	!byte 166, 166			; flash (+6 from body)
	!byte 160, 160, 160		; gun
	!byte 160, 160, 160		; hand
pistol_spr_y
	!byte 162, 162			; flash (gun Y − 24)
	!byte 186, 186, 186		; gun (hand Y − 22)
	!byte 208, 208, 208		; hand (bottom centre)

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

minigun_spr_col
	!byte 1, 2			; flash white, red
	!byte 15, 15			; highlights (brightness-updated)
	!byte 11, 11			; light grey body
	!byte 0, 0   			; dark grey body
minigun_spr_x
	!byte 160, 160			; flash
	!byte 160, 160			; hi top / bot (centred)
	!byte 136, 184			; light L / R
	!byte 136, 184			; dark L / R
minigun_spr_y
	!byte 162, 162			; flash
	!byte 194, 208			; hi top / bot
	!byte 194, 194			; light (+7 sprite px above dark)
	!byte 208, 208			; dark

rocket_spr_col
	!byte 10, 10			; pink flash (Pepto light red)
	!byte 15, 15			; highlights (brightness-updated)
	!byte 0, 0, 0, 0		; dark 2×2
rocket_spr_x
	!byte 136, 184			; flash L / R (side by side)
	!byte 160, 160			; hi top / bot (centred)
	!byte 136, 184			; dark TL / TR
	!byte 136, 184			; dark BL / BR
rocket_spr_y
	!byte 162, 162			; flash (+9 sprite px above body top)
	!byte 180, 208			; hi top / bot
	!byte 180, 180			; dark TL / TR (dy=14 sprite px)
	!byte 208, 208			; dark BL / BR

; X = weapon id (0=pistol, 1=shotgun, 2=minigun, 3=rocket). No-op if already active.
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
	jmp .wpn_hi_bright		; match sector brightness this frame
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
	; fall through
; SEC_BRIGHT → highlight colour on the active weapon's hi sprite(s).
.wpn_hi_bright
	ldx player_sector
	lda SEC_BRIGHT,x
	cmp #17
	bcc .wh_ok
	lda #16
.wh_ok
	tax
	lda bright_to_wpn_hi,x
	ldx cur_weapon
	beq .wh_pistol
	cpx #1
	beq .wh_sg
	; minigun / rocket: sprites 2–3 are highlights
	sta $d029
	sta $d02a
	rts
.wh_pistol
	sta $d029			; pistol sprite 2 (gun highlight)
	rts
.wh_sg
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

; ------------------------------------------------------------------
; Shared 8-sprite setup: A = ptr0, col/x/y tables via (ptr)
; ------------------------------------------------------------------
setup_pistol
	lda #EIGHT_ENABLE_IDLE
	jsr .wpn_en
	lda #$ff			; XY expand all eight
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
	cpx #8
	bcc .sp_set
	rts

setup_shotgun
	lda #EIGHT_ENABLE_IDLE
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

setup_minigun
	lda #EIGHT_ENABLE_IDLE
	jsr .wpn_en
	lda #$ff
	sta $d01d
	sta $d017
	lda #0
	sta $d01c
	sta $d010
	ldx #0
	ldy #0
.sm_set
	lda minigun_spr_col,x
	sta $d027,x
	txa
	clc
	adc #MINIGUN_SPR_PTR0
	sta $07f8,x
	lda minigun_spr_x,x
	sta $d000,y
	lda minigun_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sm_set
	rts

setup_rocket
	lda #EIGHT_ENABLE_IDLE
	jsr .wpn_en
	lda #$ff
	sta $d01d
	sta $d017
	lda #0
	sta $d01c
	sta $d010
	ldx #0
	ldy #0
.sr_set
	lda rocket_spr_col,x
	sta $d027,x
	txa
	clc
	adc #ROCKET_SPR_PTR0
	sta $07f8,x
	lda rocket_spr_x,x
	sta $d000,y
	lda rocket_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sr_set
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

damage_minigun
	jmp damage_pistol

damage_rocket
	jsr GetRandom8
	lsr
	lsr
	clc
	adc #20
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
	ldx cur_weapon
	lda wpn_sound,x
	jsr play_sound
	jsr wpn_damage
	clc
	rts
.fs_empty
	lda #SOUND_OOF
	jsr play_sound
	sec
	rts

; Fire SFX per weapon id
wpn_sound
	!byte SOUND_PISTOL, SOUND_SHOTGN, SOUND_PISTOL, SOUND_SHOTGN

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
	bcc .mf_expired		; underflow
	ora muzzle_ms_l		; A = hi
	bne .mf_keys		; still > 0
.mf_expired
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

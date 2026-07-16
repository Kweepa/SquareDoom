; Weapon HUD sprites — pistol layers + muzzle flash
!zone weapon

; Six hi-res layers @ $3680–$37FF, double-size:
;   sprites 0–1 = muzzle flash (white/red, highest priority)
;   sprites 2–5 = weapon+hand
PISTOL_SPR_PTR0 = PISTOL_SPRITES / 64	; $da
PISTOL_SPR_X = 160			; left edge; 48px wide → centred on 160
PISTOL_SPR_Y = 208			; bottom of view with Y-expand (42px)
; Flash offset: 4px left / 14px up in sprite space → 8 / 28 screen px when expanded
FLASH_SPR_X = PISTOL_SPR_X + 6
FLASH_SPR_Y = PISTOL_SPR_Y - 24
MUZZLE_MS = 300
FIRE_REPEAT_DELAY = 600		; ms hold before autorepeat / between shots

init_pistol_sprites
	lda #$3c
	sta spr_en
	sta $d015			; enable weapon sprites 2–5 (flash off)
	lda #$3f
	sta $d01d			; expand X (all six)
	sta $d017			; expand Y
	lda #0
	sta $d01c			; hi-res (not multicolour)
	sta $d010			; X MSB clear (X < 256)
	sta muzzle_ms_l
	sta muzzle_ms_h
	sta fire_rpt_l
	sta fire_rpt_h

	lda #1
	sta $d027			; sprite 0 = white (flash)
	lda #2
	sta $d028			; sprite 1 = red (flash)
	lda #0
	sta $d029			; sprite 2 = black
	lda #11
	sta $d02a			; sprite 3 = dark grey
	lda #9
	sta $d02b			; sprite 4 = brown
	lda #8
	sta $d02c			; sprite 5 = orange

	ldx #0
.setptr
	txa
	clc
	adc #PISTOL_SPR_PTR0
	sta $07f8,x
	inx
	cpx #6
	bcc .setptr

	; Flash at offset (sprites 0–1)
	lda #FLASH_SPR_X
	sta $d000
	sta $d002
	lda #FLASH_SPR_Y
	sta $d001
	sta $d003
	; Weapon (sprites 2–5)
	ldx #0
.pos
	lda #PISTOL_SPR_X
	sta $d004,x			; X
	lda #PISTOL_SPR_Y
	sta $d005,x			; Y
	inx
	inx
	cpx #8
	bcc .pos
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

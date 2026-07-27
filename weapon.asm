; Weapon HUD sprites — table-driven layers + muzzle flash; switch via SMC
!zone weapon

; Contiguous banks in VIC bank 0 (see squaredoom.asm):
;   fist right $2a00 / punch $2c00: 7 layers + pad each
;   chainsaw hi2 $2dc0 (punch pad); body $2e00: 8 sprites (no flash)
;   minigun  $3000: 6 body; rocket $3180: 8 (pink flash); shotgun $3380: 6
;   pistol   $3500: 6 body; shared muzzle $3680: flash A/B white+red (sprites 6–7)
FIST_RIGHT_SPR_PTR0 = FIST_RIGHT_SPRITES / 64
FIST_PUNCH_SPR_PTR0 = FIST_PUNCH_SPRITES / 64
CHAINSAW_BLADE_HI2_PTR = CHAINSAW_BLADE_HI2_SPRITES / 64
CHAINSAW_SPR_PTR0 = CHAINSAW_SPRITES / 64
MINIGUN_SPR_PTR0 = MINIGUN_SPRITES / 64
ROCKET_SPR_PTR0 = ROCKET_SPRITES / 64
SHOTGUN_SPR_PTR0 = SHOTGUN_SPRITES / 64
PISTOL_SPR_PTR0 = PISTOL_SPRITES / 64
MUZZLE_FLASH_PTR0 = MUZZLE_FLASH_SPRITES / 64
EIGHT_ENABLE_IDLE = $3f		; sprites 0–5 (body; flash 6–7 off)
EIGHT_ENABLE_ALL = $ff		; all eight (chainsaw)
FIST_ENABLE = $7f			; sprites 0–6 (hand layers)
FLASH_ENABLE = $c0			; sprites 6–7
MUZZLE_MS = 300
PUNCH_MS = 350				; fist punch pose duration

; Screen layout (XY expand): sprite px ×2.
; Bottom dark/hand row Y=208; adjacent X = 112 / 160; centred hi X = 136.
; Pistol gun = hand − 22 (11 sprite px); minigun light/hi top = dark − 14;
; rocket top row = dark − 28; rocket pink flash = body top − 18.
; VIC: low sprite # = front — body first, muzzle flash last (under gun/hand).

; $00 until first blit, then $ff — AND with spr_en before writing $d015
wpn_visible	!byte 0
; Gun highlight while muzzle flash is up (picked per shot)
muzzle_hi_col	!byte 1
muzzle_hi_cycle !byte 0
muzzle_flash_var !byte 0		; bit0: 0=flash A, 1=flash B (shared pistol/sg/mg)
saw_blade_frame	!byte 0			; 0=hi, 1=hi2
saw_blade_div	!byte 0			; IRQ tick; toggle every 4th (100 ms)
saw_running	!byte 0			; 1 = fire held: Y+4 + blade anim
muzzle_hi_cols
	!byte 1, 7, 1, 10		; some bright colours

; Per-weapon fire interval (ms while held) — fist, saw, pistol, sg, mg, rocket
wpn_fire_ms_lo
	!byte <800, <100, <600, <900, <100, <1200
wpn_fire_ms_hi
	!byte >800, >100, >600, >900, >100, >1200

wpn_setup_lo
	!byte <setup_fist, <setup_chainsaw, <setup_pistol, <setup_shotgun
	!byte <setup_minigun, <setup_rocket
wpn_setup_hi
	!byte >setup_fist, >setup_chainsaw, >setup_pistol, >setup_shotgun
	!byte >setup_minigun, >setup_rocket
wpn_damage_lo
	!byte <damage_fist, <damage_chainsaw, <damage_pistol, <damage_shotgun
	!byte <damage_pistol, <spawn_player_rocket
wpn_damage_hi
	!byte >damage_fist, >damage_chainsaw, >damage_pistol, >damage_shotgun
	!byte >damage_pistol, >spawn_player_rocket

; SMC stubs — +1/+2 patched by switch_weapon
wpn_setup
	jmp setup_pistol
wpn_damage
	jmp damage_pistol

; Per-sprite colour / X / Y (screen coords; expand already factored into offsets).
; Order = VIC sprites 0–7: body first (front), flash last (behind).
pistol_spr_col
	!byte 15, 11, 0		; gun hilight / dark grey / black
	!byte 8, 9, 0		; hand orange / brown / black
	!byte 1, 2			; flash white, red
pistol_spr_x
	!byte 160, 160, 160		; gun
	!byte 160, 160, 160		; hand
	!byte 166, 166			; flash (+6 from body)
pistol_spr_y
	!byte 186, 186, 186		; gun (hand Y − 22)
	!byte 208, 208, 208		; hand (bottom centre)
	!byte 162, 162			; flash (gun Y − 24)

shotgun_spr_col
	!byte 11			; highlight (over metal)
	!byte 0, 0, 0		; barrel / bodyleft / bodyright
	!byte 9, 8			; hand brown, orange
	!byte 1, 2			; flash white, red
shotgun_spr_x
	!byte 160	    		; highlight
	!byte 160, 140, 188		; body
	!byte 140, 140			; hand
	!byte 160, 160			; flash
shotgun_spr_y
	!byte 208		    	; highlight
	!byte 186, 208, 208		; body
	!byte 208, 208			; hand
	!byte 162, 162			; flash

minigun_spr_col
	!byte 15, 15			; highlights (brightness-updated)
	!byte 11, 11			; light grey body
	!byte 0, 0   			; dark grey body
	!byte 1, 2			; flash white, red
minigun_spr_x
	!byte 160, 160			; hi top / bot (centred)
	!byte 136, 184			; light L / R
	!byte 136, 184			; dark L / R
	!byte 160, 160			; flash
minigun_spr_y
	!byte 194, 208			; hi top / bot
	!byte 194, 194			; light (+7 sprite px above dark)
	!byte 208, 208			; dark
	!byte 166, 166			; flash

rocket_spr_col
	!byte 15, 11			; hi (brightness-updated) / detail dark grey
	!byte 0, 0, 0, 0		; dark 2×2
	!byte 10, 10			; pink flash (Pepto light red)
rocket_spr_x
	!byte 160, 160			; hi / detail (centred)
	!byte 136, 184			; dark TL / TR
	!byte 136, 184			; dark BL / BR
	!byte 136, 184			; flash L / R (side by side)
rocket_spr_y
	!byte 180, 208			; hi / detail
	!byte 180, 180			; dark TL / TR (dy=14 sprite px)
	!byte 208, 208			; dark BL / BR
	!byte 162, 162			; flash (+9 sprite px above body top)

; Chainsaw: blade hi, detail, hands, blade dark, body L/M/R — no flash
; Blade crop x=31 (was 48): screen X −34. Detail crop y=19 (was 20): Y −2.
chainsaw_spr_col
	!byte 1, 11			; blade hi white / grey detail
	!byte 8, 9			; hand orange / brown
	!byte 0				; blade dark
	!byte 0, 0, 0			; body L/M/R
chainsaw_spr_x
	!byte 174, 182			; blade hi / detail
	!byte 112, 112			; hands
	!byte 174			; blade dark
	!byte 112, 160, 208		; body L/M/R
chainsaw_spr_y
	!byte 168, 206			; blade hi / detail
	!byte 208, 208			; hands
	!byte 168			; blade dark
	!byte 208, 208, 208		; body

; Fist open right hand / punch — grey hi, light×3, dark×3 (+ pad unused)
; Idle: right side. Punch: right tile center at mid-screen (~184).
; Tile X step matches PNG crops 0/16/33 (*2 expand = +32/+34)
fist_spr_col
	!byte 15			; grey highlight
	!byte 8, 8, 8		; light
	!byte 9, 9, 9			; dark
	!byte 0				; pad
fist_spr_x
	!byte 226			; hi (right tile)
	!byte 160, 192, 226		; pink L/M/R
	!byte 160, 192, 226		; dark L/M/R
	!byte 0				; pad
; Punch: R=160 so mid of right sprite (160+24) ≈ screen center
fist_punch_spr_x
	!byte 160			; hi (right tile)
	!byte 94, 126, 160		; pink L/M/R
	!byte 94, 126, 160		; dark L/M/R
	!byte 0				; pad
fist_spr_y
	!byte 208
	!byte 208, 208, 208
	!byte 208, 208, 208
	!byte 208

; X = weapon id (0=fist … 5=rocket). Gated by owned_weapons (fist always ok).
switch_weapon
	cpx #0
	beq .sw_ok			; fist always
	lda wpn_own_bit,x
	bit owned_weapons
	beq .sw_done			; not owned
.sw_ok
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
	lda #1
	sta hud_dirty
	jsr wpn_setup
	jmp .wpn_hi_bright
.sw_done
	rts

init_weapon
	lda #0
	sta wpn_visible			; hide until first render blit
	lda #$02
	sta owned_weapons		; pistol until init_hud_state (level start)
	lda #$ff
	sta cur_weapon			; force setup
	ldx #2				; pistol
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
	lda health
	beq hide_weapon			; death / pre-start: keep sprites off
	lda #$ff
	sta wpn_visible
	lda spr_en
	sta $d015
	; fall through
; Highlight colour: random muzzle tint while flash is up, else SEC_BRIGHT mapping.
.wpn_hi_bright
	lda muzzle_ms_l
	ora muzzle_ms_h
	beq .wh_sector
	lda muzzle_hi_col
	bne .wh_apply
.wh_sector
	ldx player_sector
	lda SEC_BRIGHT,x
	cmp #17
	bcc .wh_ok
	lda #16
.wh_ok
	tax
	lda bright_to_wpn_hi,x
.wh_apply
	sta $d027
	ldx cur_weapon
	cpx #4
	bne .wh_rts
	sta $d028
.wh_rts
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
setup_fist
	lda #FIST_RIGHT_SPR_PTR0
	ldx #0				; idle X table
	beq .fist_apply

; Punch pose — replaces open right hand for PUNCH_MS
setup_fist_punch
	lda #FIST_PUNCH_SPR_PTR0
	ldx #1				; punch X table (further left)
	; fall through
.fist_apply
	sta tmp0			; sprite pointer base
	stx tmp1			; 0=idle X, 1=punch X
	lda #FIST_ENABLE
	jsr .wpn_en
	lda #$ff
	sta $d01d
	sta $d017
	lda #0
	sta $d01c
	sta $d010
	ldx #0
	ldy #0
	clc
.sf_set
	lda fist_spr_col,x
	sta $d027,x
	txa
	adc tmp0
	sta $07f8,x
	lda tmp1
	bne .sf_punch_x
	lda fist_spr_x,x
	jmp .sf_got_x
.sf_punch_x
	lda fist_punch_spr_x,x
.sf_got_x
	sta $d000,y
	lda fist_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sf_set
	rts

setup_chainsaw
	lda #0
	sta saw_running
	sta saw_blade_frame
	sta saw_blade_div
	lda #EIGHT_ENABLE_ALL
	jsr .wpn_en
	lda #$ff
	sta $d01d
	sta $d017
	lda #0
	sta $d01c
	sta $d010
	ldx #0
	ldy #0
	clc
.sc_set
	lda chainsaw_spr_col,x
	sta $d027,x
	txa
	adc #CHAINSAW_SPR_PTR0
	sta $07f8,x
	lda chainsaw_spr_x,x
	sta $d000,y
	lda chainsaw_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sc_set
	rts

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
	clc
.sp_set
	lda pistol_spr_col,x
	sta $d027,x
	cpx #6
	bcs .sp_xy			; flash ptrs via .set_muzzle_ptrs
	txa
	adc #PISTOL_SPR_PTR0
	sta $07f8,x
.sp_xy
	lda pistol_spr_x,x
	sta $d000,y
	lda pistol_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sp_set
	jmp .set_muzzle_ptrs

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
	clc
.ss_set
	lda shotgun_spr_col,x
	sta $d027,x
	cpx #6
	bcs .ss_xy
	txa
	adc #SHOTGUN_SPR_PTR0
	sta $07f8,x
.ss_xy
	lda shotgun_spr_x,x
	sta $d000,y
	lda shotgun_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .ss_set
	jmp .set_muzzle_ptrs

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
	clc
.sm_set
	lda minigun_spr_col,x
	sta $d027,x
	cpx #6
	bcs .sm_xy
	txa
	adc #MINIGUN_SPR_PTR0
	sta $07f8,x
.sm_xy
	lda minigun_spr_x,x
	sta $d000,y
	lda minigun_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sm_set
	jmp .set_muzzle_ptrs

; Shared muzzle A/B → VIC sprites 6–7 (pistol / shotgun / minigun).
; muzzle_flash_var bit0: 0 → A (ptr0+0/+1), 1 → B (ptr0+2/+3).
.set_muzzle_ptrs
	lda muzzle_flash_var
	and #1
	asl				; ×2 → 0 or 2
	adc #MUZZLE_FLASH_PTR0
	sta $07fe			; sprite 6 white
	adc #1
	sta $07ff			; sprite 7 red
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
	clc
.sr_set
	lda rocket_spr_col,x
	sta $d027,x
	txa
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

; Fist / chainsaw: pistol-scale damage, but only in MELEERANGE (COL_AIM_Z).
; Chainsaw adds pain_boost so hits flinch more often (same dmg, faster fire).
damage_fist
	lda #0
	sta pain_boost
	beq .dmg_melee
damage_chainsaw
	lda #10				; bias past typical mobj_pain_chance
	sta pain_boost
.dmg_melee
	jsr GetRandom8
	lsr
	lsr
	lsr
	lsr
	clc
	adc #1				; 1..16, same as pistol
	jsr TryDamageMelee
	lda #0
	sta pain_boost
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

; Spend 1 ammo from the active weapon's reserve, show muzzle flash, damage via SMC.
; C=0 ok, C=1 no ammo (or rocket slot busy). Melee (0/1) skips ammo/flash.
.fire_shot
	ldx cur_weapon
	cpx #2
	bcc .fs_melee
	cpx #5				; rocket — need free projectile slot
	bne .fs_ammo
	lda MOBJ_ALLOC + MOBJ_PLAYER_ROCKET
	bne .fs_empty
.fs_ammo
	ldx cur_weapon
	lda wpn_ammo_idx,x
	tay
	lda ammo_bullets,y
	beq .fs_empty
	sec
	sbc #1
	sta ammo_bullets,y
	lda #1
	sta hud_dirty
	lda #<MUZZLE_MS
	sta muzzle_ms_l
	lda #>MUZZLE_MS
	sta muzzle_ms_h
	ldx cur_weapon
	cpx #5				; rocket: own flash, no A/B toggle
	beq .fs_flash_en
	jsr .set_muzzle_ptrs		; current A/B (start at A)
	inc muzzle_flash_var		; next shot flips
.fs_flash_en
	lda spr_en
	ora #FLASH_ENABLE
	jsr .wpn_en
	inc muzzle_hi_cycle
	lda muzzle_hi_cycle
	and #3
	tax
	lda muzzle_hi_cols,x
	sta muzzle_hi_col
	jsr .wpn_hi_bright
	ldx cur_weapon
	lda wpn_sound,x
	jsr play_sound
	jsr wpn_damage
	clc
	rts
.fs_melee
	ldx cur_weapon
	bne .fs_melee_saw
	; fist — show punch pose for PUNCH_MS (replaces open right hand)
	lda #<PUNCH_MS
	sta muzzle_ms_l
	lda #>PUNCH_MS
	sta muzzle_ms_h
	jsr setup_fist_punch
	jsr .wpn_hi_bright
.fs_melee_saw
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

; Fire SFX per weapon id (fist, saw, pistol, sg, mg, rocket)
wpn_sound
	!byte SOUND_PUNCH, SOUND_SAWFUL, SOUND_PISTOL, SOUND_SHOTGN, SOUND_PISTOL, SOUND_SHOTGN

; Call once per frame after render (COL_AIM_* set in render_items).
; While SPACE held: fire when fire_rpt is 0, then wait wpn_fire_ms.
; Note: $d015 is write-only — use spr_en mirror; gated by wpn_visible.
update_muzzle_flash
	; --- muzzle flash / fist-punch timeout ---
	lda muzzle_ms_l
	ora muzzle_ms_h
	beq .mf_keys
	ldx cur_weapon
	beq .mf_tick			; fist punch: no flash OR
	lda spr_en
	ora #FLASH_ENABLE
	jsr .wpn_en
.mf_tick
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
	; restore idle weapon pose (fist → open hand; guns → flash off)
	jsr wpn_setup
	jsr .wpn_hi_bright

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
.mf_up
	lda #0
	sta fire_rpt_l
	sta fire_rpt_h
	rts

; Called from input_irq (Timer A, every SAMPLE_MS). Chainsaw + SPACE:
; drop sprites +4 and flip blade hi/hi2 every 4th tick (~100 ms).
SAW_RUN_DY = 8

update_saw_blade
	lda cur_weapon
	cmp #1
	bne .usb_idle
	lda #$7f
	sta $dc00
	lda $dc01
	and #$10				; SPACE
	bne .usb_idle			; not held
	lda saw_running
	bne .usb_anim
	lda #1
	sta saw_running
	jsr .saw_set_y_run
.usb_anim
	inc saw_blade_div
	lda saw_blade_div
	and #3
	bne .usb_rts
	lda saw_blade_frame
	eor #1
	sta saw_blade_frame
	beq .usb_hi
	lda #CHAINSAW_BLADE_HI2_PTR
	sta $07f8
	rts
.usb_hi
	lda #CHAINSAW_SPR_PTR0
	sta $07f8
.usb_rts
	rts
.usb_idle
	lda #0
	sta saw_blade_frame
	sta saw_blade_div
	lda saw_running
	beq .usb_idle_ptr
	lda #0
	sta saw_running
	jsr .saw_set_y_idle
.usb_idle_ptr
	lda cur_weapon
	cmp #1
	bne .usb_rts
	lda #CHAINSAW_SPR_PTR0
	sta $07f8
	rts

; Y = chainsaw_spr_y[i] (+ SAW_RUN_DY if run)
.saw_set_y_run
	ldx #0
	ldy #0
.ssyr
	lda chainsaw_spr_y,x
	clc
	adc #SAW_RUN_DY
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .ssyr
	rts

.saw_set_y_idle
	ldx #0
	ldy #0
.ssyi
	lda chainsaw_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .ssyi
	rts

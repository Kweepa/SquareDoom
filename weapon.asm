; Weapon HUD sprites — table-driven layers + muzzle flash; switch via SMC
!zone weapon

; Contiguous banks in VIC bank 3 (see mem_vic.asm):
;   minigun B $C800: 3 alt; fist right / punch; chainsaw; minigun A;
;   rocket / shotgun / pistol / muzzle; cock. Sprite pointers at SPR_PTR ($C7F8).
FIST_RIGHT_SPR_PTR0 = <(FIST_RIGHT_SPRITES / 64)
FIST_PUNCH_SPR_PTR0 = <(FIST_PUNCH_SPRITES / 64)
CHAINSAW_BLADE_HI2_PTR = <(CHAINSAW_BLADE_HI2_SPRITES / 64)
CHAINSAW_SPR_PTR0 = <(CHAINSAW_SPRITES / 64)
MINIGUN_B_SPR_PTR0 = <(MINIGUN_B_SPRITES / 64)
MINIGUN_SPR_PTR0 = <(MINIGUN_SPRITES / 64)
ROCKET_SPR_PTR0 = <(ROCKET_SPRITES / 64)
SHOTGUN_SPR_PTR0 = <(SHOTGUN_SPRITES / 64)
SHOTGUN_COCK_SPR_PTR0 = <(SHOTGUN_COCK_SPRITES / 64)
PISTOL_SPR_PTR0 = <(PISTOL_SPRITES / 64)
MUZZLE_FLASH_PTR0 = <(MUZZLE_FLASH_SPRITES / 64)
EIGHT_ENABLE_IDLE = $3f		; sprites 0–5 (body; flash 6–7 off)
EIGHT_ENABLE_ALL = $ff		; all eight (chainsaw)
FIST_ENABLE = $7f			; sprites 0–6 (hand layers)
FLASH_ENABLE = $c0			; sprites 6–7

; HUD poses / 50 Hz ticks (Timer A SAMPLE_MS = 20)
POSE_IDLE = 0
POSE_FIRE = 1
POSE_RECOIL = 2
POSE_COCK = 3
FLASH_TICKS = 15			; 300 ms
PUNCH_TICKS = 18			; 360 ms (~350)
PISTOL_FIRE_TICKS = 15			; 300 ms
PISTOL_RECOIL_TICKS = 8			; 160 ms (~150)
SG_COCK_TICKS = 30			; 600 ms
SAW_RUN_DY = 8
PISTOL_FIRE_DY = $fc			; −4
PISTOL_RECOIL_DY = $fa			; −6

; Screen layout (XY expand): sprite px ×2.
; Bottom dark/hand row Y=208; adjacent X = 112 / 160; centred hi X = 136.
; Pistol idle is +6 vs that flush so recoil (−6) still covers the bottom of the screen.
; Pistol gun = hand − 22 (11 sprite px); minigun light/hi top = dark − 14;
; rocket top row = dark − 28; rocket pink flash = body top − 18.
; VIC: low sprite # = front — body first, muzzle flash last (under gun/hand).

; $00 until first blit, then $ff — AND with spr_en before writing $d015
; wpn_visible / muzzle_hi_cycle / muzzle_flash_var / saw_* / mg_frame
; → under-stack scrap (zeropage.asm)
muzzle_hi_col	!byte 1			; gun highlight while muzzle flash is up
muzzle_hi_cols
	!byte 1, 7, 1, 10		; some bright colours

; Per-weapon fire interval (50 Hz ticks while held) — fist, saw, pistol, sg, mg, rocket
wpn_fire_ticks_tab
	!byte 40, 5, 30, 45, 5, 60

; Rocket grenade recoil (Quake64), Y down, 1/2/2 ticks
recoil_gren_dy
	!byte 24, 16, 8
recoil_gren_ticks
	!byte 1, 2, 2

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
	!byte 192, 192, 192		; gun (hand Y − 22)
	!byte 214, 214, 214		; hand (idle +6 so recoil covers flush)
	!byte 168, 168			; flash (gun Y − 24)

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

; Cock pose: 6 layers, stacked blacks (hi+42=lo), no flash, 2× expand
; Layer order (low VIC# = front): black_hi, black_lo, grey, highlight, brown, orange
shotgun_cock_col
	!byte 0, 0			; black top / black bottom
	!byte 11			; dark grey detail (top)
	!byte 15			; highlight (bottom)
	!byte 9, 8			; hand brown / orange
shotgun_cock_x
	!byte 100, 100			; black layers
	!byte 100			; grey
	!byte 100			; highlight
	!byte 100, 100			; hand
shotgun_cock_y
	!byte 166, 208			; black hi / lo (stacked)
	!byte 166			; grey (top half)
	!byte 208			; highlight (bottom half)
	!byte 186, 184			; brown rows 10–30; orange rows 9–29

minigun_spr_col
	!byte 15, 15			; upper / lower highlights (brightness-updated)
	!byte 11, 11			; grey body L/R
	!byte 0, 0   			; black body L/R
	!byte 1, 2			; flash white, red
minigun_spr_x
	!byte 160, 160			; upper / lower hi (centred)
	!byte 136, 184			; grey L / R
	!byte 136, 184			; black L / R
	!byte 160, 160			; flash
minigun_spr_y
	!byte 194, 208			; upper / lower hi
	!byte 194, 194			; grey (+7 sprite px above black)
	!byte 208, 208			; black
	!byte 172, 172			; flash

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
	lda #0
	sta wpn_pose
	sta wpn_off_y
	sta wpn_pose_ticks
	sta wpn_flash_ticks
	sta wpn_fire_ticks
	sta recoil_step
	sta wpn_shot_req
	lda #1
	sta hud_dirty
	php
	sei				; lock out 50 Hz HUD writer
	jsr wpn_setup
	jsr .wpn_hi_bright
	plp
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
	jsr io_push
	lda #0
	sta $d015
	jmp io_pop

; After first blit — allow $d015 writes and enable current spr_en.
; Also refresh weapon highlight colour from player sector brightness.
show_weapon
	lda health
	beq hide_weapon			; death / pre-start: keep sprites off
	lda #$ff
	sta wpn_visible
	jsr io_push
	lda spr_en
	sta $d015
	jsr io_pop
	jmp .wpn_hi_bright
; Highlight colour: random muzzle tint while flash ticks remain, else SEC_BRIGHT.
; Skip while shotgun cock pose is up (sprite 0 is black base, not highlight).
.wpn_hi_bright
	jsr io_push
	jsr .wpn_hi_direct
	jmp io_pop

; I/O already mapped. No tmp*.
.wpn_hi_direct
	lda wpn_pose
	cmp #POSE_COCK
	beq .wh_rts
	lda wpn_flash_ticks
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
	jsr io_push
	lda spr_en
	and wpn_visible
	sta $d015
	jmp io_pop

; A = enable mask. I/O already in (IRQ).
.wpn_en_irq
	sta spr_en
	and wpn_visible
	sta $d015
	rts

; ------------------------------------------------------------------
; Shared 8-sprite setup: A = ptr0, col/x/y tables via (ptr)
; ------------------------------------------------------------------
setup_fist
	jsr io_push
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
	adc #FIST_RIGHT_SPR_PTR0
	sta SPR_PTR,x
	lda fist_spr_x,x
	sta $d000,y
	lda fist_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sf_set
	jmp io_pop

setup_chainsaw
	jsr io_push
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
	sta SPR_PTR,x
	lda chainsaw_spr_x,x
	sta $d000,y
	lda chainsaw_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sc_set
	jmp io_pop

setup_pistol
	jsr io_push
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
	sta SPR_PTR,x
.sp_xy
	lda pistol_spr_x,x
	sta $d000,y
	lda pistol_spr_y,x
	clc
	adc wpn_off_y
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sp_set
	jsr .set_muzzle_ptrs
	jmp io_pop

setup_shotgun
	jsr io_push
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
	sta SPR_PTR,x
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
	jsr .set_muzzle_ptrs
	jmp io_pop

; Show shotgun cock pose — sprites 0–5 from SHOTGUN_COCK area, flash off.
; Cock pose: 6 layers, stacked blacks (hi+42=lo), no flash, 2× expand
setup_shotgun_cock
	jsr io_push
	lda #EIGHT_ENABLE_IDLE		; sprites 0–5 on, 6–7 off
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
.ssc_set
	lda shotgun_cock_col,x
	sta $d027,x
	txa
	adc #SHOTGUN_COCK_SPR_PTR0
	sta SPR_PTR,x
	lda shotgun_cock_x,x
	sta $d000,y
	lda shotgun_cock_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #6
	bcc .ssc_set
	jmp io_pop

setup_minigun
	jsr io_push
	lda #0
	sta mg_frame
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
	sta SPR_PTR,x
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
	jsr .set_muzzle_ptrs
	jmp io_pop

; Shared muzzle A/B → VIC sprites 6–7 (pistol / shotgun / minigun).
; muzzle_flash_var bit0: 0 → A (ptr0+0/+1), 1 → B (ptr0+2/+3).
.set_muzzle_ptrs
	lda muzzle_flash_var
	and #1
	asl				; ×2 → 0 or 2
	adc #MUZZLE_FLASH_PTR0
	sta SPR_PTR+6			; sprite 6 white
	adc #1
	sta SPR_PTR+7			; sprite 7 red
	rts

; Minigun body A/B → VIC 0 (upper), 2–3 (grey L/R). Shared 1/4/5 unchanged.
.set_minigun_frame_ptrs
	lda mg_frame
	bne .smfp_b
	lda #MINIGUN_SPR_PTR0		; A upper
	sta SPR_PTR
	lda #MINIGUN_SPR_PTR0 + 2	; A grey L
	sta SPR_PTR+2
	lda #MINIGUN_SPR_PTR0 + 3	; A grey R
	sta SPR_PTR+3
	rts
.smfp_b
	lda #MINIGUN_B_SPR_PTR0		; B upper
	sta SPR_PTR
	lda #MINIGUN_B_SPR_PTR0 + 1	; B grey L
	sta SPR_PTR+2
	lda #MINIGUN_B_SPR_PTR0 + 2	; B grey R
	sta SPR_PTR+3
	rts

setup_rocket
	jsr io_push
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
	sta SPR_PTR,x
	lda rocket_spr_x,x
	sta $d000,y
	lda rocket_spr_y,x
	clc
	adc wpn_off_y
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .sr_set
	jmp io_pop

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

; 5 pellets: each picks a random column in 18..22 and applies pistol damage.
damage_shotgun
	ldy #5
.sg_pellet
	tya
	pha				; preserve pellet count across GetRandom8 / damage
	jsr GetRandom8
	and #15
.sg_reduce
	cmp #5
	bcc .sg_col
	sbc #5			; C=1 from cmp
	jmp .sg_reduce		; re-cmp (do not bcs — C stays set)
.sg_col
	clc
	adc #MUZZLE_COL - AIM_COL_SLACK	; 18
	tax
	jsr GetRandom8
	lsr
	lsr
	lsr
	lsr
	clc
	adc #1				; pistol 1..16
	jsr TryDamageAtCol
	pla
	tay
	dey
	bne .sg_pellet
	rts

; Fire SFX per weapon id (fist, saw, pistol, sg, mg, rocket)
wpn_sound
	!byte SOUND_PUNCH, SOUND_SAWFUL, SOUND_PISTOL, SOUND_SHOTGN, SOUND_PISTOL, SOUND_SHOTGN

; ------------------------------------------------------------------
; Game loop: take pending IRQ shots (COL_AIM_* valid). No HUD.
; ------------------------------------------------------------------
update_muzzle_flash
	sei
	lda wpn_shot_req
	ldx #0
	stx wpn_shot_req
	cli
	tax
	beq .uw_done
.uw_loop
	txa
	pha
	jsr .world_shot
	pla
	tax
	dex
	bne .uw_loop
.uw_done
	rts

.world_shot
	ldx cur_weapon
	cpx #2
	bcc .ws_dmg			; melee: no ammo
	lda wpn_ammo_idx,x
	tay
	lda ammo_bullets,y
	beq .ws_rts
	sec
	sbc #1
	sta ammo_bullets,y
	lda #1
	sta hud_dirty
.ws_dmg
	jmp wpn_damage
.ws_rts
	rts

; ------------------------------------------------------------------
; Timer A 50 Hz: fire gate, poses, SPR_PTR / XY / flash / SFX.
; $01 already $35. No tmp*, no io_push, no SEI/CLI.
; ------------------------------------------------------------------
update_weapon_irq
	lda wpn_visible
	beq .uwi_rts
	lda health
	beq .uwi_rts
	lda wpn_fire_ticks
	beq .uwi_space
	dec wpn_fire_ticks
.uwi_space
	lda #$7f
	sta $dc00
	lda $dc01
	and #$10			; SPACE
	bne .uwi_up
	ldx cur_weapon
	cpx #1
	bne .uwi_held
	jsr .saw_hold
.uwi_held
	jsr .irq_tick_flash
	jsr .irq_tick_pose
	lda wpn_fire_ticks
	bne .uwi_rts
	jmp .irq_try_fire
.uwi_up
	jsr .irq_fire_released
	jsr .irq_tick_flash
	jmp .irq_tick_pose
.uwi_rts
	rts

.irq_fire_released
	lda cur_weapon
	cmp #4
	bne .ifr_saw
	lda mg_frame
	beq .ifr_saw
	lda #0
	sta mg_frame
	jsr .set_minigun_frame_ptrs
.ifr_saw
	lda saw_running
	beq .ifr_rts
	lda #0
	sta saw_running
	sta saw_blade_frame
	sta saw_blade_div
	jsr .saw_set_y_idle
	lda cur_weapon
	cmp #1
	bne .ifr_rts
	lda #CHAINSAW_SPR_PTR0
	sta SPR_PTR
.ifr_rts
	rts

.irq_try_fire
	ldx cur_weapon
	cpx #2
	bcc .itf_do			; melee
	cpx #5
	bne .itf_ammo
	lda MOBJ_ALLOC + MOBJ_PLAYER_ROCKET
	bne .itf_empty
	lda wpn_shot_req
	bne .itf_empty
.itf_ammo
	lda wpn_ammo_idx,x
	tay
	lda ammo_bullets,y
	cmp wpn_shot_req
	beq .itf_empty
	bcc .itf_empty
.itf_do
	jsr .irq_start_hud
	ldx cur_weapon
	lda wpn_sound,x
	jsr play_sound
	inc wpn_shot_req
	ldx cur_weapon
	lda wpn_fire_ticks_tab,x
	sta wpn_fire_ticks
	rts
.itf_empty
	lda #SOUND_OOF
	jsr play_sound
	ldx cur_weapon
	lda wpn_fire_ticks_tab,x
	sta wpn_fire_ticks
	rts

.irq_start_hud
	ldx cur_weapon
	beq .irq_start_punch
	cpx #1
	beq .ish_rts			; saw Y from .saw_hold
	cpx #2
	beq .irq_start_pistol
	cpx #3
	beq .irq_start_shotgun
	cpx #4
	beq .irq_start_minigun
	jmp .irq_start_rocket
.ish_rts
	rts

.irq_start_punch
	lda #POSE_FIRE
	sta wpn_pose
	lda #PUNCH_TICKS
	sta wpn_pose_ticks
	jmp .irq_apply_fist

.irq_start_pistol
	lda #POSE_FIRE
	sta wpn_pose
	lda #PISTOL_FIRE_DY
	sta wpn_off_y
	lda #PISTOL_FIRE_TICKS
	sta wpn_pose_ticks
	lda #FLASH_TICKS
	sta wpn_flash_ticks
	jsr .irq_apply_pistol_y
	jsr .set_muzzle_ptrs
	inc muzzle_flash_var
	jsr .irq_flash_on
	jmp .irq_muzzle_hi

.irq_start_shotgun
	lda wpn_pose
	cmp #POSE_COCK
	bne .iss_flash
	jsr .irq_apply_shotgun
.iss_flash
	lda #POSE_FIRE
	sta wpn_pose
	lda #FLASH_TICKS
	sta wpn_flash_ticks
	lda #0
	sta wpn_pose_ticks
	jsr .set_muzzle_ptrs
	inc muzzle_flash_var
	jsr .irq_flash_on
	jmp .irq_muzzle_hi

.irq_start_minigun
	lda #POSE_FIRE
	sta wpn_pose
	lda #FLASH_TICKS
	sta wpn_flash_ticks
	jsr .set_muzzle_ptrs
	inc muzzle_flash_var
	lda mg_frame
	eor #1
	sta mg_frame
	jsr .set_minigun_frame_ptrs
	jsr .irq_flash_on
	jmp .irq_muzzle_hi

.irq_start_rocket
	lda #POSE_RECOIL
	sta wpn_pose
	lda #0
	sta recoil_step
	lda recoil_gren_dy
	sta wpn_off_y
	lda recoil_gren_ticks
	sta wpn_pose_ticks
	lda #FLASH_TICKS
	sta wpn_flash_ticks
	jsr .irq_apply_rocket_y
	jsr .irq_flash_on
	jmp .irq_muzzle_hi

.irq_muzzle_hi
	inc muzzle_hi_cycle
	lda muzzle_hi_cycle
	and #3
	tax
	lda muzzle_hi_cols,x
	sta muzzle_hi_col
	jmp .wpn_hi_direct

.irq_flash_on
	lda spr_en
	ora #FLASH_ENABLE
	jmp .wpn_en_irq

.irq_flash_off
	lda spr_en
	and #EIGHT_ENABLE_IDLE
	jmp .wpn_en_irq

.irq_tick_flash
	ldx cur_weapon
	cpx #2
	beq .itfl_rts			; pistol pose owns flash
	lda wpn_flash_ticks
	beq .itfl_rts
	dec wpn_flash_ticks
	bne .itfl_rts
	cpx #3
	beq .irq_start_cock
	jsr .irq_flash_off
	jmp .wpn_hi_direct
.itfl_rts
	rts

.irq_start_cock
	lda #POSE_COCK
	sta wpn_pose
	lda #SG_COCK_TICKS
	sta wpn_pose_ticks
	lda #0
	sta wpn_flash_ticks
	lda #SOUND_SGCOCK
	jsr play_sound
	jsr .irq_apply_shotgun_cock
	jmp .wpn_hi_direct

.irq_tick_pose
	lda wpn_pose_ticks
	beq .itp_rts
	dec wpn_pose_ticks
	bne .itp_rts
	ldx cur_weapon
	beq .itp_fist_idle
	cpx #2
	beq .itp_pistol
	cpx #3
	beq .itp_sg_idle
	cpx #5
	beq .itp_rocket
.itp_rts
	rts

.itp_fist_idle
	lda #POSE_IDLE
	sta wpn_pose
	jsr .irq_apply_fist
	jmp .wpn_hi_direct

.itp_pistol
	lda wpn_pose
	cmp #POSE_FIRE
	bne .itp_pis_idle
	lda #POSE_RECOIL
	sta wpn_pose
	lda #PISTOL_RECOIL_DY
	sta wpn_off_y
	lda #PISTOL_RECOIL_TICKS
	sta wpn_pose_ticks
	lda #0
	sta wpn_flash_ticks
	jsr .irq_flash_off
	jsr .irq_apply_pistol_y
	jmp .wpn_hi_direct
.itp_pis_idle
	lda #POSE_IDLE
	sta wpn_pose
	lda #0
	sta wpn_off_y
	jsr .irq_apply_pistol_y
	jmp .wpn_hi_direct

.itp_sg_idle
	lda #POSE_IDLE
	sta wpn_pose
	jsr .irq_apply_shotgun
	jmp .wpn_hi_direct

.itp_rocket
	ldx recoil_step
	inx
	stx recoil_step
	cpx #3
	bcs .itp_rok_idle
	lda recoil_gren_dy,x
	sta wpn_off_y
	lda recoil_gren_ticks,x
	sta wpn_pose_ticks
	jmp .irq_apply_rocket_y
.itp_rok_idle
	lda #POSE_IDLE
	sta wpn_pose
	lda #0
	sta recoil_step
	sta wpn_off_y
	jmp .irq_apply_rocket_y

; --- IRQ-safe pose apply (A/X/Y only) ---

.irq_apply_pistol_y
	ldx #0
	ldy #0
.iapy
	lda pistol_spr_y,x
	clc
	adc wpn_off_y
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .iapy
	rts

.irq_apply_rocket_y
	ldx #0
	ldy #0
.iary
	lda rocket_spr_y,x
	clc
	adc wpn_off_y
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .iary
	rts

.irq_apply_fist
	ldx #0
	ldy #0
.iaf
	txa
	clc
	adc #FIST_RIGHT_SPR_PTR0
	sta SPR_PTR,x
	lda wpn_pose
	bne .iaf_punch
	lda fist_spr_x,x
	jmp .iaf_xy
.iaf_punch
	txa
	clc
	adc #FIST_PUNCH_SPR_PTR0
	sta SPR_PTR,x
	lda fist_punch_spr_x,x
.iaf_xy
	sta $d000,y
	lda fist_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .iaf
	rts

.irq_apply_shotgun
	ldx #0
	ldy #0
	clc
.iasg
	lda shotgun_spr_col,x
	sta $d027,x
	cpx #6
	bcs .iasg_xy
	txa
	clc
	adc #SHOTGUN_SPR_PTR0
	sta SPR_PTR,x
.iasg_xy
	lda shotgun_spr_x,x
	sta $d000,y
	lda shotgun_spr_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #8
	bcc .iasg
	jsr .set_muzzle_ptrs
	lda #EIGHT_ENABLE_IDLE
	jmp .wpn_en_irq

.irq_apply_shotgun_cock
	ldx #0
	ldy #0
	clc
.iasc
	lda shotgun_cock_col,x
	sta $d027,x
	txa
	adc #SHOTGUN_COCK_SPR_PTR0
	sta SPR_PTR,x
	lda shotgun_cock_x,x
	sta $d000,y
	lda shotgun_cock_y,x
	sta $d001,y
	iny
	iny
	inx
	cpx #6
	bcc .iasc
	lda #EIGHT_ENABLE_IDLE
	jmp .wpn_en_irq

.saw_hold
	lda saw_running
	bne .sh_anim
	lda #1
	sta saw_running
	jsr .saw_set_y_run
.sh_anim
	inc saw_blade_div
	lda saw_blade_div
	and #3
	bne .sh_rts
	lda saw_blade_frame
	eor #1
	sta saw_blade_frame
	beq .sh_hi
	lda #CHAINSAW_BLADE_HI2_PTR
	sta SPR_PTR
	rts
.sh_hi
	lda #CHAINSAW_SPR_PTR0
	sta SPR_PTR
.sh_rts
	rts

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

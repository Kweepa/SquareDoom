!zone enemy

; ============================================================================
; enemy.asm — VicDoom p_enemy.c AI (possessed / imp / demon / caco + shot)
; Think only when SEC_SEEN[sector] (after render). Always camera-facing.
; Projectile flight → missile.asm.
; ============================================================================

MELEERANGE = 4
STANDOFF = 12			; no-melee stop (~1.5 tiles; Doom −192 map)
DI_NODIR = 8
TEX_ANIMATE = 64

MOBJINFO_POS = 0
MOBJINFO_IMP = 1
MOBJINFO_DEMON = 2
MOBJINFO_CACO = 3
MOBJINFO_BARON = 4
MOBJINFO_IMPSHOT = 5

STATE_POSCHASE = 0
STATE_POSPAIN = 1
STATE_POSSHOOT = 2
STATE_POSFALL = 3
STATE_IMPCHASE = 4
STATE_IMPPAIN = 5
STATE_IMPCLAW = 6
STATE_IMPMISSILE = 7
STATE_IMPFALL = 8
STATE_DMNCHASE = 9
STATE_DMNPAIN = 10
STATE_DMNBITE = 11
STATE_DMNFALL = 12
STATE_CACCHASE = 13
STATE_CACPAIN = 14
STATE_CACBITE = 15
STATE_CACMISSILE = 16
STATE_CACFALL = 17
STATE_BRNCHASE = 18
STATE_BRNPAIN = 19
STATE_BRNBITE = 20
STATE_BRNMISSILE = 21
STATE_BRNFALL = 22
STATE_IMPSHOTFLY = 23

ACTION_CHASE = 0
ACTION_FLINCH = 1
ACTION_MELEE = 2
ACTION_SHOOT = 3
ACTION_MISSILE = 4
ACTION_FALL = 5
ACTION_FLY = 6

ENEMY_TEX_WALK = 0
ENEMY_TEX_ATK = 1
ENEMY_TEX_PAIN = 2
ENEMY_TEX_IMP_WALK = 3
ENEMY_TEX_IMP_ATK = 4
ENEMY_TEX_IMP_PAIN = 5
ENEMY_TEX_DEMON_WALK = 6
ENEMY_TEX_DEMON_ATK = 7
ENEMY_TEX_DEMON_PAIN = 8
ENEMY_TEX_BARON_WALK = 9
ENEMY_TEX_BARON_ATK = 10

ITEM_TYPE_ENEMY_FIRST = 1
ITEM_TYPE_ENEMY_LAST = 5
ITEM_TYPE_SOLDIER = 1
ITEM_TYPE_IMP = 2
ITEM_TYPE_BARREL = 6
ITEM_TYPE_FIREBALL = 41
ITEM_TYPE_POSCORPSE = 36
ITEM_TYPE_IMPCORPSE = 37
ITEM_TYPE_DEMONCORPSE = 38
ITEM_TYPE_BARONCORPSE = 39
ITEM_TYPE_PLASMABALL = 42
ITEM_TYPE_ROCKET = 43
ITEM_TYPE_EXPLOSION = 44
ITEM_TYPE_EMPTY_E = $ff

MIN_SPEED = 32
FU_45 = 22
; tryd* is speed*dir per ~64 ms. wish = (tryd * dt_ms) >>> 6 so Ultimate
; (high fps) and stock C64 stay at the same world speed as the player.
ENEMY_ANIM_MS = 250
PAIN_MOVECNT = 16			; ~256 ms
FALL_MOVECNT = 8			; ~128 ms
ATK_WINDUP = 18				; ~10 tics FaceTarget before the shot
ATK_MOVECNT = 14			; ~8 tics ATK pose after the shot
ATK_REACT = 16				; ~256 ms after an attack before next melee/shot
NEWDIR_RETRY = 8			; ~128 ms; blocked retarget / busy-slot delay

; Scratch (safe after render; column temps free)
; wish_* used for try deltas; save_* for rollback

; ---------------------------------------------------------------------------
; Tables
; ---------------------------------------------------------------------------
; Speeds used to build tryd*: pos/imp/demon/caco/baron = 3,4,4,5,4
; dirs N,NE,E,SE,S,SW,W,NW × (32,22,0,-22,-32,-22,0,22) and y permute
mobj_pain_chance
	!byte 2,3,4,5,$ff		; baron $ff = never flinch
mobj_spawn_health
	!byte 20,30,60,99,150		; pos/imp/demon/caco/baron
mobj_chase_state
	!byte STATE_POSCHASE, STATE_IMPCHASE, STATE_DMNCHASE, STATE_CACCHASE, STATE_BRNCHASE
mobj_pain_state
	!byte STATE_POSPAIN, STATE_IMPPAIN, STATE_DMNPAIN, STATE_CACPAIN, STATE_BRNPAIN
mobj_melee_state
	!byte $ff, STATE_IMPCLAW, STATE_DMNBITE, STATE_CACBITE, STATE_BRNBITE
mobj_shoot_state
	!byte STATE_POSSHOOT, STATE_IMPMISSILE, $ff, STATE_CACMISSILE, STATE_BRNMISSILE
mobj_death_state
	!byte STATE_POSFALL, STATE_IMPFALL, STATE_DMNFALL, STATE_CACFALL, STATE_BRNFALL
mobj_death_sound
	!byte SOUND_SGTDTH, SOUND_PLPAIN, SOUND_DMPAIN, SOUND_POPAIN, SOUND_DMPAIN

; Frames 0–2 pos, 3–5 imp, 6–8 demon, 9–10 baron (pain=walk). Caco still stub.
state_texture
	!byte TEX_ANIMATE + ENEMY_TEX_WALK, ENEMY_TEX_PAIN, ENEMY_TEX_ATK, ENEMY_TEX_PAIN
	!byte TEX_ANIMATE + ENEMY_TEX_IMP_WALK, ENEMY_TEX_IMP_PAIN, ENEMY_TEX_IMP_ATK, ENEMY_TEX_IMP_ATK, ENEMY_TEX_IMP_PAIN
	!byte TEX_ANIMATE + ENEMY_TEX_DEMON_WALK, ENEMY_TEX_DEMON_PAIN, ENEMY_TEX_DEMON_ATK, ENEMY_TEX_DEMON_PAIN
	!byte TEX_ANIMATE + ENEMY_TEX_WALK, ENEMY_TEX_PAIN, ENEMY_TEX_ATK, ENEMY_TEX_ATK, ENEMY_TEX_PAIN
	!byte TEX_ANIMATE + ENEMY_TEX_BARON_WALK, ENEMY_TEX_BARON_WALK, ENEMY_TEX_BARON_ATK, ENEMY_TEX_BARON_ATK, ENEMY_TEX_BARON_WALK
	!byte 0

state_action
	!byte ACTION_CHASE, ACTION_FLINCH, ACTION_SHOOT, ACTION_FALL
	!byte ACTION_CHASE, ACTION_FLINCH, ACTION_MELEE, ACTION_MISSILE, ACTION_FALL
	!byte ACTION_CHASE, ACTION_FLINCH, ACTION_MELEE, ACTION_FALL
	!byte ACTION_CHASE, ACTION_FLINCH, ACTION_MELEE, ACTION_MISSILE, ACTION_FALL
	!byte ACTION_CHASE, ACTION_FLINCH, ACTION_MELEE, ACTION_MISSILE, ACTION_FALL
	!byte ACTION_FLY

opposite_dir
	!byte 4,5,6,7,0,1,2,3, DI_NODIR
diags_dir
	!byte 3,1,5,7			; NW NE SW SE

; speed[info] * dir component as signed 16-bit per ~64 ms — indexed by info*8+dir
trydx_lo
	!byte $60,$42,$00,$be,$a0,$be,$00,$42,$80,$58,$00,$a8,$80,$a8,$00,$58
	!byte $80,$58,$00,$a8,$80,$a8,$00,$58,$a0,$6e,$00,$92,$60,$92,$00,$6e
	!byte $80,$58,$00,$a8,$80,$a8,$00,$58
trydx_hi
	!byte $00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00
	!byte $00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00
	!byte $00,$00,$00,$ff,$ff,$ff,$00,$00
trydy_lo
	!byte $00,$42,$60,$42,$00,$be,$a0,$be,$00,$58,$80,$58,$00,$a8,$80,$a8
	!byte $00,$58,$80,$58,$00,$a8,$80,$a8,$00,$6e,$a0,$6e,$00,$92,$60,$92
	!byte $00,$58,$80,$58,$00,$a8,$80,$a8
trydy_hi
	!byte $00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff
	!byte $00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00,$00,$ff,$ff,$ff
	!byte $00,$00,$00,$00,$00,$ff,$ff,$ff

; ---------------------------------------------------------------------------
; Vars — under-stack scrap (zeropage.asm); missile/procket there too
; ---------------------------------------------------------------------------

; ---------------------------------------------------------------------------
; P_ApproxDistance — |dx|+|dy|/2 on signed 8-bit world deltas in tmp0/tmp1 → A
; ---------------------------------------------------------------------------
p_approx_distance
	lda tmp0
	bpl .pad_ax
	eor #$ff
	clc
	adc #1
.pad_ax
	sta tmp2
	lda tmp1
	bpl .pad_ay
	eor #$ff
	clc
	adc #1
.pad_ay
	sta tmp3
	cmp tmp2
	bcc .pad_y_smaller
	; dy >= dx: dx/2 + dy
	lda tmp2
	lsr
	clc
	adc tmp3
	rts
.pad_y_smaller
	lsr
	clc
	adc tmp2
	rts

; ---------------------------------------------------------------------------
; enemy_reset — clear all mobjs + FX overlay
; ---------------------------------------------------------------------------
enemy_reset
	ldx #0
	lda #0
.er_m
	sta MOBJ_ALLOC,x
	inx
	cpx #MAX_MOBJ
	bne .er_m
	ldx #0
	lda #$ff
.er_t
	sta ITEM_CORPSE_TEX,x
	inx
	cpx #MAX_MOBJ
	bne .er_t
	lda #0
	sta anim_frame
	sta anim_dt_acc
	sta react_dt_rem
	sta new_chase_dir_frame
	sta pain_boost
	sta barrel_events
	jsr fx_clear
	jsr hitscan_reset
	rts

; ---------------------------------------------------------------------------
; enemy_alloc_all — copy layer types 1..5 to mobj at tile center; clear cells
; ---------------------------------------------------------------------------
enemy_alloc_all
	jsr enemy_reset
	lda #0
	sta mapy
.eaa_row
	lda #0
	sta mapx
.eaa_col
	jsr item_layer_id
	cmp #ITEM_TYPE_ENEMY_FIRST
	bcc .eaa_nx
	cmp #ITEM_TYPE_ENEMY_LAST+1
	bcs .eaa_nx
	sta alloc_item_slot		; type 1..5
	jsr alloc_mobj
	bcs .eaa_nx			; full — leave the cell
	jsr item_layer_ptr
	lda #0
	tay
	sta (ptr_l),y
.eaa_nx
	inc mapx
	lda mapx
	cmp #MAP_SIZE
	bcc .eaa_col
	inc mapy
	lda mapy
	cmp #MAP_SIZE
	bcc .eaa_row
	rts

; ---------------------------------------------------------------------------
; alloc_mobj — alloc_item_slot = type 1..5; XY from mapx/mapy. C=0 ok / C=1 fail
; ---------------------------------------------------------------------------
alloc_mobj
	ldx #0
.am_find
	lda MOBJ_ALLOC,x
	beq .am_got
	inx
	cpx #MOBJ_PLAYER_ROCKET		; leave last two for missiles
	bcc .am_find
	sec
	rts
.am_got
	stx enemy_actor
	lda #1
	sta MOBJ_ALLOC,x
	lda #0
	sta MOBJ_MOVEDIR,x
	sta MOBJ_FLAGS,x
	sta MOBJ_MOVECNT,x
	lda #$80			; half-unit centers (n+0.5)
	sta MOBJ_XFRAC,x
	sta MOBJ_YFRAC,x
	jsr item_tile_xy
	ldx enemy_actor
	lda tmp0
	sta MOBJ_X,x
	lda tmp1
	sta MOBJ_Y,x
	lda #4				; wake ~64 ms (MOBJ_REACT is ms/16)
	sta MOBJ_REACT,x
	; info = typeId - 1
	lda alloc_item_slot
	sec
	sbc #1
	sta MOBJ_INFO,x
	sta enemy_info
	tay
	lda mobj_spawn_health,y
	ldx enemy_actor
	sta MOBJ_HEALTH,x
	ldy enemy_info
	lda mobj_chase_state,y
	sta MOBJ_STATE,x
	lda #$ff
	sta ITEM_CORPSE_TEX,x
	clc
	rts

; ---------------------------------------------------------------------------
; Helpers: XY / sector from enemy_actor (enemy_obj aliases the mobj index)
; ---------------------------------------------------------------------------
; → tmp0=x_h tmp1=y_h
obj_xy
	ldx enemy_actor
	lda MOBJ_X,x
	sta tmp0
	lda MOBJ_Y,x
	sta tmp1
	rts

; write tmp0/tmp1 as x_h/y_h
obj_set_xy
	ldx enemy_actor
	lda tmp0
	sta MOBJ_X,x
	lda tmp1
	sta MOBJ_Y,x
	rts

; → A = sector id (0 if void)
obj_sector
	jsr obj_xy
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	jmp map_sector_id

; distance player ↔ current obj → enemy_dist
calc_enemy_dist
	jsr obj_xy
	lda playerx_h
	sec
	sbc tmp0
	sta tmp0			; dx
	lda playery_h
	sec
	sbc tmp1
	sta tmp1			; dy
	jsr p_approx_distance
	sta enemy_dist
	rts

goto_chase_state
	ldx enemy_actor
	ldy enemy_info
	lda mobj_chase_state,y
	sta MOBJ_STATE,x
	rts

; ---------------------------------------------------------------------------
; enemy_think — after render; SEC_SEEN gate
; ---------------------------------------------------------------------------
enemy_think
	lda #0
	sta new_chase_dir_frame
	; MOBJ_REACT / MOBJ_MOVECNT are ms/16 — fold dt_ms into units.
	; rem+dt is 16-bit: carry = +256 ms = +16 units (dt_ms caps at 255).
	lda react_dt_rem
	clc
	adc dt_ms
	sta tmp0
	lda #0
	adc #0				; 1 if wrapped
	asl
	asl
	asl
	asl				; 0 or 16
	sta react_dt_units
	lda tmp0
	lsr
	lsr
	lsr
	lsr
	clc
	adc react_dt_units
	sta react_dt_units
	lda tmp0
	and #15
	sta react_dt_rem
	; walk mirror: at most one anim_frame tick per think (~250 ms → ~2 Hz flip)
	lda anim_dt_acc
	clc
	adc dt_ms
	bcc .et_anim_chk
	clc
	adc #256 - ENEMY_ANIM_MS	; wrapped sum − 250
	inc anim_frame
	jmp .et_anim_st
.et_anim_chk
	cmp #ENEMY_ANIM_MS
	bcc .et_anim_st
	sbc #ENEMY_ANIM_MS
	inc anim_frame
.et_anim_st
	sta anim_dt_acc
	jsr hitscan_frame
	lda plr_id			; setup_player_tile; keep player_sector lag for weapon hi
	sta player_sector
	ldx #0
.et_lp
	lda MOBJ_ALLOC,x
	beq .et_skip
	stx enemy_actor			; loop index (actions may clobber X)
	stx enemy_obj
	lda MOBJ_INFO,x
	sta enemy_info
	; missile always thinks while allocated
	cmp #MOBJINFO_IMPSHOT
	beq .et_run
	; corpses: no AI once fall has stamped ITEM_CORPSE_TEX
	lda MOBJ_HEALTH,x
	bne .et_live
	lda ITEM_CORPSE_TEX,x
	cmp #$ff
	bne .et_skip
	ldy MOBJ_STATE,x
	lda state_action,y
	cmp #ACTION_FALL
	bne .et_skip
	beq .et_run
.et_live
	; Chase needs SEC_SEEN. Any other live action (atk/pain/fall/…)
	; must finish even if the sector dropped out of the clip flood.
	ldy MOBJ_STATE,x
	lda state_action,y
	bne .et_run
	jsr obj_sector
	sta enemy_sector
	beq .et_nx
	tay
	lda SEC_SEEN,y
	cmp seen_gen
	bne .et_nx
.et_run
	jsr enemy_single_think
.et_nx
	ldx enemy_actor
.et_skip
	inx
	cpx #MAX_MOBJ
	bcc .et_lp
	rts

enemy_single_think
	ldx enemy_actor
	ldy MOBJ_STATE,x
	lda state_action,y
	; dispatch (ACTION_CHASE = 0 — Z from lda; a_chase is out of branch range)
	bne .est1
	jmp a_chase
.est1
	cmp #ACTION_FLINCH
	bne .est2
	jmp a_flinch
.est2
	cmp #ACTION_MELEE
	bne .est3
	jmp a_melee
.est3
	cmp #ACTION_SHOOT
	bne .est4
	jmp a_shoot
.est4
	cmp #ACTION_MISSILE
	bne .est5
	jmp a_missile
.est5
	cmp #ACTION_FALL
	bne .est6
	jmp a_fall
.est6
	jmp a_fly

; ---------------------------------------------------------------------------
; P_CheckSight — C=1 can see (uses enemy_sector from this think)
; ---------------------------------------------------------------------------
p_check_sight
	lda enemy_sector
	cmp player_sector
	beq .pcs_yes
	tay
	lda SEC_SEEN,y
	cmp seen_gen
	beq .pcs_yes
	lda enemy_dist
	cmp #3
	bcc .pcs_yes
	clc
	rts
.pcs_yes
	sec
	rts

p_check_melee_range
	lda enemy_dist
	cmp #MELEERANGE
	bcs .pcmr_no
	jmp p_check_sight
.pcmr_no
	clc
	rts

; P_CheckMissileRange — Doom: dist = (approx<<4) - 64; no melee -= 128;
; cap 200; P_Random() < dist → false. Negative after sub → always fire.
p_check_missile_range_fixed
	ldx enemy_actor
	lda MOBJ_REACT,x
	bne .pcm2_no
	jsr p_check_sight
	bcc .pcm2_no
	lda enemy_dist
	cmp #13				; 13*16 = 208 > 200 Doom
	bcc .pcm2_sc
	lda #12
.pcm2_sc
	asl
	asl
	asl
	asl				; world → Doom map (4 wu = 64)
	sec
	sbc #64
	bcc .pcm2_yes
	sta tmp4
	ldy enemy_info
	lda mobj_melee_state,y
	bpl .pcm2_cap			; has melee
	lda tmp4
	sec
	sbc #128
	bcc .pcm2_yes
	sta tmp4
.pcm2_cap
	lda tmp4
	cmp #201
	bcc .pcm2_rnd
	lda #200
.pcm2_rnd
	sta tmp4
	jsr GetRandom8
	cmp tmp4
	bcc .pcm2_no			; random < dist → no
.pcm2_yes
	sec
	rts
.pcm2_no
	clc
	rts

; ---------------------------------------------------------------------------
; P_TryMove — wish_x/y = signed 16-bit delta; C=1 ok C=0 blocked
; ---------------------------------------------------------------------------
p_try_move
	jsr obj_xy
	; old_floor/old_ceil from current sector; tmp4/5 = pre-move mapx/mapy
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	sta tmp4
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	sta tmp5
	jsr map_sector_id
	beq .ptm_voidfl
	tax
	lda SEC_FLOOR,x
	sta old_floor
	lda SEC_CEIL,x
	sta old_ceil
	jmp .ptm_save
.ptm_voidfl
	lda #0
	sta old_floor
	sta old_ceil
.ptm_save
	ldx enemy_actor
	lda MOBJ_XFRAC,x
	sta save_xl
	lda tmp0
	sta save_xh
	lda MOBJ_YFRAC,x
	sta save_yl
	lda tmp1
	sta save_yh
	; X += wish_x
	clc
	lda MOBJ_XFRAC,x
	adc wish_x_l
	sta MOBJ_XFRAC,x
	lda tmp0
	adc wish_x_h
	sta tmp0
	; Y += wish_y
	clc
	lda MOBJ_YFRAC,x
	adc wish_y_l
	sta MOBJ_YFRAC,x
	lda tmp1
	adc wish_y_h
	sta tmp1
	jsr obj_set_xy
	; tile check (dest + diagonal corner cells)
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	; both axes changed tile → require ortho corners walkable
	lda mapx
	cmp tmp4
	beq .ptm_dest
	lda mapy
	cmp tmp5
	beq .ptm_dest
	; corner (new_x, old_y)
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcs .ptm_block
	; corner (old_x, new_y)
	lda tmp4
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcs .ptm_block
	; restore dest map tile
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
.ptm_dest
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcc .ptm_ok
.ptm_block
	; restore
	ldx enemy_actor
	lda save_xl
	sta MOBJ_XFRAC,x
	lda save_yl
	sta MOBJ_YFRAC,x
	lda save_xh
	sta tmp0
	lda save_yh
	sta tmp1
	jsr obj_set_xy
	jsr enemy_push_walls
	clc
	rts
.ptm_ok
	jsr enemy_push_walls
	sec
	rts

; ---------------------------------------------------------------------------
; enemy_push_walls — keep local in 2..5 (with frac $80) from impassable
; neighbors. Positions are unit-cell centers (n+0.5), so local 2/5 sit
; 2.5 units from tile seams. Uses enemy_tile_blocked so drops ≥3 count.
; Expects enemy_obj / enemy_actor; clobbers tmp0–5, mapx/y, old_floor/ceil.
; ---------------------------------------------------------------------------
enemy_push_walls
	jsr obj_xy
	lda tmp0
	and #7
	cmp #2
	bcc .epw_go			; west: local_x < 2
	cmp #6
	bcs .epw_go			; east: local_x >= 6
	cmp #5
	bne .epw_chk_y
	ldx enemy_actor
	lda MOBJ_XFRAC,x
	cmp #$81
	bcs .epw_go			; east: local 5 and frac >= $81
.epw_chk_y
	lda tmp1
	and #7
	cmp #2
	bcc .epw_go			; north: local_y < 2
	cmp #6
	bcs .epw_go			; south: local_y >= 6
	cmp #5
	bne .epw_none
	ldx enemy_actor
	lda MOBJ_YFRAC,x
	cmp #$81
	bcs .epw_go			; south: local 5 and frac >= $81
.epw_none
	rts
.epw_go
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
	sta tmp4
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	sta tmp5
	jsr map_sector_id
	beq .epw_voidfl
	tax
	lda SEC_FLOOR,x
	sta old_floor
	lda SEC_CEIL,x
	sta old_ceil
	jmp .epw_west
.epw_voidfl
	lda #0
	sta old_floor
	sta old_ceil

	; West: neighbor (mapx-1, mapy)
.epw_west
	lda tmp4
	sec
	sbc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcc .epw_east
	lda tmp0
	and #7
	cmp #2
	bcs .epw_east			; local_x >= 2 — leave frac alone
	lda tmp4
	asl
	asl
	asl
	ora #2
	sta tmp0
	ldx enemy_actor
	lda #$80
	sta MOBJ_XFRAC,x

.epw_east
	lda tmp4
	clc
	adc #1
	sta mapx
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcc .epw_north
	lda tmp0
	and #7
	cmp #6
	bcs .epw_e_push			; local_x >= 6 → snap to 5.5
	cmp #5
	bcc .epw_north			; local_x <= 4 — ok
	ldx enemy_actor
	lda MOBJ_XFRAC,x
	cmp #$81
	bcc .epw_north			; local 5.0..5.5 — ok
.epw_e_push
	lda tmp4
	asl
	asl
	asl
	ora #5
	sta tmp0
	ldx enemy_actor
	lda #$80
	sta MOBJ_XFRAC,x

.epw_north
	; map Y−1 (smaller y)
	lda tmp4
	sta mapx
	lda tmp5
	sec
	sbc #1
	sta mapy
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcc .epw_south
	lda tmp1
	and #7
	cmp #2
	bcs .epw_south			; local_y >= 2 — leave frac alone
	lda tmp5
	asl
	asl
	asl
	ora #2
	sta tmp1
	ldx enemy_actor
	lda #$80
	sta MOBJ_YFRAC,x

.epw_south
	lda tmp4
	sta mapx
	lda tmp5
	clc
	adc #1
	sta mapy
	jsr sector_at_map
	jsr enemy_tile_blocked
	bcc .epw_done
	lda tmp1
	and #7
	cmp #6
	bcs .epw_s_push			; local_y >= 6 → snap to 5.5
	cmp #5
	bcc .epw_done			; local_y <= 4 — ok
	ldx enemy_actor
	lda MOBJ_YFRAC,x
	cmp #$81
	bcc .epw_done			; local 5.0..5.5 — ok
.epw_s_push
	lda tmp5
	asl
	asl
	asl
	ora #5
	sta tmp1
	ldx enemy_actor
	lda #$80
	sta MOBJ_YFRAC,x
.epw_done
	jmp obj_set_xy

; A = sector id → C=1 blocked, C=0 walkable.
; Same as tile_blocked, plus step-down > 2 is blocked (enemies only).
enemy_tile_blocked
	sta tmp2				; keep sector
	jsr tile_blocked
	bcs .etb_yes
	lda tmp2
	beq .etb_yes
	tax
	lda old_floor
	cmp SEC_FLOOR,x
	bcc .etb_no			; step up / flat already ok
	beq .etb_no
	sec
	sbc SEC_FLOOR,x			; drop amount
	cmp #3
	bcs .etb_yes			; drop ≥ 3 → blocked
.etb_no
	clc
	rts
.etb_yes
	sec
	rts

; ---------------------------------------------------------------------------
; P_Move — C=1 ok
; enemy_dist must already be set (a_chase / callers).
; ---------------------------------------------------------------------------
p_move
	ldx enemy_actor
	lda MOBJ_MOVEDIR,x
	cmp #DI_NODIR
	bne .pm_dir
	clc
	rts
.pm_dir
	lda enemy_dist
	cmp #MELEERANGE
	bcc .pm_ok_close
	ldy MOBJ_INFO,x
	lda mobj_melee_state,y
	bpl .pm_wish			; claw/bite — close in
	lda enemy_dist
	cmp #STANDOFF
	bcc .pm_ok_close
.pm_wish
	; wish = (table[info*8+dir] * dt_ms) >>> 6
	lda MOBJ_INFO,x
	asl
	asl
	asl
	ora MOBJ_MOVEDIR,x
	tay
	jsr scale_enemy_wish
	jmp p_try_move
.pm_ok_close
	sec
	rts

; Y = info*8+dir. wish_x/y = signed (tryd * dt_ms) >>> 6 (8.8).
scale_enemy_wish
	sty tmp4
	lda trydx_lo,y
	ldx trydx_hi,y
	jsr scale_tryd
	lda tmp0
	sta wish_x_l
	lda tmp1
	sta wish_x_h
	ldy tmp4
	lda trydy_lo,y
	ldx trydy_hi,y
	jsr scale_tryd
	lda tmp0
	sta wish_y_l
	lda tmp1
	sta wish_y_h
	rts

; A=lo X=hi signed 16 (|mag|≤192) → tmp0/tmp1 = (val * dt_ms) >>> 6
scale_tryd
	sta tmp2
	stx tmp3
	lda tmp3
	bpl .st_mul
	sec
	lda #0
	sbc tmp2
	sta tmp2
.st_mul
	ldy tmp2
	lda dt_ms
	jsr mul_8x8			; X=lo A=hi of |tryd|*dt
	sta tmp1
	stx tmp0
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	lsr tmp1
	ror tmp0
	lda tmp3
	bpl .st_done
	sec
	lda #0
	sbc tmp0
	sta tmp0
	lda #0
	sbc tmp1
	sta tmp1
.st_done
	rts

; X = enemy_actor. Subtract react_dt_units from MOBJ_MOVECNT.
; C=1 still remaining, C=0 expired (MOVECNT=0).
mobj_countdown
	lda MOBJ_MOVECNT,x
	beq .mc_exp
	sec
	sbc react_dt_units
	beq .mc_z
	bcc .mc_z
	sta MOBJ_MOVECNT,x
	sec
	rts
.mc_z
	lda #0
	sta MOBJ_MOVECNT,x
.mc_exp
	clc
	rts

p_try_walk
	jsr p_move
	bcc .ptw_no
	jsr mobj_roll_movecnt
	ldx enemy_actor
	sta MOBJ_MOVECNT,x
	sec
	rts
.ptw_no
	clc
	rts

; Doom P_TryWalk: movecount = P_Random()&15 A_Chase calls × ~128 ms → ms/16
mobj_roll_movecnt
	jsr GetRandom8
	and #15
	asl
	asl
	asl				; 0..120
	bne .mrm_ok
	lda #NEWDIR_RETRY		; min ~128 ms — 0 chained p_new_chase_dir
.mrm_ok
	rts

; ---------------------------------------------------------------------------
; P_NewChaseDir
; ---------------------------------------------------------------------------
p_new_chase_dir
	lda new_chase_dir_frame
	beq .pncd_go
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	bne .pncd_busy
	lda #NEWDIR_RETRY		; ~128 ms — don't retry every think
	sta MOBJ_MOVECNT,x
.pncd_busy
	rts
.pncd_go
	lda #1
	sta new_chase_dir_frame
	ldx enemy_actor
	lda MOBJ_MOVEDIR,x
	sta tmp4			; olddir
	tay
	lda opposite_dir,y
	sta tmp5			; turnaround
	jsr obj_xy
	; deltax = (playerx_h - objx) — VicDoom >>8 on 16-bit; we use hi already
	lda playerx_h
	sec
	sbc tmp0
	sta fracy			; deltax
	lda playery_h
	sec
	sbc tmp1
	sta fracx			; deltay
	; d1 from deltax
	lda fracy
	beq .pncd_d1n
	bmi .pncd_d1w
	lda #0				; EAST
	jmp .pncd_d1s
.pncd_d1w
	cmp #$ff			; -1 → NODIR in VicDoom (deltax < -1)
	beq .pncd_d1n
	lda #4				; WEST
	jmp .pncd_d1s
.pncd_d1n
	lda #DI_NODIR
.pncd_d1s
	sta span_a			; d1
	; d2 from deltay (VicDoom: deltay < -1 SOUTH, >0 NORTH)
	lda fracx
	beq .pncd_d2n
	bmi .pncd_d2chk
	lda #2				; NORTH
	jmp .pncd_d2s
.pncd_d2chk
	cmp #$ff
	beq .pncd_d2n
	lda #6				; SOUTH
	jmp .pncd_d2s
.pncd_d2n
	lda #DI_NODIR
.pncd_d2s
	sta span_b			; d2
	lda #DI_NODIR
	sta fill_row			; newdir
	; diagonal?
	lda span_a
	cmp #DI_NODIR
	beq .pncd_nodiag
	lda span_b
	cmp #DI_NODIR
	beq .pncd_nodiag
	; diags[((deltay<0)<<1)+(deltax>=0)]
	lda #0
	sta tmp0
	lda fracx
	bpl .pncd_dypos
	lda #2
	sta tmp0
.pncd_dypos
	lda fracy
	bmi .pncd_dxneg
	inc tmp0
.pncd_dxneg
	ldy tmp0
	lda diags_dir,y
	cmp tmp5
	beq .pncd_nodiag
	sta fill_row
.pncd_nodiag
	lda fill_row
	cmp #DI_NODIR
	bne .pncd_set
	lda span_a
	cmp tmp5
	bne .pncd_d1ok
	lda #DI_NODIR
	sta span_a
.pncd_d1ok
	lda span_b
	cmp tmp5
	bne .pncd_d2ok
	lda #DI_NODIR
	sta span_b
.pncd_d2ok
	lda span_a
	cmp #DI_NODIR
	beq .pncd_try2
	sta fill_row
	jmp .pncd_set
.pncd_try2
	lda span_b
	cmp #DI_NODIR
	beq .pncd_rand
	sta fill_row
	jmp .pncd_set
.pncd_rand
	jsr GetRandom8
	and #7
	sta fill_row
.pncd_set
	ldx enemy_actor
	lda fill_row
	sta MOBJ_MOVEDIR,x
	jsr p_try_walk
	bcs .pncd_done
	jsr GetRandom8
	and #7
	ldx enemy_actor
	sta MOBJ_MOVEDIR,x
	jsr mobj_roll_movecnt
	ldx enemy_actor
	sta MOBJ_MOVECNT,x
.pncd_done
	rts

; ---------------------------------------------------------------------------
; Actions
; ---------------------------------------------------------------------------
a_chase
	jsr calc_enemy_dist
	ldx enemy_actor
	lda MOBJ_REACT,x
	beq .ac_nort
	sec
	sbc react_dt_units
	bcs .ac_react_ok
	lda #0
.ac_react_ok
	sta MOBJ_REACT,x
.ac_nort
	lda MOBJ_FLAGS,x
	and #MF_JUSTATTACKED
	beq .ac_melee
	lda MOBJ_FLAGS,x
	and #$fe				; clear MF_JUSTATTACKED
	sta MOBJ_FLAGS,x
	jmp p_new_chase_dir
.ac_melee
	lda MOBJ_REACT,x
	beq .ac_melee_ok
	jmp .ac_move			; cooldown — walk, don't claw
.ac_melee_ok
	ldy enemy_info
	lda mobj_melee_state,y
	bmi .ac_missile
	jsr p_check_melee_range
	bcc .ac_missile
	ldx enemy_actor
	lda #ATK_WINDUP
	sta MOBJ_MOVECNT,x
	ldy enemy_info
	lda mobj_melee_state,y
	sta MOBJ_STATE,x
	lda MOBJ_FLAGS,x
	ora #MF_JUSTATTACKED | MF_ATK_WINDUP
	sta MOBJ_FLAGS,x
	rts
.ac_missile
	ldy enemy_info
	lda mobj_shoot_state,y
	bmi .ac_move
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	bne .ac_move
	; Possessed: hitscan before ATK; others enter shoot state directly
	lda enemy_info
	bne .ac_missile_direct
	; Poll outstanding hitscan for this actor
	lda hs_actor
	cmp enemy_actor
	bne .ac_hs_try
	lda hs_status
	cmp #HS_PENDING
	beq .ac_walk			; waiting — keep current dir
	cmp #HS_CLEAR
	beq .ac_hs_fire
	cmp #HS_BLOCKED
	beq .ac_hs_miss
.ac_hs_try
	jsr p_check_missile_range_fixed
	bcc .ac_move
	ldx enemy_actor
	jsr hitscan_request
	bcs .ac_walk			; another enemy already claimed this frame
	lda hs_status
	cmp #HS_CLEAR
	beq .ac_hs_fire
	jmp .ac_walk			; PENDING
.ac_hs_fire
	ldy enemy_info
	lda mobj_shoot_state,y
	ldx enemy_actor
	sta MOBJ_STATE,x
	lda #ATK_WINDUP
	sta MOBJ_MOVECNT,x
	lda MOBJ_FLAGS,x
	ora #MF_JUSTATTACKED | MF_ATK_WINDUP
	sta MOBJ_FLAGS,x
	rts
.ac_hs_miss
	jsr hitscan_release
	jmp .ac_move
.ac_missile_direct
	jsr p_check_missile_range_fixed
	bcc .ac_move
	ldy enemy_info
	lda mobj_shoot_state,y
	ldx enemy_actor
	sta MOBJ_STATE,x
	lda #ATK_WINDUP
	sta MOBJ_MOVECNT,x
	lda MOBJ_FLAGS,x
	ora #MF_JUSTATTACKED | MF_ATK_WINDUP
	sta MOBJ_FLAGS,x
	rts
.ac_move
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	beq .ac_newdir			; already 0 — shoot window was this think
	jsr mobj_countdown		; may hit 0; still walk (old dec 1→0)
.ac_walk
	ldx enemy_actor
	jsr p_move
	bcs .ac_snd
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	bne .ac_snd			; still in a walk window — keep heading
.ac_newdir
	jsr p_new_chase_dir
.ac_snd
	jsr GetRandom8
	cmp #3
	bcs .ac_done
	lda #SOUND_GURGLE
	jsr play_sound
.ac_done
	rts

; Hold pain state for MOVECNT ms/16 (set in enemy_damage). Old path
; jumped to chase the same frame as the hit — pain never reached a render.
a_flinch
	ldx enemy_actor
	lda MOBJ_HEALTH,x
	beq .afl_dead			; 0 HP must not return to chase
	lda MOBJ_MOVECNT,x
	beq .afl_done			; timer finished last think — pose has rendered
	jsr mobj_countdown
	rts				; even if dt ate the rest this think, draw pain first
.afl_done
	jmp goto_chase_state
.afl_dead
	lda #FALL_MOVECNT
	sta MOBJ_MOVECNT,x
	ldy enemy_info
	lda mobj_death_state,y
	sta MOBJ_STATE,x
	rts

; Hitscan already CLEAR (chase only enters POSSHOOT then). Accuracy + damage.
; MOVECNT windup (MF_ATK_WINDUP) then shot, then recover — Doom ATK1/ATK2.
a_shoot
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	beq .as_chase
	jsr mobj_countdown
	bcs .as_rts
	lda MOBJ_FLAGS,x
	and #MF_ATK_WINDUP
	beq .as_chase
	lda MOBJ_FLAGS,x
	and #$ff - MF_ATK_WINDUP
	sta MOBJ_FLAGS,x
	lda #SOUND_PISTOL
	jsr play_sound
	jsr calc_enemy_dist
	lda enemy_dist
	cmp #29
	bcc .as_d
	lda #28
.as_d
	sta tmp4
	jsr GetRandom8
	and #31
	cmp tmp4
	beq .as_miss
	bcc .as_miss			; hit only if (rand&31) > dist
	jsr GetRandom8
	and #3
	clc
	adc #2
	sta tmp0
	asl
	clc
	adc tmp0			; *3
	jsr damage_player
.as_miss
	jsr hitscan_release
	ldx enemy_actor
	lda #ATK_MOVECNT
	sta MOBJ_MOVECNT,x
	lda #ATK_REACT
	sta MOBJ_REACT,x
.as_rts
	rts
.as_chase
	jmp goto_chase_state

a_melee
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	beq .ame_done
	jsr mobj_countdown
	bcs .ame_rts
	lda MOBJ_FLAGS,x
	and #MF_ATK_WINDUP
	beq .ame_done
	lda MOBJ_FLAGS,x
	and #$ff - MF_ATK_WINDUP
	sta MOBJ_FLAGS,x
	lda #SOUND_CLAW
	jsr play_sound
	jsr GetRandom8
	and #7
	clc
	adc #1
	sta tmp0
	asl
	clc
	adc tmp0
	jsr damage_player
	ldx enemy_actor
	lda #ATK_MOVECNT
	sta MOBJ_MOVECNT,x
	lda #ATK_REACT
	sta MOBJ_REACT,x
.ame_rts
	rts
.ame_done
	jmp goto_chase_state

a_missile
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	beq .ami_chase
	jsr mobj_countdown
	bcs .ami_rts
	lda MOBJ_FLAGS,x
	and #MF_ATK_WINDUP
	beq .ami_chase
	lda MOBJ_FLAGS,x
	and #$ff - MF_ATK_WINDUP
	sta MOBJ_FLAGS,x
	lda MOBJ_ALLOC + MOBJ_MISSILE
	bne .ami_pose
	jsr spawn_enemy_missile
.ami_pose
	ldx enemy_actor
	lda #ATK_MOVECNT
	sta MOBJ_MOVECNT,x
	lda #ATK_REACT
	sta MOBJ_REACT,x
.ami_rts
	rts
.ami_chase
	jmp goto_chase_state

a_fall
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	beq .af_corpse			; timer finished last think — pose has rendered
	jsr mobj_countdown
	rts				; even if dt ate the rest this think, draw pain first
.af_corpse
	; Keep the mobj. pos/imp/demon/baron → item-atlas corpse tex;
	; caco → 16×32 stub in ITEM_CORPSE_TEX.
	lda MOBJ_INFO,x
	cmp #MOBJINFO_BARON
	beq .af_baron
	cmp #MOBJINFO_CACO
	bcs .af_stub			; caco / missile
	clc
	adc #ITEM_TYPE_POSCORPSE	; 0→pos, 1→imp, 2→demon
	sta ITEM_CORPSE_TEX,x
	rts
.af_baron
	lda #ITEM_TYPE_BARONCORPSE
	sta ITEM_CORPSE_TEX,x
	rts
.af_stub
	lda MOBJ_STATE,x
	tay
	lda state_texture,y
	and #$bf				; clear TEX_ANIMATE
	sta ITEM_CORPSE_TEX,x
.af_done
	rts

; ---------------------------------------------------------------------------
; enemy_damage — X = mobj index, A = damage
; ---------------------------------------------------------------------------
enemy_damage
	sta damage_amount
	lda MOBJ_ALLOC,x
	beq .ed_rts
	lda MOBJ_HEALTH,x
	bne .ed_alive
	rts
.ed_alive
	stx enemy_actor
	stx enemy_obj
	lda MOBJ_INFO,x
	sta enemy_info
	cmp #MOBJINFO_IMPSHOT
	bcc .ed_dmg
	rts
.ed_dmg
	; P_DamageMobj
	lda MOBJ_HEALTH,x
	sec
	sbc damage_amount
	sta MOBJ_HEALTH,x
	beq .ed_kill
	bcc .ed_kill
	lda MOBJ_FLAGS,x
	ora #MF_JUSTATTACKED
	sta MOBJ_FLAGS,x
	lda damage_amount
	clc
	adc pain_boost			; chainsaw: bias toward flinch
	bcs .ed_pain			; overflow → always pain (non-baron)
	ldy enemy_info
	cmp mobj_pain_chance,y
	bcc .ed_rts
	beq .ed_rts
.ed_pain
	ldy enemy_info
	lda mobj_pain_chance,y
	bmi .ed_rts
	lda mobj_pain_state,y
	ldx enemy_actor
	sta MOBJ_STATE,x
	lda #PAIN_MOVECNT		; ~256 ms of pain before chase
	sta MOBJ_MOVECNT,x
	rts
.ed_kill
	ldx enemy_actor
	lda #0
	sta MOBJ_HEALTH,x
	lda #FALL_MOVECNT
	sta MOBJ_MOVECNT,x
	inc num_kills
	ldy enemy_info
	lda mobj_death_sound,y
	jsr play_sound			; preserves X/Y
	lda mobj_death_state,y
	sta MOBJ_STATE,x
	; E1M8: last baron → lower forever floors
	jsr e1m8_baron_kill_hook
.ed_rts
	rts

; ---------------------------------------------------------------------------
; enemy_get_texture — X = mobj → A = tex (bit6=animate), C=1 if 16×32
; Live enemies use enemy_sprites. Dead pos/imp/demon/baron use item atlas
; (ITEM_CORPSE_TEX = pos/imp/demon/baron atlas ids). Caco stub is a 16×32 frame index.
; ---------------------------------------------------------------------------
enemy_get_texture
	lda ITEM_CORPSE_TEX,x
	cmp #$ff
	beq .egt_live
	cmp #ITEM_TYPE_POSCORPSE
	bcc .egt_stub			; caco / other 16×32 corpse
	; item-atlas corpse
.egt_item8
	lda #0
	clc
	rts
.egt_stub
	sec
	rts				; A = corpse tex stub
.egt_live
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT		; missile uses fireball item atlas
	bcs .egt_item8
	lda MOBJ_STATE,x
	tay
	lda state_texture,y
	sec
	rts

; ---------------------------------------------------------------------------
; TryDamageEnemy — A = damage; nearest live enemy on MUZZLE±AIM_COL_SLACK
; via COL_AIM_* (per-column stamp; pick lowest COL_AIM_Z in the cone).
; TryDamageMelee — same, but only if COL_AIM_Z < MELEERANGE.
; TryDamageAtCol — A = damage, X = column; hit that column's aim target only.
; COL_AIM_SLOT is a vis-list index.
; ---------------------------------------------------------------------------
TryDamageMelee
	sta damage_amount
	lda #MELEERANGE
	sta tde_max_z
	jmp .tde_go

TryDamageEnemy
	sta damage_amount
	lda #$ff			; any depth
	sta tde_max_z
.tde_go
	lda #$ff
	sta tde_best_z
	sta tde_best_slot
	ldx #MUZZLE_COL - AIM_COL_SLACK
.tde_scan
	lda COL_AIM_SLOT,x
	bmi .tde_nx
	lda COL_AIM_Z,x
	cmp tde_best_z
	bcs .tde_nx
	sta tde_best_z
	lda COL_AIM_SLOT,x
	sta tde_best_slot
.tde_nx
	inx
	cpx #MUZZLE_COL + AIM_COL_SLACK + 1
	bcc .tde_scan
	lda tde_best_slot
	bmi .tde_rts
	lda tde_max_z
	bmi .tde_slot
	lda tde_best_z
	cmp tde_max_z
	bcs .tde_rts			; too far for melee
.tde_slot
	ldx tde_best_slot		; vis index
	lda ITEM_SORT_SLOT,x
	bmi .tde_layer
	tax				; mobj
	lda MOBJ_HEALTH,x
	beq .tde_rts
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .tde_rts
	lda damage_amount
	jmp enemy_damage
.tde_layer
	and #$40
	bne .tde_rts			; FX overlay — not a barrel
	lda ITEM_SORT_SLOT,x
	and #31
	sta mapx
	lda ITEM_SORT_SEC,x
	sta mapy
	jsr item_layer_id
	cmp #ITEM_TYPE_BARREL
	bne .tde_rts
	jmp explode_tile
.tde_rts
	rts

; A = damage, X = screen column — damage COL_AIM_SLOT,x if live (any range).
TryDamageAtCol
	sta damage_amount
	lda COL_AIM_SLOT,x
	bmi .tde_rts
	sta tde_best_slot
	jmp .tde_slot

; ============================================================================
; E1M8 boss death → forever floors; explosions (barrels + rockets)
; ============================================================================

BARREL_FUSE_TIME = 12			; ms/16 (~192 ms) until detonation
EXPLOSION_TIME = 32			; ms/16 (~512 ms); +1 extra frame after timer
EXPLOSION_SPLASH = 8			; world units (1 tile)

; boss_* / barrel_events — cassette scrap BSS (zeropage.asm)

; e1m8_baron_kill_hook — after any kill; if last baron on E1M8, lower floors
e1m8_baron_kill_hook
	lda enemy_info
	cmp #MOBJINFO_BARON
	bne .e1h_rts
	lda level_num
	cmp #8
	bne .e1h_rts
	; fall through
; e1m8_check_barons_dead — if no live barons remain, lower forever floors
e1m8_check_barons_dead
	ldx #0
.e1b_lp
	lda MOBJ_ALLOC,x
	beq .e1b_nx
	lda MOBJ_INFO,x
	cmp #MOBJINFO_BARON
	bne .e1b_nx
	lda MOBJ_HEALTH,x
	bne .e1h_rts			; still one alive
.e1b_nx
	inx
	cpx #MAX_MOBJ
	bcc .e1b_lp
	jmp boss_lower_forever_floors
.e1h_rts
	rts

; boss_lower_forever_floors — lower every forever+none sector (self). Once/level.
boss_lower_forever_floors
	lda boss_floors_done
	bne .blf_rts
	lda #1
	sta boss_floors_done
	ldx #1
.blf_lp
	stx boss_scan_sec
	jsr sec_trigger
	cmp #TRIG_NONE
	bne .blf_nx
	ldx boss_scan_sec
	jsr sec_action
	cmp #ACT_LOWER_FLOOR_FOREVER
	bne .blf_nx
	ldx boss_scan_sec
	stx tmp1
	lda #0
	sta elev_mode
	jsr elevator_find_dest
	sta elev_dest
	ldx tmp1
	jsr forever_adopt_nb
	lda elev_dest
	sta tmp2
	jsr floor_forever_activate
.blf_nx
	ldx boss_scan_sec
	cpx level_sector_max
	bcs .blf_rts
	inx
	bne .blf_lp
.blf_rts
	rts

; ---------------------------------------------------------------------------
; FX overlay (cassette): fuse / explosion sprites, not the item layer
; ---------------------------------------------------------------------------
fx_clear
	ldx #0
	lda #0
.fxc
	sta FX_KIND,x
	inx
	cpx #FX_MAX
	bcc .fxc
	rts

; mapx/mapy → C=0 X=index if an overlay occupies that tile
fx_find
	ldx #0
.fxf
	lda FX_KIND,x
	beq .fxf_nx
	lda FX_TX,x
	cmp mapx
	bne .fxf_nx
	lda FX_TY,x
	cmp mapy
	bne .fxf_nx
	clc
	rts
.fxf_nx
	inx
	cpx #FX_MAX
	bcc .fxf
	sec
	rts

fx_alloc
	ldx #0
.fxa
	lda FX_KIND,x
	beq .fxa_got
	inx
	cpx #FX_MAX
	bcc .fxa
	sec
	rts
.fxa_got
	clc
	rts

; Light a barrel fuse at mapx/mapy (no-op if already fused / overlay full)
fx_fuse_at
	jsr fx_find
	bcc .fxu_rts
	jsr fx_alloc
	bcs .fxu_rts
	lda #FX_FUSE
	sta FX_KIND,x
	lda mapx
	sta FX_TX,x
	lda mapy
	sta FX_TY,x
	lda #BARREL_FUSE_TIME
	sta FX_TIME,x
	inc barrel_events
.fxu_rts
	rts

; ---------------------------------------------------------------------------
; explosion_near_mobj — X = mobj; C=0 if within EXPLOSION_SPLASH of save_xh/yh
; ---------------------------------------------------------------------------
explosion_near_mobj
	lda MOBJ_X,x
	sec
	sbc save_xh
	bcs .eny_ax
	eor #$ff
	adc #1
.eny_ax
	cmp #EXPLOSION_SPLASH+1
	bcs .eny_out
	lda MOBJ_Y,x
	sec
	sbc save_yh
	bcs .eny_ay
	eor #$ff
	adc #1
.eny_ay
	cmp #EXPLOSION_SPLASH+1
	rts
.eny_out
	sec
	rts

; ---------------------------------------------------------------------------
; explode_tile — mapx/mapy = blast tile (barrel or rocket).
; Overlay explosion sprite; splash enemies; fuse neighbour barrels (3×3).
; ---------------------------------------------------------------------------
explode_tile
	jsr item_tile_xy
	lda tmp0
	sta save_xh
	lda tmp1
	sta save_yh
	; drop barrel from the layer if present
	jsr item_layer_id
	cmp #ITEM_TYPE_BARREL
	bne .bex_fx
	lda #0
	sta (ptr_l),y
.bex_fx
	; reuse overlay on this tile, else alloc
	jsr fx_find
	bcc .bex_set
	jsr fx_alloc
	bcs .bex_sfx			; full — still splash
.bex_set
	lda #FX_EXPL
	sta FX_KIND,x
	lda mapx
	sta FX_TX,x
	lda mapy
	sta FX_TY,x
	lda #EXPLOSION_TIME
	sta FX_TIME,x
	inc barrel_events
.bex_sfx
	lda #SOUND_BAREXP
	jsr play_sound
	ldx #0
.bex_mobj
	lda MOBJ_ALLOC,x
	beq .bex_mn
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .bex_mn
	jsr explosion_near_mobj
	bcs .bex_mn
	stx tmp5
	jsr GetRandom8
	and #31
	clc
	adc #16
	ldx tmp5
	jsr enemy_damage
	ldx tmp5
.bex_mn
	inx
	cpx #MOBJ_PLAYER_ROCKET
	bcc .bex_mobj
	; 3×3 layer neighbourhood (skip center)
	lda mapx
	sta tmp4
	lda mapy
	sta tmp5
	lda tmp5
	sec
	sbc #1
	sta mapy
	ldy #3
.bex_yy
	lda tmp4
	sec
	sbc #1
	sta mapx
	ldx #3
.bex_xx
	lda mapx
	cmp #MAP_SIZE
	bcs .bex_xn
	lda mapy
	cmp #MAP_SIZE
	bcs .bex_xn
	lda mapx
	cmp tmp4
	bne .bex_chk
	lda mapy
	cmp tmp5
	beq .bex_xn
.bex_chk
	stx tmp2
	sty tmp3
	jsr item_layer_id
	cmp #ITEM_TYPE_BARREL
	bne .bex_rst
	jsr fx_fuse_at
.bex_rst
	ldx tmp2
	ldy tmp3
.bex_xn
	inc mapx
	dex
	bne .bex_xx
	inc mapy
	dey
	bne .bex_yy
	lda tmp4
	sta mapx
	lda tmp5
	sta mapy
	rts

; ---------------------------------------------------------------------------
; barrel_update — overlay fuse countdown + explosion lifetime
; ---------------------------------------------------------------------------
barrel_update
	lda barrel_events
	bne .bu_go
	rts
.bu_go
	ldx #0
.bu_lp
	lda FX_KIND,x
	beq .bu_nx
	cmp #FX_FUSE
	beq .bu_fuse
	cmp #FX_EXPL
	bne .bu_nx
	lda FX_TIME,x
	beq .bu_expl_done		; timer already 0 — extra frame shown
	jsr fx_countdown
	bcs .bu_nx
	jmp .bu_nx			; keep overlay one more displayed frame
.bu_expl_done
	lda #0
	sta FX_KIND,x
	dec barrel_events
	jmp .bu_nx
.bu_fuse
	jsr fx_countdown
	bcs .bu_nx
	stx tmp2
	lda FX_TX,x
	sta mapx
	lda FX_TY,x
	sta mapy
	lda #0
	sta FX_KIND,x
	dec barrel_events			; fuse consumed
	jsr explode_tile
	ldx tmp2
.bu_nx
	inx
	cpx #FX_MAX
	bcc .bu_lp
	rts

; X = overlay. Subtract react_dt_units from FX_TIME.
; C=1 still remaining, C=0 expired.
fx_countdown
	lda FX_TIME,x
	beq .fxc_exp
	sec
	sbc react_dt_units
	beq .fxc_z
	bcc .fxc_z
	sta FX_TIME,x
	sec
	rts
.fxc_z
	lda #0
	sta FX_TIME,x
.fxc_exp
	clc
	rts

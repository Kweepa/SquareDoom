!zone enemy

; ============================================================================
; enemy.asm — VicDoom p_enemy.c AI (possessed / imp / demon / caco + shot)
; Think only when SEC_SEEN[sector] (after render). Always camera-facing.
; ============================================================================

MF_JUSTATTACKED = 1
MELEERANGE = 4
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
ITEM_TYPE_FIREBALL = 22
ITEM_TYPE_POSCORPSE = 23
ITEM_TYPE_IMPCORPSE = 24
ITEM_TYPE_DEMONCORPSE = 25
ITEM_TYPE_BARONCORPSE = 26
ITEM_TYPE_PLASMABALL = 27
ITEM_TYPE_ROCKET = 28
ITEM_TYPE_EMPTY_E = $ff

MIN_SPEED = 32
FU_45 = 22

; Scratch (safe after render; column temps free)
; wish_* used for try deltas; save_* for rollback

; ---------------------------------------------------------------------------
; Tables
; ---------------------------------------------------------------------------
mobj_speed
	!byte 3,4,6,5,4
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

xspeed
	!byte MIN_SPEED, FU_45, 0, $ea, $e0, $ea, 0, FU_45	; $ea=-22 $e0=-32
yspeed
	!byte 0, FU_45, MIN_SPEED, FU_45, 0, $ea, $e0, $ea

; ---------------------------------------------------------------------------
; Vars
; ---------------------------------------------------------------------------
enemy_actor		!byte 0
enemy_obj		!byte 0
enemy_dist		!byte 0
enemy_info		!byte 0
alloc_item_slot		!byte 0		; item slot for alloc_mobj (not tmp*)
unlink_mobj_idx		!byte 0		; mobj idx for mobj_unlink
mobj_lookup_slot	!byte 0		; item slot for mobj_for_slot
damage_amount		!byte 0		; enemy_damage / TryDamageEnemy payload
pain_boost		!byte 0		; added to damage for pain-chance check (chainsaw)
tde_best_z		!byte 0		; TryDamageEnemy scan
tde_best_slot		!byte 0
tde_max_z		!byte 0		; exclusive max COL_AIM_Z ($ff = any range)
new_chase_dir_frame	!byte 0
anim_frame		!byte 0
missile_momx_l		!byte 0
missile_momx_h		!byte 0
missile_momy_l		!byte 0
missile_momy_h		!byte 0
missile_momz_l		!byte 0
missile_momz_h		!byte 0
missile_z		!byte 0		; world Z (hitscan-style)
missile_zfrac		!byte 0
procket_momx_l		!byte 0
procket_momx_h		!byte 0
procket_momy_l		!byte 0
procket_momy_h		!byte 0
procket_momz_l		!byte 0
procket_momz_h		!byte 0
procket_z		!byte 0
procket_zfrac		!byte 0
player_sector		!byte 0

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
	lsr tmp2
	clc
	lda tmp2
	adc tmp3
	rts
.pad_y_smaller
	lsr tmp3
	clc
	lda tmp2
	adc tmp3
	rts

; ---------------------------------------------------------------------------
; enemy_reset — clear all mobjs + item maps
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
.er_i
	sta MOBJ_FOR_ITEM,x
	sta ITEM_CORPSE_TEX,x
	inx
	cpx #48				; MAX_ITEMS (literal — defined later in root)
	bne .er_i
	; Reserve missile item slots
	lda #ITEM_TYPE_EMPTY_E
	sta level_item_type + ITEM_MISSILE
	sta level_item_type + ITEM_PLAYER_ROCKET
	lda #0
	sta anim_frame
	sta new_chase_dir_frame
	sta pain_boost
	jsr hitscan_reset
	rts

; ---------------------------------------------------------------------------
; enemy_alloc_all — bind mobjs to item types 1..5 (soldier…baron)
; ---------------------------------------------------------------------------
enemy_alloc_all
	jsr enemy_reset
	ldx #0
.eaa_lp
	lda level_item_type,x
	cmp #ITEM_TYPE_ENEMY_FIRST
	bcc .eaa_nx
	cmp #ITEM_TYPE_ENEMY_LAST+1
	bcs .eaa_nx
	stx alloc_item_slot
	txa
	pha				; alloc_mobj clobbers X
	jsr alloc_mobj
	pla
	tax
.eaa_nx
	inx
	cpx #ITEM_MISSILE		; skip reserved missile slot
	bcc .eaa_lp
	rts

; ---------------------------------------------------------------------------
; mobj_unlink — A = mobj idx; clear every FOR_ITEM[i] that pointed at A
; ---------------------------------------------------------------------------
mobj_unlink
	sta unlink_mobj_idx
	ldx #0
.mu_lp
	lda MOBJ_FOR_ITEM,x
	cmp unlink_mobj_idx
	bne .mu_nx
	lda #$ff
	sta MOBJ_FOR_ITEM,x
.mu_nx
	inx
	cpx #48
	bne .mu_lp
	rts

; ---------------------------------------------------------------------------
; mobj_for_slot — X = item slot → C=0 Y=A=mobj / C=1 none
; MOBJ_OBJ is authoritative; repairs FOR_ITEM when a live owner is found.
; ---------------------------------------------------------------------------
mobj_for_slot
	stx mobj_lookup_slot
	ldx #0
.mfs_lp
	lda MOBJ_ALLOC,x
	beq .mfs_nx
	lda MOBJ_OBJ,x
	cmp mobj_lookup_slot
	bne .mfs_nx
	txa
	ldy mobj_lookup_slot
	sta MOBJ_FOR_ITEM,y		; keep forward map in sync
	tay
	clc
	rts
.mfs_nx
	inx
	cpx #MAX_MOBJ
	bcc .mfs_lp
	lda #$ff
	ldx mobj_lookup_slot
	sta MOBJ_FOR_ITEM,x		; drop stale forward
	sec
	rts

; ---------------------------------------------------------------------------
; alloc_mobj — alloc_item_slot = item → C=0 ok / C=1 fail
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
	txa
	jsr mobj_unlink			; drop any stale FOR_ITEM → this index
	ldx enemy_actor
	lda #1
	sta MOBJ_ALLOC,x
	lda alloc_item_slot
	sta MOBJ_OBJ,x
	tay
	txa
	sta MOBJ_FOR_ITEM,y
	lda #0
	sta MOBJ_MOVEDIR,x
	sta MOBJ_FLAGS,x
	sta MOBJ_MOVECNT,x
	sta MOBJ_XFRAC,x
	sta MOBJ_YFRAC,x
	lda #2
	sta MOBJ_REACT,x
	; info = typeId - 1
	ldy alloc_item_slot
	lda level_item_type,y
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
	ldy alloc_item_slot
	lda #$ff
	sta ITEM_CORPSE_TEX,y
	clc
	rts

; ---------------------------------------------------------------------------
; Helpers: item XY / sector from enemy_obj
; ---------------------------------------------------------------------------
; → A = type at enemy_obj
obj_type
	ldx enemy_obj
	lda level_item_type,x
	rts

; → tmp0=x_h tmp1=y_h
obj_xy
	ldx enemy_obj
	lda level_item_x,x
	sta tmp0
	lda level_item_y,x
	sta tmp1
	rts

; write tmp0/tmp1 as x_h/y_h
obj_set_xy
	ldx enemy_obj
	lda tmp0
	sta level_item_x,x
	lda tmp1
	sta level_item_y,x
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

; sync player_sector
cache_player_sector
	jsr player_tile
	jsr map_sector_id
	sta player_sector
	rts

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
	inc anim_frame
	lda #0
	sta new_chase_dir_frame
	jsr hitscan_frame
	jsr cache_player_sector
	ldx #0
.et_lp
	stx enemy_actor			; loop index (actions may clobber X)
	lda MOBJ_ALLOC,x
	beq .et_nx
	lda MOBJ_OBJ,x
	sta enemy_obj
	lda MOBJ_INFO,x
	sta enemy_info
	; missile always thinks while allocated
	cmp #MOBJINFO_IMPSHOT
	beq .et_run
	; dying must finish even if sector not in view this frame
	ldy MOBJ_STATE,x
	lda state_action,y
	cmp #ACTION_FALL
	beq .et_run
	jsr obj_sector
	beq .et_nx
	tay
	lda SEC_SEEN,y
	beq .et_nx
.et_run
	jsr enemy_single_think
.et_nx
	ldx enemy_actor
	inx
	cpx #MAX_MOBJ
	bcc .et_lp
	rts

enemy_single_think
	ldx enemy_actor
	ldy MOBJ_STATE,x
	lda state_action,y
	; dispatch
	cmp #ACTION_CHASE
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
; P_CheckSight — C=1 can see
; ---------------------------------------------------------------------------
p_check_sight
	jsr obj_sector
	cmp player_sector
	beq .pcs_yes
	tay
	lda SEC_SEEN,y
	bne .pcs_yes
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

; if ((P_Random()>>2) < dist) return false; else true. C=1 ok
p_check_missile_range_fixed
	ldx enemy_actor
	lda MOBJ_REACT,x
	bne .pcm2_no
	jsr p_check_sight
	bcc .pcm2_no
	ldy enemy_info
	lda mobj_melee_state,y
	cmp #$ff
	beq .pcm2_d
	lda enemy_dist
	cmp #6
	bcc .pcm2_no
.pcm2_d
	lda enemy_dist
	cmp #51
	bcc .pcm2_ok
	lda #50
.pcm2_ok
	sta tmp4
	jsr GetRandom8
	lsr
	lsr
	cmp tmp4
	bcc .pcm2_no			; rand>>2 < dist → no
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
	clc
	rts
.ptm_ok
	sec
	rts

; ---------------------------------------------------------------------------
; Missile_TryMove — same as P_TryMove + ortho corners, no floor step snap
; ---------------------------------------------------------------------------
missile_try_move
	jsr obj_xy
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
	; both axes changed tile → require ortho corners open
	lda mapx
	cmp tmp4
	beq .mtm_dest
	lda mapy
	cmp tmp5
	beq .mtm_dest
	; corner (new_x, old_y)
	lda tmp5
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcs .mtm_block
	; corner (old_x, new_y)
	lda tmp4
	sta mapx
	lda tmp1
	lsr
	lsr
	lsr
	sta mapy
	jsr sector_at_map
	jsr missile_tile_blocked
	bcs .mtm_block
	; restore dest map tile
	lda tmp0
	lsr
	lsr
	lsr
	sta mapx
.mtm_dest
	jsr sector_at_map
	jsr missile_tile_blocked
	bcc .mtm_ok
.mtm_block
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
	clc
	rts
.mtm_ok
	sec
	rts

; A = sector id → C=1 blocked (void / closed door only; no floor steps)
missile_tile_blocked
	cmp #0
	beq .mtb_yes
	tax
	lda SEC_CEIL,x
	sec
	sbc SEC_FLOOR,x
	cmp #4
	bcc .mtb_yes
	clc
	rts
.mtb_yes
	sec
	rts

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

; A = signed speed component, Y = speed (1..n)
; → wish_x = A * Y (signed 16-bit)
mul_speed_comp
	sta tmp2
	sty tmp3
	lda #0
	sta wish_x_l
	sta wish_x_h
	lda tmp3
	beq .msc_done			; speed 0 → 0
	lda tmp2
	bne .msc_nz
.msc_done
	rts
.msc_nz
	bpl .msc_pos
	; negative: product = -(speed * |comp|)
	eor #$ff
	clc
	adc #1
	sta tmp2
	ldx tmp3
	lda #0
	sta tmp4
	sta tmp5
.msc_nl
	clc
	lda tmp4
	adc tmp2
	sta tmp4
	lda tmp5
	adc #0
	sta tmp5
	dex
	bne .msc_nl
	lda tmp4
	eor #$ff
	clc
	adc #1
	sta wish_x_l
	lda tmp5
	eor #$ff
	adc #0
	sta wish_x_h
	rts
.msc_pos
	ldx tmp3
.msc_pl
	clc
	lda wish_x_l
	adc tmp2
	sta wish_x_l
	lda wish_x_h
	adc #0
	sta wish_x_h
	dex
	bne .msc_pl
	rts

; ---------------------------------------------------------------------------
; P_Move — C=1 ok
; ---------------------------------------------------------------------------
p_move
	ldx enemy_actor
	lda MOBJ_MOVEDIR,x
	cmp #DI_NODIR
	bne .pm_dir
	clc
	rts
.pm_dir
	jsr calc_enemy_dist
	lda enemy_dist
	cmp #MELEERANGE
	bcc .pm_ok_close
	; trydx = speed * xspeed[dir]
	ldx enemy_actor
	lda MOBJ_MOVEDIR,x
	tay
	lda xspeed,y
	sta tmp4				; component
	lda MOBJ_INFO,x
	tay
	lda mobj_speed,y
	tay					; Y = speed
	lda tmp4
	jsr mul_speed_comp		; → wish_x
	lda wish_x_l
	sta tmp0
	lda wish_x_h
	sta tmp1
	; trydy
	ldx enemy_actor
	lda MOBJ_MOVEDIR,x
	tay
	lda yspeed,y
	sta tmp4
	lda MOBJ_INFO,x
	tay
	lda mobj_speed,y
	tay
	lda tmp4
	jsr mul_speed_comp
	lda wish_x_l
	sta wish_y_l
	lda wish_x_h
	sta wish_y_h
	lda tmp0
	sta wish_x_l
	lda tmp1
	sta wish_x_h
	jmp p_try_move
.pm_ok_close
	sec
	rts

p_try_walk
	jsr p_move
	bcc .ptw_no
	jsr GetRandom8
	and #3
	clc
	adc #3
	ldx enemy_actor
	sta MOBJ_MOVECNT,x
	sec
	rts
.ptw_no
	clc
	rts

; ---------------------------------------------------------------------------
; P_NewChaseDir
; ---------------------------------------------------------------------------
p_new_chase_dir
	lda new_chase_dir_frame
	beq .pncd_go
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
	lda #3
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
	dec MOBJ_REACT,x
.ac_nort
	lda MOBJ_FLAGS,x
	and #MF_JUSTATTACKED
	beq .ac_melee
	lda MOBJ_FLAGS,x
	and #$fe				; clear MF_JUSTATTACKED
	sta MOBJ_FLAGS,x
	jmp p_new_chase_dir
.ac_melee
	ldy enemy_info
	lda mobj_melee_state,y
	cmp #$ff
	beq .ac_missile
	jsr p_check_melee_range
	bcc .ac_missile
	ldx enemy_actor
	lda #0
	sta MOBJ_MOVECNT,x
	ldy enemy_info
	lda mobj_melee_state,y
	sta MOBJ_STATE,x
	rts
.ac_missile
	ldy enemy_info
	lda mobj_shoot_state,y
	cmp #$ff
	beq .ac_move
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
	beq .ac_move			; waiting — keep walk chase
	cmp #HS_CLEAR
	beq .ac_hs_fire
	cmp #HS_BLOCKED
	beq .ac_hs_miss
.ac_hs_try
	jsr p_check_missile_range_fixed
	bcc .ac_move
	ldx enemy_actor
	jsr hitscan_request
	bcs .ac_move			; another enemy already claimed this frame
	lda hs_status
	cmp #HS_CLEAR
	beq .ac_hs_fire
	jmp .ac_move			; PENDING (or unexpected)
.ac_hs_fire
	ldy enemy_info
	lda mobj_shoot_state,y
	ldx enemy_actor
	sta MOBJ_STATE,x
	lda MOBJ_FLAGS,x
	ora #MF_JUSTATTACKED
	sta MOBJ_FLAGS,x
	rts
.ac_hs_miss
	jsr hitscan_release
	jsr GetRandom8
	and #7
	ldx enemy_actor
	sta MOBJ_REACT,x
	jmp .ac_move
.ac_missile_direct
	jsr p_check_missile_range_fixed
	bcc .ac_move
	ldy enemy_info
	lda mobj_shoot_state,y
	ldx enemy_actor
	sta MOBJ_STATE,x
	lda MOBJ_FLAGS,x
	ora #MF_JUSTATTACKED
	sta MOBJ_FLAGS,x
	rts
.ac_move
	ldx enemy_actor
	dec MOBJ_MOVECNT,x
	lda MOBJ_MOVECNT,x
	bmi .ac_newdir
	jsr p_move
	bcs .ac_snd
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

; Hold pain state for MOVECNT thinks (set in enemy_damage). Old path
; jumped to chase the same frame as the hit — pain never reached a render.
a_flinch
	ldx enemy_actor
	lda MOBJ_HEALTH,x
	beq .afl_dead			; 0 HP must not return to chase
	lda MOBJ_MOVECNT,x
	beq .afl_done
	dec MOBJ_MOVECNT,x
	lda MOBJ_MOVECNT,x
	beq .afl_done
	rts
.afl_done
	jmp goto_chase_state
.afl_dead
	lda #2
	sta MOBJ_MOVECNT,x
	ldy enemy_info
	lda mobj_death_state,y
	sta MOBJ_STATE,x
	rts

; Hitscan already CLEAR (chase only enters POSSHOOT then). Accuracy + damage.
a_shoot
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
	jsr GetRandom8
	and #7
	ldx enemy_actor
	sta MOBJ_REACT,x
	jmp goto_chase_state

a_melee
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	bne .ame_done
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
	inc MOBJ_MOVECNT,x
	rts
.ame_done
	jmp goto_chase_state

a_missile
	lda MOBJ_ALLOC + MOBJ_MISSILE
	beq .ami_spawn
	jmp .ami_react
.ami_spawn
	; Aim like hitscan: (x0,y0,z0=floor+2) → (player, eyeheight), free dx/dy/dz
	jsr obj_sector
	tay
	lda SEC_FLOOR,y
	clc
	adc #2
	sta missile_z
	lda #0
	sta missile_zfrac
	lda eyeheight
	sec
	sbc missile_z
	sta tmp4				; dz (signed)
	jsr obj_xy
	lda playerx_h
	sec
	sbc tmp0
	sta fracy				; dx
	lda playery_h
	sec
	sbc tmp1
	sta fracx				; dy
	; dist = P_AproxDistance(dx,dy), min 1
	lda fracy
	sta tmp0
	lda fracx
	sta tmp1
	jsr p_approx_distance
	bne .ami_dnz
	lda #1
.ami_dnz
	sta span_a
	; mom* = (d* << 8) / dist  (8.8 toward player; arrives together if still)
	lda fracy
	jsr missile_scale_mom
	lda wish_x_l
	sta missile_momx_l
	lda wish_x_h
	sta missile_momx_h
	lda fracx
	jsr missile_scale_mom
	lda wish_x_l
	sta missile_momy_l
	lda wish_x_h
	sta missile_momy_h
	lda tmp4
	jsr missile_scale_mom
	lda wish_x_l
	sta missile_momz_l
	lda wish_x_h
	sta missile_momz_h
	; spawn at enemy pos
	jsr obj_xy
	lda enemy_info
	cmp #MOBJINFO_BARON
	bne .ami_fb
	lda #ITEM_TYPE_PLASMABALL
	bne .ami_type
.ami_fb
	lda #ITEM_TYPE_FIREBALL
.ami_type
	sta level_item_type + ITEM_MISSILE
	lda tmp0
	sta level_item_x + ITEM_MISSILE
	lda tmp1
	sta level_item_y + ITEM_MISSILE
	ldx #MOBJ_MISSILE
	lda #1
	sta MOBJ_ALLOC,x
	lda #ITEM_MISSILE
	sta MOBJ_OBJ,x
	txa
	sta MOBJ_FOR_ITEM + ITEM_MISSILE
	lda #MOBJINFO_IMPSHOT
	sta MOBJ_INFO,x
	lda #STATE_IMPSHOTFLY
	sta MOBJ_STATE,x
	lda #0
	sta MOBJ_XFRAC,x
	sta MOBJ_YFRAC,x
	sta MOBJ_FLAGS,x
	lda #48
	sta MOBJ_MOVECNT,x
	; damage payload in health
	lda enemy_info
	cmp #MOBJINFO_IMP
	bne .ami_caco
	lda #10
	bne .ami_hp
.ami_caco
	lda #30
.ami_hp
	sta MOBJ_HEALTH,x
.ami_react
	jsr GetRandom8
	and #7
	ldx enemy_actor
	sta MOBJ_REACT,x
	jmp goto_chase_state

; A = signed delta, span_a = dist ≥ 1 → wish_x = ((delta<<8)/dist)*8 as signed 8.8
; (*8 = VicDoom <<=2 then ×2 more for feel)
missile_scale_mom
	sta tmp2
	lda #0
	sta aux_l
	lda tmp2
	bpl .msm_abs
	eor #$ff
	clc
	adc #1
.msm_abs
	sta aux_h
	lda span_a
	jsr udiv16x8
	sta wish_x_l
	lda #0
	sta wish_x_h
	lda tmp2
	bpl .msm_scl
	lda #0
	sec
	sbc wish_x_l
	sta wish_x_l
	lda #0
	sbc wish_x_h
	sta wish_x_h
.msm_scl
	asl wish_x_l
	rol wish_x_h
	asl wish_x_l
	rol wish_x_h
	asl wish_x_l
	rol wish_x_h
	rts

a_fall
	ldx enemy_actor
	lda MOBJ_MOVECNT,x
	beq .af_corpse			; already 0 — do not dec into $FF
	dec MOBJ_MOVECNT,x
	lda MOBJ_MOVECNT,x
	bne .af_done
.af_corpse
	; pos/imp/demon → 24–26; baron → 27; caco → ITEM_CORPSE_TEX stub
	lda MOBJ_INFO,x
	cmp #MOBJINFO_BARON
	beq .af_baron
	cmp #MOBJINFO_CACO
	bcs .af_stub			; caco / missile
	ldy MOBJ_OBJ,x
	clc
	adc #ITEM_TYPE_POSCORPSE	; 0→23, 1→24, 2→25
	sta level_item_type,y
	jmp .af_free
.af_baron
	ldy MOBJ_OBJ,x
	lda #ITEM_TYPE_BARONCORPSE
	sta level_item_type,y
	jmp .af_free
.af_stub
	lda MOBJ_STATE,x
	tay
	lda state_texture,y
	and #$bf				; clear TEX_ANIMATE
	ldy MOBJ_OBJ,x
	sta ITEM_CORPSE_TEX,y
.af_free
	ldx enemy_actor
	txa				; mobj idx
	jsr mobj_unlink
	ldx enemy_actor
	lda #0
	sta MOBJ_ALLOC,x
.af_done
	rts

a_fly
	ldx enemy_actor
	cpx #MOBJ_PLAYER_ROCKET
	bne .afy_enemy
	jmp a_fly_player
.afy_enemy
	jsr calc_enemy_dist
	lda enemy_dist
	cmp #3
	bcs .afy_move
	; close in XY — also require Z near eye (hitscan endpoint)
	lda missile_z
	sec
	sbc eyeheight
	bpl .afy_zok
	eor #$ff
	clc
	adc #1
.afy_zok
	cmp #3
	bcs .afy_move
	ldx enemy_actor
	lda MOBJ_HEALTH,x
	sta tmp0
	jsr GetRandom8
	and #15
	clc
	adc tmp0
	jsr damage_player
	jmp .afy_die
.afy_move
	lda missile_momx_l
	sta wish_x_l
	lda missile_momx_h
	sta wish_x_h
	lda missile_momy_l
	sta wish_y_l
	lda missile_momy_h
	sta wish_y_h
	jsr missile_try_move
	bcc .afy_boom
	; Z step (hitscan-style height along the ray)
	clc
	lda missile_zfrac
	adc missile_momz_l
	sta missile_zfrac
	lda missile_z
	adc missile_momz_h
	sta missile_z
	jsr obj_sector
	beq .afy_boom
	tax
	lda SEC_FLOOR,x
	cmp missile_z
	bcs .afy_boom			; z ≤ floor
	lda SEC_CEIL,x
	cmp missile_z
	beq .afy_boom
	bcc .afy_boom			; z ≥ ceil
	ldx enemy_actor
	dec MOBJ_MOVECNT,x
	lda MOBJ_MOVECNT,x
	bmi .afy_die
	rts
.afy_boom
	; radius attack
	lda enemy_dist
	cmp #4
	bcs .afy_die
	ldx enemy_actor
	lda MOBJ_HEALTH,x
	sta tmp0
	jsr GetRandom8
	and #15
	clc
	adc tmp0
	jsr damage_player
.afy_die
	lda #ITEM_TYPE_EMPTY_E
	sta level_item_type + ITEM_MISSILE
	lda #$ff
	sta MOBJ_FOR_ITEM + ITEM_MISSILE
	ldx #MOBJ_MISSILE
	lda #0
	sta MOBJ_ALLOC,x
	rts

; Player rocket flight — damages enemies on XY contact; no splash
a_fly_player
	jsr procket_try_hit
	bcs .afp_die
	lda procket_momx_l
	sta wish_x_l
	lda procket_momx_h
	sta wish_x_h
	lda procket_momy_l
	sta wish_y_l
	lda procket_momy_h
	sta wish_y_h
	jsr missile_try_move
	bcc .afp_die
	clc
	lda procket_zfrac
	adc procket_momz_l
	sta procket_zfrac
	lda procket_z
	adc procket_momz_h
	sta procket_z
	jsr obj_sector
	beq .afp_die
	tax
	lda SEC_FLOOR,x
	cmp procket_z
	bcs .afp_die
	lda SEC_CEIL,x
	cmp procket_z
	beq .afp_die
	bcc .afp_die
	ldx enemy_actor
	dec MOBJ_MOVECNT,x
	lda MOBJ_MOVECNT,x
	bmi .afp_die
	rts
.afp_die
	lda #ITEM_TYPE_EMPTY_E
	sta level_item_type + ITEM_PLAYER_ROCKET
	lda #$ff
	sta MOBJ_FOR_ITEM + ITEM_PLAYER_ROCKET
	ldx #MOBJ_PLAYER_ROCKET
	lda #0
	sta MOBJ_ALLOC,x
	rts

; C=1 if rocket hit an enemy (damaged). Uses ITEM_PLAYER_ROCKET pos.
procket_try_hit
	lda level_item_x + ITEM_PLAYER_ROCKET
	sta save_xh
	lda level_item_y + ITEM_PLAYER_ROCKET
	sta save_yh
	ldx #0
.pth_lp
	lda MOBJ_ALLOC,x
	beq .pth_nx
	lda MOBJ_INFO,x
	cmp #MOBJINFO_IMPSHOT
	bcs .pth_nx
	ldy MOBJ_OBJ,x
	lda level_item_x,y
	sec
	sbc save_xh
	sta tmp0
	lda level_item_y,y
	sec
	sbc save_yh
	sta tmp1
	stx tmp5			; mobj idx
	sty tmp4			; item slot
	jsr p_approx_distance
	cmp #3
	bcs .pth_rest
	; hit — damage from rocket HEALTH payload + rand
	ldx #MOBJ_PLAYER_ROCKET
	lda MOBJ_HEALTH,x
	sta tmp0
	jsr GetRandom8
	and #15
	clc
	adc tmp0
	ldx tmp4
	jsr enemy_damage
	sec
	rts
.pth_rest
	ldx tmp5
.pth_nx
	inx
	cpx #MOBJ_PLAYER_ROCKET
	bcc .pth_lp
	clc
	rts

; Spawn player rocket along look direction. C=0 spawned, C=1 busy/fail.
spawn_player_rocket
	lda MOBJ_ALLOC + MOBJ_PLAYER_ROCKET
	beq .spr_ok
	sec
	rts
.spr_ok
	lda playerx_h
	sta level_item_x + ITEM_PLAYER_ROCKET
	lda playery_h
	sta level_item_y + ITEM_PLAYER_ROCKET
	lda #ITEM_TYPE_ROCKET
	sta level_item_type + ITEM_PLAYER_ROCKET
	lda eyeheight
	sta procket_z
	lda #0
	sta procket_zfrac
	sta procket_momz_l
	sta procket_momz_h
	; mom = (sin, −cos)/8 as signed 8.8 — matches walk forward
	ldy playera
	lda sintab,y
	jsr procket_scale_mom
	lda wish_x_l
	sta procket_momx_l
	lda wish_x_h
	sta procket_momx_h
	lda playera
	clc
	adc #64
	tay
	lda sintab,y
	jsr neg_a
	jsr procket_scale_mom
	lda wish_x_l
	sta procket_momy_l
	lda wish_x_h
	sta procket_momy_h
	ldx #MOBJ_PLAYER_ROCKET
	lda #1
	sta MOBJ_ALLOC,x
	lda #ITEM_PLAYER_ROCKET
	sta MOBJ_OBJ,x
	txa
	sta MOBJ_FOR_ITEM + ITEM_PLAYER_ROCKET
	lda #MOBJINFO_IMPSHOT
	sta MOBJ_INFO,x
	lda #STATE_IMPSHOTFLY
	sta MOBJ_STATE,x
	lda #0
	sta MOBJ_XFRAC,x
	sta MOBJ_YFRAC,x
	sta MOBJ_FLAGS,x
	lda #48
	sta MOBJ_MOVECNT,x
	; damage payload (was hitscan rocket)
	jsr GetRandom8
	lsr
	lsr
	clc
	adc #20
	sta MOBJ_HEALTH,x
	clc
	rts

; A = signed sintab (-64..64) → wish_x = A/8 as signed 8.8 (hi=A/8, lo=0)
procket_scale_mom
	sta tmp2
	lda #0
	sta wish_x_l
	lda tmp2
	bpl .psm_pos
	eor #$ff
	clc
	adc #1
	lsr
	lsr
	lsr
	eor #$ff
	clc
	adc #1
	sta wish_x_h
	rts
.psm_pos
	lsr
	lsr
	lsr
	sta wish_x_h
	rts

; ---------------------------------------------------------------------------
; enemy_damage — X = item slot, A = damage
; ---------------------------------------------------------------------------
enemy_damage
	sta damage_amount
	jsr mobj_for_slot
	bcs .ed_rts
	lda MOBJ_HEALTH,y
	beq .ed_rts
	sty enemy_actor
	lda MOBJ_OBJ,y
	sta enemy_obj
	lda MOBJ_INFO,y
	sta enemy_info
	cmp #MOBJINFO_IMPSHOT
	bcs .ed_rts
	; P_DamageMobj
	lda MOBJ_HEALTH,y
	sec
	sbc damage_amount
	sta MOBJ_HEALTH,y
	beq .ed_kill
	bcc .ed_kill
	lda MOBJ_FLAGS,y
	ora #MF_JUSTATTACKED
	sta MOBJ_FLAGS,y
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
	cmp #$ff			; baron: never flinch
	beq .ed_rts
	lda mobj_pain_state,y
	ldx enemy_actor
	sta MOBJ_STATE,x
	lda #4				; ~4 thinks of pain before chase
	sta MOBJ_MOVECNT,x
	rts
.ed_kill
	ldx enemy_actor
	lda #0
	sta MOBJ_HEALTH,x
	lda #2
	sta MOBJ_MOVECNT,x
	ldy enemy_info
	lda mobj_death_sound,y
	jsr play_sound			; preserves X/Y; reload actor anyway
	ldx enemy_actor
	ldy enemy_info
	lda mobj_death_state,y
	sta MOBJ_STATE,x
.ed_rts
	rts

; ---------------------------------------------------------------------------
; enemy_get_texture — X = item slot → A = tex (bit6=animate), C=1 if 16×32
; Live enemies (types 1–5) use enemy_sprites; pos/imp/demon/baron corpses are
; item types 24–27. Caco still uses ITEM_CORPSE_TEX until art exists.
; ---------------------------------------------------------------------------
enemy_get_texture
	lda level_item_type,x
	cmp #ITEM_TYPE_ENEMY_FIRST
	bcc .egt_item8
	cmp #ITEM_TYPE_ENEMY_LAST+1
	bcs .egt_item8
	lda ITEM_CORPSE_TEX,x
	cmp #$ff
	beq .egt_live
	sec
	rts				; A = corpse tex stub (caco)
.egt_live
	jsr mobj_for_slot		; X = item slot
	bcs .egt_item8
	lda MOBJ_INFO,y
	cmp #MOBJINFO_IMPSHOT		; missile uses fireball item atlas
	bcs .egt_item8
	lda MOBJ_STATE,y
	tay
	lda state_texture,y
	sec
	rts
.egt_item8
	lda #0
	clc
	rts

; ---------------------------------------------------------------------------
; TryDamageEnemy — A = damage; nearest live enemy on MUZZLE±AIM_COL_SLACK
; via COL_AIM_* (per-column stamp; pick lowest COL_AIM_Z in the cone).
; TryDamageMelee — same, but only if COL_AIM_Z < MELEERANGE.
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
	cmp #$ff
	beq .tde_nx
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
	cmp #$ff
	beq .tde_rts
	lda tde_max_z
	cmp #$ff
	beq .tde_slot
	lda tde_best_z
	cmp tde_max_z
	bcs .tde_rts			; too far for melee
.tde_slot
	ldx tde_best_slot
	jsr mobj_for_slot
	bcs .tde_rts
	lda MOBJ_HEALTH,y
	beq .tde_rts
	lda MOBJ_INFO,y
	cmp #MOBJINFO_IMPSHOT
	bcs .tde_rts
	ldx tde_best_slot
	lda damage_amount
	jmp enemy_damage
.tde_rts
	rts

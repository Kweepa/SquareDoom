; Walk-over pickups + top-line info messages (pickup / locked door)
!zone pickup

PICKUP_RADIUS = 4
INFO_MS_L = <4000
INFO_MS_H = >4000
AMMO_ADD = 10
AMMO_BULLETS_MAX = 200
AMMO_BULLETS_PACK = 250
AMMO_SHELLS_MAX = 50
AMMO_SHELLS_PACK = 100
AMMO_ROCKETS_MAX = 50
AMMO_ROCKETS_PACK = 100
HEALTH_ADD = 25
HEALTH_MAX = 100
HEALTH_SOUL = 100
HEALTH_MEGA_MAX = 200
ARMOR_GREEN = 100
ARMOR_BLUE = 200

; MSG_LETTER0 / letter bank — see squaredoom.asm (MSG_LET0)
INFO_COLOR = 7				; yellow

; 0 = "picked up the "+name+"."; 1 = full string at info_name
; info_kind / ammo_* / combat_armor / owned_weapons — under-stack scrap (zeropage.asm)

; Weapon id → ammo reserve index (0=bullets, 1=shells, 2=rockets)
; fist/chainsaw unused by fire path; pistol=2 … rocket=5
wpn_ammo_idx
	!byte 0, 0, 0, 1, 0, 2

ammo_max_base
	!byte AMMO_BULLETS_MAX, AMMO_SHELLS_MAX, AMMO_ROCKETS_MAX
ammo_max_pack
	!byte AMMO_BULLETS_PACK, AMMO_SHELLS_PACK, AMMO_ROCKETS_PACK

; cur_weapon 1..5 → ownership bit (id 0 fist = always)
wpn_own_bit
	!byte 0, $01, $02, $04, $08, $10

ITEM_TYPE_HEALTH = 7
ITEM_TYPE_SHELLS = 8
ITEM_TYPE_SHOTGUN = 9
ITEM_TYPE_CHAINGUN = 10
ITEM_TYPE_CHAINSAW = 11
ITEM_TYPE_ROCKETLAUNCHER = 12
ITEM_TYPE_GREENARMOR = 13
ITEM_TYPE_BLUEARMOR = 14
ITEM_TYPE_BACKPACK = 15
ITEM_TYPE_REDCARD = 16
ITEM_TYPE_BLUECARD = 17
ITEM_TYPE_YELLOWCARD = 18
ITEM_TYPE_SOULSPHERE = 19
ITEM_TYPE_RADSUIT = 20
ITEM_TYPE_HEALTHBONUS = 21
ITEM_TYPE_ARMORBONUS = 22
ITEM_TYPE_CLIP = 23
ITEM_TYPE_SHELLBOX = 24
ITEM_TYPE_AMMOBOX = 25
ITEM_TYPE_HEALTHCRATE = 26
ITEM_TYPE_POSCORPSE = 34
ITEM_TYPE_EMPTY = $ff
ITEM_TYPE_PICKUP_LAST = ITEM_TYPE_HEALTHCRATE

HEALTH_BONUS = 1
ARMOR_BONUS = 1
HEALTH_STIM = 10
CLIP_ADD = 10
AMMOBOX_ADD = 50
SHELLBOX_ADD = 20
ARMOR_BONUS_MAX = 200

; ---------------------------------------------------------------------------
; add_ammo — Y = pool 0/1/2, A = amount; clamp to current max; sets hud_dirty
; ---------------------------------------------------------------------------
add_ammo
	sta tmp2
	lda has_backpack
	bne .aa_pack
	lda ammo_max_base,y
	bne .aa_max
.aa_pack
	lda ammo_max_pack,y
.aa_max
	sta tmp1
	lda ammo_bullets,y
	clc
	adc tmp2
	bcs .aa_clamp
	cmp tmp1
	bcc .aa_store
.aa_clamp
	lda tmp1
.aa_store
	sta ammo_bullets,y
	lda #1
	sta hud_dirty
	rts

; ---------------------------------------------------------------------------
; try_pickups — after apply_move; player-tile layer, then guts from corpses
; ---------------------------------------------------------------------------
try_pickups
	jsr player_tile
	jsr item_layer_id
	beq .tp_guts
	cmp #ITEM_TYPE_HEALTH
	bcc .tp_guts
	cmp #ITEM_TYPE_PICKUP_LAST + 1
	bcs .tp_guts
	sta tmp4			; typeId
	jsr pickup_apply
	bcc .tp_guts			; not taken
	inc num_items_got
	jsr item_layer_ptr
	lda #0
	tay
	sta (ptr_l),y
	rts
.tp_guts
	ldx #0
.tp_gl
	lda MOBJ_ALLOC,x
	beq .tp_gn
	lda MOBJ_INFO,x
	cmp #MOBJINFO_POS
	bne .tp_gn
	lda MOBJ_HEALTH,x
	bne .tp_gn
	lda MOBJ_FLAGS,x
	and #MF_GUTS_TAKEN
	bne .tp_gn
	lda MOBJ_X,x
	sta tmp0
	lda MOBJ_Y,x
	sta tmp1
	lda tmp0
	sec
	sbc playerx_h
	bcs .tp_gdx
	eor #$ff
	adc #1
.tp_gdx
	cmp #PICKUP_RADIUS
	bcs .tp_gn
	lda tmp1
	sec
	sbc playery_h
	bcs .tp_gdy
	eor #$ff
	adc #1
.tp_gdy
	cmp #PICKUP_RADIUS
	bcs .tp_gn
	stx tmp5
	lda MOBJ_FLAGS,x
	ora #MF_GUTS_TAKEN
	sta MOBJ_FLAGS,x
	lda #ITEM_TYPE_POSCORPSE
	sta tmp4
	jsr pickup_apply
	rts
.tp_gn
	inx
	cpx #MOBJ_PLAYER_ROCKET
	bcc .tp_gl
	rts

; ---------------------------------------------------------------------------
; pickup_apply — A = typeId; C=1 if taken (message set), C=0 if refused
; ---------------------------------------------------------------------------
pickup_apply
	cmp #ITEM_TYPE_POSCORPSE
	bne .pa_tab
	jmp .pa_poscorpse
.pa_tab
	sec
	sbc #ITEM_TYPE_HEALTH
	cmp #ITEM_TYPE_PICKUP_LAST - ITEM_TYPE_HEALTH + 1
	bcc .pa_ok
	clc
	rts
.pa_ok
	tay				; index = typeId - HEALTH (lo/hi tables)
	lda .pa_jmp_lo,y
	sta ptr_l
	lda .pa_jmp_hi,y
	sta ptr_h
	jmp (ptr_l)

.pa_jmp_lo
	!byte <.pa_health, <.pa_shells, <.pa_weapon, <.pa_weapon
	!byte <.pa_weapon, <.pa_weapon, <.pa_garmor, <.pa_barmor
	!byte <.pa_pack, <.pa_red, <.pa_blue, <.pa_yellow
	!byte <.pa_soulsphere, <.pa_radsuit
	!byte <.pa_hbonus, <.pa_abonus, <.pa_clip, <.pa_shellbox
	!byte <.pa_ammobox, <.pa_stim
.pa_jmp_hi
	!byte >.pa_health, >.pa_shells, >.pa_weapon, >.pa_weapon
	!byte >.pa_weapon, >.pa_weapon, >.pa_garmor, >.pa_barmor
	!byte >.pa_pack, >.pa_red, >.pa_blue, >.pa_yellow
	!byte >.pa_soulsphere, >.pa_radsuit
	!byte >.pa_hbonus, >.pa_abonus, >.pa_clip, >.pa_shellbox
	!byte >.pa_ammobox, >.pa_stim

.pa_health
	lda health
	cmp #HEALTH_MAX
	bcc .pa_health_go
	jmp .pa_no
.pa_health_go
	clc
	adc #HEALTH_ADD
	cmp #HEALTH_MAX
	bcc .pa_hok
	lda #HEALTH_MAX
.pa_hok
	sta health
	lda #ITEM_TYPE_HEALTH
	jmp pickup_message

.pa_shells
	ldy #1				; shells pool
	lda has_backpack
	bne .pa_smax
	lda ammo_max_base,y
	bne .pa_scap
.pa_smax
	lda ammo_max_pack,y
.pa_scap
	cmp ammo_shells
	beq .pa_shells_full
	bcc .pa_shells_full
	lda #AMMO_ADD
	jsr add_ammo
	lda #ITEM_TYPE_SHELLS
	jmp pickup_message
.pa_shells_full
	jmp .pa_no

.pa_garmor
	lda armor
	cmp #ARMOR_GREEN
	bcc .pa_garmor_go
	jmp .pa_no
.pa_garmor_go
	lda #ARMOR_GREEN
	sta armor
	lda #0
	sta combat_armor
	lda #ITEM_TYPE_GREENARMOR
	jmp pickup_message

.pa_barmor
	lda armor
	cmp #ARMOR_BLUE
	bcc .pa_barmor_go
	jmp .pa_no
.pa_barmor_go
	lda #ARMOR_BLUE
	sta armor
	lda #1
	sta combat_armor
	lda #ITEM_TYPE_BLUEARMOR
	jmp pickup_message

.pa_pack
	lda has_backpack
	bne .pa_pack_ammo
	lda #1
	sta has_backpack
.pa_pack_ammo
	ldy #0
	lda #10
	jsr add_ammo
	ldy #1
	lda #4
	jsr add_ammo
	ldy #2
	lda #1
	jsr add_ammo
	lda #ITEM_TYPE_BACKPACK
	jmp pickup_message

.pa_red
	lda keys
	ora #$01
	sta keys
	lda #ITEM_TYPE_REDCARD
	jmp pickup_message

.pa_blue
	lda keys
	ora #$04
	sta keys
	lda #ITEM_TYPE_BLUECARD
	jmp pickup_message

.pa_yellow
	lda keys
	ora #$02
	sta keys
	lda #ITEM_TYPE_YELLOWCARD
	jmp pickup_message

.pa_soulsphere
	lda health
	cmp #HEALTH_MEGA_MAX
	bcc .pa_soul_go
	jmp .pa_no
.pa_soul_go
	clc
	adc #HEALTH_SOUL
	bcs .pa_soul_clamp
	cmp #HEALTH_MEGA_MAX
	bcc .pa_soul_ok
.pa_soul_clamp
	lda #HEALTH_MEGA_MAX
.pa_soul_ok
	sta health
	lda #ITEM_TYPE_SOULSPHERE
	jmp pickup_message

.pa_radsuit
	lda #<RADSUIT_MS
	sta radsuit_ms
	lda #>RADSUIT_MS
	sta radsuit_ms + 1
	lda #ITEM_TYPE_RADSUIT
	jmp pickup_message

.pa_weapon
	lda tmp4
	cmp #ITEM_TYPE_SHOTGUN
	beq .pa_w_sg
	cmp #ITEM_TYPE_CHAINGUN
	beq .pa_w_cg
	cmp #ITEM_TYPE_ROCKETLAUNCHER
	beq .pa_w_rl
	; chainsaw — own bit0, switch to 1
	lda owned_weapons
	ora #$01
	sta owned_weapons
	ldx #1
	jsr switch_weapon
	lda #ITEM_TYPE_CHAINSAW
	jmp pickup_message
.pa_w_sg
	lda owned_weapons
	ora #$04
	sta owned_weapons
	ldy #1
	lda #8
	jsr add_ammo
	ldx #3
	jsr switch_weapon
	lda #ITEM_TYPE_SHOTGUN
	jmp pickup_message
.pa_w_cg
	lda owned_weapons
	ora #$08
	sta owned_weapons
	ldy #0
	lda #20
	jsr add_ammo
	ldx #4
	jsr switch_weapon
	lda #ITEM_TYPE_CHAINGUN
	jmp pickup_message
.pa_w_rl
	lda owned_weapons
	ora #$10
	sta owned_weapons
	ldy #2
	lda #2
	jsr add_ammo
	ldx #5
	jsr switch_weapon
	lda #ITEM_TYPE_ROCKETLAUNCHER
	jmp pickup_message

.pa_hbonus
	lda health
	cmp #ARMOR_BONUS_MAX
	bcs .pa_hbonus_no
	clc
	adc #HEALTH_BONUS
	cmp #ARMOR_BONUS_MAX + 1
	bcc .pa_hbonus_ok
	lda #ARMOR_BONUS_MAX
.pa_hbonus_ok
	sta health
	lda #ITEM_TYPE_HEALTHBONUS
	jmp pickup_message
.pa_hbonus_no
	jmp .pa_no

.pa_abonus
	lda armor
	cmp #ARMOR_BONUS_MAX
	bcs .pa_abonus_no
	clc
	adc #ARMOR_BONUS
	cmp #ARMOR_BONUS_MAX + 1
	bcc .pa_abonus_ok
	lda #ARMOR_BONUS_MAX
.pa_abonus_ok
	sta armor
	lda #ITEM_TYPE_ARMORBONUS
	jmp pickup_message
.pa_abonus_no
	jmp .pa_no

.pa_clip
	ldy #0
	lda has_backpack
	bne .pa_clip_chk
	lda ammo_max_base,y
	bne .pa_clip_cap
.pa_clip_chk
	lda ammo_max_pack,y
.pa_clip_cap
	cmp ammo_bullets
	beq .pa_clip_full
	bcc .pa_clip_full
	lda #CLIP_ADD
	jsr add_ammo
	lda #ITEM_TYPE_CLIP
	jmp pickup_message
.pa_clip_full
	jmp .pa_no

.pa_shellbox
	ldy #1
	lda has_backpack
	bne .pa_sb_chk
	lda ammo_max_base,y
	bne .pa_sb_cap
.pa_sb_chk
	lda ammo_max_pack,y
.pa_sb_cap
	cmp ammo_shells
	beq .pa_sb_full
	bcc .pa_sb_full
	lda #SHELLBOX_ADD
	jsr add_ammo
	lda #ITEM_TYPE_SHELLBOX
	jmp pickup_message
.pa_sb_full
	jmp .pa_no

.pa_ammobox
	ldy #0
	lda has_backpack
	bne .pa_ab_chk
	lda ammo_max_base,y
	bne .pa_ab_cap
.pa_ab_chk
	lda ammo_max_pack,y
.pa_ab_cap
	cmp ammo_bullets
	beq .pa_ab_full
	bcc .pa_ab_full
	lda #AMMOBOX_ADD
	jsr add_ammo
	lda #ITEM_TYPE_AMMOBOX
	jmp pickup_message
.pa_ab_full
	jmp .pa_no

.pa_stim
	lda health
	cmp #HEALTH_MAX
	bcs .pa_stim_no
	clc
	adc #HEALTH_STIM
	cmp #HEALTH_MAX
	bcc .pa_stim_ok
	lda #HEALTH_MAX
.pa_stim_ok
	sta health
	lda #ITEM_TYPE_HEALTHCRATE
	jmp pickup_message
.pa_stim_no
	jmp .pa_no

; Pos corpse — +4 shells +10 bullets (always take)
.pa_poscorpse
	ldy #1
	lda #4
	jsr add_ammo
	ldy #0
	lda #10
	jsr add_ammo
	lda #SOUND_ITEMUP
	jsr play_sound
	lda #0
	sta info_kind
	lda #1
	sta hud_dirty
	lda #<name_clips
	sta info_name_l
	lda #>name_clips
	sta info_name_h
	ldy #0
.pc_len
	lda (info_name_l),y
	beq .pc_got
	iny
	bne .pc_len
.pc_got
	tya
	clc
	adc #15				; prefix + '.'
	sta info_len
	lda #INFO_MS_L
	sta info_ms_l
	lda #INFO_MS_H
	sta info_ms_h
	sec
	rts

.pa_no
	clc
	rts

; ---------------------------------------------------------------------------
; pickup_message — A = typeId; set info line + 4s timer; C=1
; ---------------------------------------------------------------------------
pickup_message
	pha
	lda #SOUND_ITEMUP
	jsr play_sound
	pla
	ldx #0
	stx info_kind
	ldx #1
	stx hud_dirty
	sec
	sbc #ITEM_TYPE_HEALTH
	tay				; index = typeId - HEALTH (lo/hi tables)
	lda pickup_name_lo,y
	sta info_name_l
	lda pickup_name_hi,y
	sta info_name_h
	; len = "picked up the " (14) + namelen + "." (1)
	ldy #0
.pm_len
	lda (info_name_l),y
	beq .pm_got
	iny
	bne .pm_len
.pm_got
	tya
	clc
	adc #15				; prefix + '.'
	sta info_len
	lda #INFO_MS_L
	sta info_ms_l
	lda #INFO_MS_H
	sta info_ms_h
	sec
	rts

; ---------------------------------------------------------------------------
; door_need_msg — A = 0 red / 1 yellow / 2 blue; oof + top-line message
; ---------------------------------------------------------------------------
door_need_msg
	tay
	lda door_msg_lo,y
	sta info_name_l
	lda door_msg_hi,y
	sta info_name_h
	lda door_msg_len,y
	sta info_len
	lda #1
	sta info_kind
	lda #INFO_MS_L
	sta info_ms_l
	lda #INFO_MS_H
	sta info_ms_h
	lda #SOUND_OOF
	jmp play_sound

; ---------------------------------------------------------------------------
; update_info_msg — tick 4s timer; clear info_len when done
; ---------------------------------------------------------------------------
update_info_msg
	lda info_ms_l
	ora info_ms_h
	beq .ui_out
	sec
	lda info_ms_l
	sbc dt_ms
	sta info_ms_l
	lda info_ms_h
	sbc #0
	sta info_ms_h
	bcs .ui_out
	lda #0
	sta info_ms_l
	sta info_ms_h
	sta info_len
	sta info_kind
.ui_out
	rts

; ---------------------------------------------------------------------------
; draw_info_msg — into SCREENBUFFER/PATTERNBUFFER row 0 (pre-blit)
; Glyphs: letters → MSG_LETTER0+(n-1); space/digit/punct unchanged.
; ---------------------------------------------------------------------------
draw_info_msg
	lda info_len
	bne .di_go
	rts
.di_go
	lda #0
	sta col				; write left→right along top row
	lda info_kind
	bne .di_raw
	; "picked up the "
	ldx #0
.di_pref
	lda pickup_prefix,x
	jsr .di_putc
	inx
	cpx #14
	bcc .di_pref
	; name
	ldy #0
.di_name
	lda (info_name_l),y
	beq .di_dot
	sty tmp1
	jsr .di_putc
	ldy tmp1
	iny
	bne .di_name
.di_dot
	lda #46				; '.'
	jmp .di_putc
.di_raw
	ldy #0
.di_rawloop
	lda (info_name_l),y
	beq .di_done
	sty tmp1
	jsr .di_putc
	ldy tmp1
	iny
	bne .di_rawloop
.di_done
	rts
; A = raw screen code from !scr → PATTERNBUFFER row0 + SCREENBUFFER colour
.di_putc
	sta tmp0
	cmp #27
	bcs .di_rawch
	cmp #1
	bcc .di_rawch
	clc
	adc #MSG_LETTER0 - 1
	sta tmp0
.di_rawch
	ldx col
	lda colbaselo,x
	sta col_base_l
	sta pat_base_l
	lda colbasehi,x
	sta col_base_h
	clc
	adc #4				; PATTERNBUFFER = SCREENBUFFER+$400
	sta pat_base_h
	ldy #0				; row 0
	lda #INFO_COLOR
	sta (col_base_l),y
	lda tmp0
	sta (pat_base_l),y
	inc col
	rts

pickup_prefix
	!scr "picked up the "

; Name table indexed by (typeId - ITEM_TYPE_HEALTH)
pickup_name_lo
	!byte <name_health, <name_ammo, <name_shotgun, <name_chaingun
	!byte <name_chainsaw, <name_rocket, <name_garmor, <name_barmor
	!byte <name_backpack, <name_redcard, <name_bluecard, <name_yellowcard
	!byte <name_soulsphere, <name_radsuit
	!byte <name_hbonus, <name_abonus, <name_clip, <name_shellbox
	!byte <name_ammobox, <name_stim
pickup_name_hi
	!byte >name_health, >name_ammo, >name_shotgun, >name_chaingun
	!byte >name_chainsaw, >name_rocket, >name_garmor, >name_barmor
	!byte >name_backpack, >name_redcard, >name_bluecard, >name_yellowcard
	!byte >name_soulsphere, >name_radsuit
	!byte >name_hbonus, >name_abonus, >name_clip, >name_shellbox
	!byte >name_ammobox, >name_stim

name_health
	!scr "health"
	!byte 0
name_ammo
	!scr "shells"
	!byte 0
name_clips
	!scr "ammo"
	!byte 0
name_clip
	!scr "clip"
	!byte 0
name_shellbox
	!scr "shell box"
	!byte 0
name_ammobox
	!scr "ammo box"
	!byte 0
name_hbonus
	!scr "health bonus"
	!byte 0
name_abonus
	!scr "armor bonus"
	!byte 0
name_stim
	!scr "health crate"
	!byte 0
name_shotgun
	!scr "shotgun"
	!byte 0
name_chaingun
	!scr "chaingun"
	!byte 0
name_chainsaw
	!scr "chainsaw"
	!byte 0
name_rocket
	!scr "rocket launcher"
	!byte 0
name_garmor
	!scr "green armor"
	!byte 0
name_barmor
	!scr "blue armor"
	!byte 0
name_backpack
	!scr "backpack"
	!byte 0
name_redcard
	!scr "red keycard"
	!byte 0
name_bluecard
	!scr "blue keycard"
	!byte 0
name_yellowcard
	!scr "yellow keycard"
	!byte 0
name_soulsphere
	!scr "soulsphere"
	!byte 0
name_radsuit
	!scr "rad suit"
	!byte 0

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

MSG_LETTER0 = 192			; screen code for 'A' (glyph bank)
INFO_COLOR = 7				; yellow

; 0 = "picked up the "+name+"."; 1 = full string at info_name
info_kind		!byte 0

; Ammo reserves (BSS — fire/HUD/pickup only; not ZP)
ammo_bullets		!byte 0
ammo_shells		!byte 0
ammo_rockets		!byte 0

; bit0=chainsaw bit1=pistol bit2=shotgun bit3=minigun bit4=rocket
owned_weapons		!byte 0

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
ITEM_TYPE_POSCORPSE = 21
ITEM_TYPE_EMPTY = $ff

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
; try_pickups — after apply_move; one item per frame if within radius
; ---------------------------------------------------------------------------
try_pickups
	ldx #0
.tp_loop
	lda level_item_type,x
	bmi .tp_next
	cmp #ITEM_TYPE_HEALTH
	bcc .tp_next
	cmp #ITEM_TYPE_POSCORPSE + 1
	bcs .tp_next
.tp_cand
	sta tmp4			; typeId
	lda level_item_x,x
	sta tmp0			; item x
	lda level_item_y,x
	sta tmp1			; item y

	; |ix - playerx_h|
	lda tmp0
	sec
	sbc playerx_h
	bcs .tp_dx
	eor #$ff
	adc #1
.tp_dx
	cmp #PICKUP_RADIUS
	bcs .tp_next
	; |iy - playery_h|
	lda tmp1
	sec
	sbc playery_h
	bcs .tp_dy
	eor #$ff
	adc #1
.tp_dy
	cmp #PICKUP_RADIUS
	bcs .tp_next

	stx tmp5			; slot
	lda tmp4
	jsr pickup_apply
	bcc .tp_done			; not taken
	; countable pickup (not poscorpse) → stats
	lda tmp4
	cmp #ITEM_TYPE_RADSUIT + 1
	bcs .tp_consume
	inc num_items_got
.tp_consume
	; consume item
	ldx tmp5
	lda #ITEM_TYPE_EMPTY
	sta level_item_type,x
.tp_done
	rts
.tp_next
	inx
	cpx #MAX_ITEMS
	bcc .tp_loop
	rts

; ---------------------------------------------------------------------------
; pickup_apply — A = typeId; C=1 if taken (message set), C=0 if refused
; ---------------------------------------------------------------------------
pickup_apply
	sec
	sbc #ITEM_TYPE_HEALTH
	cmp #ITEM_TYPE_POSCORPSE - ITEM_TYPE_HEALTH + 1
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
	!byte <.pa_soulsphere, <.pa_radsuit, <.pa_poscorpse
.pa_jmp_hi
	!byte >.pa_health, >.pa_shells, >.pa_weapon, >.pa_weapon
	!byte >.pa_weapon, >.pa_weapon, >.pa_garmor, >.pa_barmor
	!byte >.pa_pack, >.pa_red, >.pa_blue, >.pa_yellow
	!byte >.pa_soulsphere, >.pa_radsuit, >.pa_poscorpse

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
; draw_info_msg — into FRAMEBUFFER/LIGHTFRAME row 0 (pre-blit)
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
; A = raw screen code from !scr → LIGHTFRAME row0 + FRAMEBUFFER colour
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
	adc #4				; LIGHTFRAME = FRAMEBUFFER+$400
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
	!byte <name_soulsphere, <name_radsuit, <name_clips
pickup_name_hi
	!byte >name_health, >name_ammo, >name_shotgun, >name_chaingun
	!byte >name_chainsaw, >name_rocket, >name_garmor, >name_barmor
	!byte >name_backpack, >name_redcard, >name_bluecard, >name_yellowcard
	!byte >name_soulsphere, >name_radsuit, >name_clips

name_health
	!scr "health"
	!byte 0
name_ammo
	!scr "shells"
	!byte 0
name_clips
	!scr "ammo"
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

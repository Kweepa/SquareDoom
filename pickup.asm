; Walk-over pickups + top-line "picked up …." message
!zone pickup

PICKUP_RADIUS = 4
INFO_MS_L = <4000
INFO_MS_H = >4000
AMMO_ADD = 10
AMMO_MAX = 200
AMMO_MAX_PACK = 255
HEALTH_ADD = 25
HEALTH_MAX = 100
ARMOR_GREEN = 100
ARMOR_BLUE = 200

MSG_LETTER0 = 192			; screen code for 'A' (glyph bank)
INFO_COLOR = 7				; yellow

ITEM_TYPE_HEALTH = 7
ITEM_TYPE_SHELLS = 8
ITEM_TYPE_SHOTGUN = 9
ITEM_TYPE_CHAINGUN = 10
ITEM_TYPE_CHAINSAW = 11
ITEM_TYPE_GREENARMOR = 12
ITEM_TYPE_BLUEARMOR = 13
ITEM_TYPE_BACKPACK = 14
ITEM_TYPE_REDCARD = 15
ITEM_TYPE_BLUECARD = 16
ITEM_TYPE_YELLOWCARD = 17

; ---------------------------------------------------------------------------
; try_pickups — after apply_move; one item per frame if within radius
; ---------------------------------------------------------------------------
try_pickups
	ldx #0
.tp_loop
	txa
	asl
	asl
	tay
	lda level_items,y
	cmp #ITEM_TYPE_HEALTH
	bcc .tp_next
	cmp #ITEM_TYPE_YELLOWCARD + 1
	bcs .tp_next
	sta tmp4			; typeId
	iny
	lda level_items,y
	sta tmp0			; item x
	iny
	lda level_items,y
	sta tmp1			; item y

	; |ix - playerx_h|
	lda tmp0
	sec
	sbc playerx_h
	bcs .tp_dx
	eor #$ff
	clc
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
	clc
	adc #1
.tp_dy
	cmp #PICKUP_RADIUS
	bcs .tp_next

	stx tmp5			; slot
	lda tmp4
	jsr pickup_apply
	bcc .tp_done			; not taken
	; consume item
	lda tmp5
	asl
	asl
	tay
	lda #ITEM_TYPE_EMPTY
	sta level_items,y
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
	cmp #ITEM_TYPE_YELLOWCARD - ITEM_TYPE_HEALTH + 1
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
	!byte <.pa_weapon, <.pa_garmor, <.pa_barmor, <.pa_pack
	!byte <.pa_red, <.pa_blue, <.pa_yellow
.pa_jmp_hi
	!byte >.pa_health, >.pa_shells, >.pa_weapon, >.pa_weapon
	!byte >.pa_weapon, >.pa_garmor, >.pa_barmor, >.pa_pack
	!byte >.pa_red, >.pa_blue, >.pa_yellow

.pa_health
	lda health
	cmp #HEALTH_MAX
	bcs .pa_no
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
	lda has_backpack
	bne .pa_smax
	lda #AMMO_MAX
	bne .pa_scap
.pa_smax
	lda #AMMO_MAX_PACK
.pa_scap
	sta tmp0
	lda ammo
	cmp tmp0
	bcs .pa_no
	clc
	adc #AMMO_ADD
	cmp tmp0
	bcc .pa_sok
	lda tmp0
.pa_sok
	sta ammo
	lda #ITEM_TYPE_SHELLS
	jmp pickup_message

.pa_garmor
	lda armor
	cmp #ARMOR_GREEN
	bcs .pa_no
	lda #ARMOR_GREEN
	sta armor
	lda #ITEM_TYPE_GREENARMOR
	jmp pickup_message

.pa_barmor
	lda armor
	cmp #ARMOR_BLUE
	bcs .pa_no
	lda #ARMOR_BLUE
	sta armor
	lda #ITEM_TYPE_BLUEARMOR
	jmp pickup_message

.pa_pack
	lda #1
	sta has_backpack
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

.pa_weapon
	; A still holds typeId from caller… but jmp table clobbered it.
	; Recover from tmp4 (set by try_pickups).
	lda tmp4
	jmp pickup_message

.pa_no
	clc
	rts

; ---------------------------------------------------------------------------
; pickup_message — A = typeId; set info line + 4s timer; C=1
; ---------------------------------------------------------------------------
pickup_message
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
	; fall through
; A = raw screen code from !scr → LIGHTFRAME row0 + FRAMEBUFFER colour
.di_putc
	sta tmp0
	cmp #27
	bcs .di_raw
	cmp #1
	bcc .di_raw
	clc
	adc #MSG_LETTER0 - 1
	sta tmp0
.di_raw
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
	!byte <name_chainsaw, <name_garmor, <name_barmor, <name_backpack
	!byte <name_redcard, <name_bluecard, <name_yellowcard
pickup_name_hi
	!byte >name_health, >name_ammo, >name_shotgun, >name_chaingun
	!byte >name_chainsaw, >name_garmor, >name_barmor, >name_backpack
	!byte >name_redcard, >name_bluecard, >name_yellowcard

name_health
	!scr "health"
	!byte 0
name_ammo
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

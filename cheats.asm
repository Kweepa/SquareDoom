; Cheat codes — probe only the next expected CIA1 matrix cell (col, row).
; Called from input_irq (Timer A); no tmp*, no SEI/CLI.
; Shared ID prefix, then three suffix FSMs: iddqd / idkfa / idclevNN.
!zone cheats

CHEAT_IDLE = 0
CHEAT_GOT_I = 1
CHEAT_AFTER_ID = 2

god_mode		!byte 0
clev			!byte 0
cheat_phase		!byte 0
cheat_dqd		!byte 0		; byte index into seq
cheat_kfa		!byte 0
cheat_clev		!byte 0		; 0..3 letters, 4=ep digit, 5=map digit
cheat_ep_dig		!byte 0		; 1..9
cheat_map_dig		!byte 0
cheat_was		!byte 0, 0, 0, 0	; prev down slots 0..3
cheat_dig_prev		!byte 0		; last held digit 0=none, 1..9
cheat_a			!byte 0		; IRQ scratch
cheat_b			!byte 0
cheat_c			!byte 0

; col, row (active-low). 0,0 = end.
cheat_seq_dqd
	!byte $fb, $04, $7f, $40, $fb, $04, 0, 0		; D Q D
cheat_seq_kfa
	!byte $ef, $20, $fb, $20, $fd, $04, 0, 0		; K F A
cheat_seq_clev
	!byte $fb, $10, $df, $04, $fd, $40, $f7, $80, 0, 0	; C L E V
cheat_seq_dig
	!byte $7f, $01, $7f, $08, $fd, $01, $fd, $08, $fb, $01
	!byte $fb, $08, $f7, $01, $f7, $08, $ef, $01	; 1..9

cheat_msg_dqd
	!scr "degreelessness mode"
	!byte 0
cheat_msg_kfa
	!scr "keys, full ammo"
	!byte 0
cheat_msg_clev
	!scr "change level"
	!byte 0

; ---------------------------------------------------------------------------
check_cheats
	lda cheat_phase
	beq .idle
	cmp #CHEAT_GOT_I
	beq .got_i
	jmp .after_id

.idle
	lda #$ef
	ldy #$02
	ldx #0
	jsr cheat_rise
	bcc .rts
	lda #CHEAT_GOT_I
	sta cheat_phase
	lda #0
	sta cheat_was
.rts
	rts

.got_i
	lda #$fb
	ldy #$04
	ldx #0
	jsr cheat_rise
	bcc .rts
	jsr cheat_clear_suf
	lda #CHEAT_AFTER_ID
	sta cheat_phase
	rts

.after_id
	lda #$ef
	ldy #$02
	ldx #3
	jsr cheat_rise
	bcc .suf
	jsr cheat_clear_suf
	lda #CHEAT_GOT_I
	sta cheat_phase
	rts

.suf
	ldx cheat_dqd
	lda cheat_seq_dqd,x
	beq .kfa
	ldy cheat_seq_dqd + 1,x
	ldx #0
	jsr cheat_rise
	bcc .kfa
	ldx cheat_dqd
	inx
	inx
	stx cheat_dqd
	lda cheat_seq_dqd,x
	bne .kfa
	jmp cheat_do_dqd

.kfa
	ldx cheat_kfa
	lda cheat_seq_kfa,x
	beq .clev
	ldy cheat_seq_kfa + 1,x
	ldx #1
	jsr cheat_rise
	bcc .clev
	ldx cheat_kfa
	inx
	inx
	stx cheat_kfa
	lda cheat_seq_kfa,x
	bne .clev
	jmp cheat_do_kfa

.clev
	lda cheat_clev
	cmp #4
	bcs .clev_dig
	asl
	tax
	lda cheat_seq_clev,x
	beq .rts2
	ldy cheat_seq_clev + 1,x
	ldx #2
	jsr cheat_rise
	bcc .rts2
	inc cheat_clev
	lda cheat_clev
	cmp #4
	bne .rts2
	jsr cheat_dig_held		; seed so held keys aren't a rising edge
	sta cheat_dig_prev
.rts2
	rts

.clev_dig
	jsr cheat_dig_rise
	beq .rts2
	ldx cheat_clev
	cpx #4
	bne .clev_map
	sta cheat_ep_dig
	inc cheat_clev
	rts
.clev_map
	sta cheat_map_dig
	jmp cheat_do_clev

; ---------------------------------------------------------------------------
; cheat_rise — A=col Y=row X=slot; C=1 on rising edge
; ---------------------------------------------------------------------------
cheat_rise
	sta cheat_a
	sty cheat_b
	stx cheat_c
	sta $dc00
	lda $dc01
	and cheat_b
	beq .down
	lda #0
	beq .edge
.down
	lda #1
.edge
	ldx cheat_c
	cmp cheat_was,x
	sta cheat_was,x
	beq .no
	cmp #1
	bne .no
	sec
	rts
.no
	clc
	rts

; ---------------------------------------------------------------------------
; cheat_dig_held — A = first held digit 1..9, or 0
; cheat_dig_rise — A = digit on rising edge, else 0
; ---------------------------------------------------------------------------
cheat_dig_held
	ldx #0
.dh_loop
	txa
	asl
	tay
	lda cheat_seq_dig,y
	sta $dc00
	lda $dc01
	and cheat_seq_dig + 1,y
	beq .dh_hit
	inx
	cpx #9
	bcc .dh_loop
	lda #0
	rts
.dh_hit
	txa
	clc
	adc #1
	rts

cheat_dig_rise
	jsr cheat_dig_held
	cmp cheat_dig_prev
	sta cheat_dig_prev
	beq .dr_no
	cmp #0
	beq .dr_no
	rts				; A = 1..9
.dr_no
	lda #0
	rts

cheat_clear_suf
	lda #0
	sta cheat_dqd
	sta cheat_kfa
	sta cheat_clev
	sta cheat_was
	sta cheat_was + 1
	sta cheat_was + 2
	sta cheat_was + 3
	sta cheat_dig_prev
	rts

cheat_reset_all
	jsr cheat_clear_suf
	lda #0
	sta cheat_phase
	rts

; ---------------------------------------------------------------------------
cheat_do_dqd
	jsr cheat_reset_all
	lda god_mode
	eor #1
	sta god_mode
	lda #100
	sta health
	lda #1
	sta hud_dirty
	lda #<cheat_msg_dqd
	ldy #>cheat_msg_dqd
	jmp cheat_show_msg

cheat_do_kfa
	jsr cheat_reset_all
	lda #$07
	sta keys
	lda #$1f
	sta owned_weapons
	lda #200
	sta armor
	lda #1
	sta combat_armor
	ldx #0
.ck_ammo
	lda has_backpack
	bne .ck_pack
	lda ammo_max_base,x
	bne .ck_set
.ck_pack
	lda ammo_max_pack,x
.ck_set
	sta ammo_bullets,x
	inx
	cpx #3
	bcc .ck_ammo
	lda #1
	sta hud_dirty
	lda #<cheat_msg_kfa
	ldy #>cheat_msg_kfa
	jmp cheat_show_msg

cheat_do_clev
	jsr cheat_reset_all
	lda cheat_ep_dig
	sec
	sbc #1
	sta episode
	lda cheat_map_dig
	sta level_num
	lda #1
	sta clev
	sta end_level
	lda #<cheat_msg_clev
	ldy #>cheat_msg_clev

cheat_show_msg
	sta info_name_l
	sty info_name_h
	lda #1
	sta info_kind
	ldy #0
.csm_len
	lda (info_name_l),y
	beq .csm_got
	iny
	bne .csm_len
.csm_got
	sty info_len
	lda #INFO_MS_L
	sta info_ms_l
	lda #INFO_MS_H
	sta info_ms_h
	ldx #SOUND_ITEMUP
	lda sound_priorities,x
	cmp sound_priority
	bcc .csm_rts
	sta sound_priority
	txa
	asl
	tay
	lda sound_table,y
	sta sound_ptr_l
	lda sound_table + 1,y
	sta sound_ptr_h
	ldy #0
	lda (sound_ptr_l),y
	tay
	iny
	sty sound_max
	lda #0
	sta sound_count
	stx sound_index
	lda effects_vol
	sta $d418
.csm_rts
	rts

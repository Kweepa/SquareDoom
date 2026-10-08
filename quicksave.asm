; F5 quick save / F7 quick load. Two files on the game disk:
;   QS — live state at $C4ED (header, 13-byte ZP hole, scalars, procs,
;        mobj, FX, automap fog). Saved in place.
;   QL — live level window at $96E0 (LEVEL_BYTES), saved in place.
; Save is KERNAL $FFD8 only (USE_KRILL=0). Krill's resident loader cannot
; write files without a much larger block, so the Krill disk has F7 load
; (loadraw) and no F5. SAVE runs at $01=$36 so the level tail under BASIC
; ($A000–$A470) is RAM. No IOINIT. A missing QS leaves the game running
; (red border). A present file that fails verification has already
; overwritten live mobs, so the current level is reloaded.
!zone quicksave

; Snapshot latches. F5 wins when both are set. Krill: F7 only.
poll_quick_keys
	sei
!if USE_KRILL = 0 {
	lda in_qsave
	sta tmp0
}
	lda in_qload
	sta tmp1
	lda #0
!if USE_KRILL = 0 {
	sta in_qsave
}
	sta in_qload
	cli
!if USE_KRILL = 0 {
	lda tmp0
	beq .pqk_load
	jmp quick_save
.pqk_load
}
	lda tmp1
	beq .pqk_none
	jmp quick_load
.pqk_none
	rts

!if USE_KRILL = 0 {
; ---------------------------------------------------------------------------
quick_save
	jsr qs_disk_prep
	lda #BANK_RAM
	sta $01
	jsr qs_pack
	jsr qs_kernal_begin
	ldx #<qs_scratch_qs
	ldy #>qs_scratch_qs
	jsr qs_scratch
	bcs .qs_bad
	ldx #<qs_scratch_ql
	ldy #>qs_scratch_ql
	jsr qs_scratch
	bcs .qs_bad
	jsr qs_save_qs
	bcs .qs_bad
	jsr qs_save_ql
	bcs .qs_bad
	sei
	lda #BANK_RAM			; SAVE may have used KERNAL ZP
	sta $01
	lda #1
	jsr qs_zp_xfer
	lda #$ff				; KERNAL clobbers sky_col_base
	sta last_playera
	jsr qs_recover_hw
	lda #0
	sta $d020
	lda #BANK_RAM
	sta $01
	cli
	clc
	rts
.qs_bad
	jmp qs_fail
}

; ---------------------------------------------------------------------------
quick_load
	jsr qs_disk_prep
	ldx #<qs_dos_name
	ldy #>qs_dos_name
	jsr qs_load_file
	bcs qs_fail
	lda #BANK_RAM
	sta $01
	sei
	jsr qs_verify_hdr
	bcs .qsl_reload			; file landed on live state
	ldx #<ql_dos_name
	ldy #>ql_dos_name
	jsr qs_load_file
	bcs .qsl_reload
	lda #BANK_RAM
	sta $01
	sei
	jsr qs_verify
	bcs .qsl_reload
	lda #1
	jsr qs_zp_xfer			; hole → player / episode bytes
	jsr qs_after_load
	jsr qs_recover_hw
	lda #0
	sta $d020
	lda #BANK_RAM
	sta $01
	cli
	clc
	rts
.qsl_reload
	jsr LoadLevel			; live state and/or the map already overwritten
	bcs qs_fail
	jsr start_level
	jmp qs_fail

; Red border. hurt_flash keeps it through player_frame on the live path.
qs_fail
	jsr qs_recover_hw
	lda #2
	sta $d020
	lda #32					; keep the fail border up long enough to see
	sta hurt_flash
	lda #$ff				; KERNAL clobbers sky_col_base
	sta last_playera
	lda #BANK_RAM
	sta $01
	cli
	sec
	rts

; Kill game IRQs and blank. Leave CIA2 timers running (DEN off + timers
; stopped stalls KERNAL IEC). Do not IOINIT.
qs_disk_prep
	sei
	cld
	lda #BANK_LOADER
	sta $01
	lda #$7f
	sta $dc0d
	lda $dc0d
	lda #0
	sta $d01a
	lda #$ff
	sta $d019				; ack; do not reuse this read as a colour
	lda #0
	sta $d015
	sta $d020
	sta $d021
	jmp set_vic_bank3

; $01=$35, SEI. DEN on, keyboard DDR, profiler, input IRQ.
qs_recover_hw
	sei
	lda #BANK_LOADER
	sta $01
	lda #$ff
	sta $dc02
	lda #0
	sta $dc03
	jsr set_vic_bank3
	lda #$1b				; DEN on, 25 rows, YSCROLL=3. Do not RMW:
	sta $d011				; a read at raster≥256 latches RST8
	lda #0					; play background/border (KERNAL I/O leaves $d021)
	sta $d020
	sta $d021
	lda spr_en				; prep hid the gun; fail returns before render
	sta $d015
	jsr prof_init
	jmp input_irq_init

!if USE_KRILL = 0 {
; $01=$36, messages off, CLI. KERNAL IEC with our CIA1 IRQ still disabled.
; $98 is only the KERNAL open-file count (seen_gen lives at $80).
; VIC bank 3 ($DD00=$00) also holds ATN; level loads switch to bank 0 first.
qs_kernal_begin
	lda #BANK_IO
	sta $01
	lda #0
	sta $98					; open-file count
	sta $90					; ST
	jsr $ffe7				; CLALL (count is 0). Leave $BA (load device).
	lda #$3f
	sta $dd02
	lda #$07				; VIC bank 0, IOINIT port
	sta $dd00
	lda #$08				; timers stopped; $00 plus DEN off stalls IEC
	sta $dc0e
	sta $dd0e
	sta $dc0f
	sta $dd0f
	lda #0
	jsr $ff90				; $9D=0 (aliases ui_str_l)
	lda #1
	sta $cc					; cursor off
	cli
	rts

; X/Y = "S0:.." (5 chars). $01=$36.
; Read the status line. A 1541 does not finish the scratch until the error
; channel is read; SAVE then hits "file exists" and the previous QS/QL stay.
; C=0 for 00 (ok), 01 (files scratched), or 62 (no such file).
qs_scratch
	lda #5
	jsr $ffbd
	lda #15
	ldx $ba
	ldy #15
	jsr $ffba
	jsr $ffc0
	bcs .qsc_err
	ldx #15
	jsr $ffc6				; CHKIN
	bcs .qsc_err_close
	jsr $ffcf
	sta tmp2
	jsr $ffcf
	sta tmp3
.qsc_drain
	jsr $ffcf
	cmp #$0d
	beq .qsc_shut
	lda $90					; ST: EOI
	beq .qsc_drain
.qsc_shut
	jsr $ffcc				; CLRCH
	lda #15
	jsr $ffc3
	lda tmp2
	cmp #'0'				; 00 ok, 01 scratched
	beq .qsc_ok
	cmp #'6'
	bne .qsc_err
	lda tmp3
	cmp #'2'				; 62 file not found
	bne .qsc_err
.qsc_ok
	clc
	rts
.qsc_err_close
	jsr $ffcc
	lda #15
	jsr $ffc3
.qsc_err
	sec
	rts

qs_save_qs
	lda #2
	ldx #<qs_dos_name
	ldy #>qs_dos_name
	jsr $ffbd
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba
	lda #<QS_PACK
	sta tmp0
	lda #>QS_PACK
	sta tmp1
	ldx #<QS_END
	ldy #>QS_END
	lda #tmp0
	jmp $ffd8

qs_save_ql
	lda #2
	ldx #<ql_dos_name
	ldy #>ql_dos_name
	jsr $ffbd
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba
	lda #<level_data
	sta tmp0
	lda #>level_data
	sta tmp1
	ldx #<(level_data + LEVEL_BYTES)
	ldy #>(level_data + LEVEL_BYTES)
	lda #tmp0
	jmp $ffd8
}

; X/Y = 0-terminated name. C=0 ok. Krill: loadraw. KERNAL: $FFD5, no IOINIT.
qs_load_file
!if USE_KRILL {
	lda #0
	sta load_do_pad
	jmp LoadPrg
} else {
	stx load_name_l
	sty load_name_h
	jsr qs_kernal_begin
	lda #2
	ldx load_name_l
	ldy load_name_h
	jsr $ffbd
	lda #1
	ldx $ba
	ldy #1
	jsr $ffba
	lda #0
	jsr $ffd5
	php
	pha
	lda #1
	jsr $ffc3
	pla
	plp
	sei
	rts
}

; ---------------------------------------------------------------------------
; Fill the header. Live arrays are already the save image. $01=$34.
!if USE_KRILL = 0 {
qs_pack
	lda #0
	jsr qs_zp_xfer
	lda #'S'
	sta QS_MAGIC
	lda #'D'
	sta QS_MAGIC + 1
	lda #'Q'
	sta QS_MAGIC + 2
	lda #'S'
	sta QS_MAGIC + 3
	lda #QS_VERSION
	sta QS_VER
	jsr qs_checksum
	lda tmp0
	sta QS_CSUM
	lda tmp1
	sta QS_CSUM + 1
	rts
}

; Magic + version. C=0 ok.
qs_verify_hdr
	lda QS_MAGIC
	cmp #'S'
	bne .qsvh_bad
	lda QS_MAGIC + 1
	cmp #'D'
	bne .qsvh_bad
	lda QS_MAGIC + 2
	cmp #'Q'
	bne .qsvh_bad
	lda QS_MAGIC + 3
	cmp #'S'
	bne .qsvh_bad
	lda QS_VER
	cmp #QS_VERSION
	bne .qsvh_bad
	clc
	rts
.qsvh_bad
	sec
	rts

; Header + checksum of QS body and the level window. C=0 ok. $01=$34.
qs_verify
	jsr qs_verify_hdr
	bcs .qsv_bad
	jsr qs_checksum
	lda tmp0
	cmp QS_CSUM
	bne .qsv_bad
	lda tmp1
	cmp QS_CSUM + 1
	bne .qsv_bad
	clc
	rts
.qsv_bad
	sec
	rts

; Sum QS body + level_data into tmp0/tmp1.
qs_checksum
	lda #0
	sta tmp0
	sta tmp1
	lda #<QS_BODY
	sta aux_l
	lda #>QS_BODY
	sta aux_h
	lda #<(QS_END - QS_BODY)
	sta tmp2
	lda #>(QS_END - QS_BODY)
	sta tmp3
	jsr qs_sum
	lda #<level_data
	sta aux_l
	lda #>level_data
	sta aux_h
	lda #<LEVEL_BYTES
	sta tmp2
	lda #>LEVEL_BYTES
	sta tmp3
	jmp qs_sum

qs_sum
.qss_lp
	lda tmp2
	ora tmp3
	beq .qss_done
	ldy #0
	lda (aux_l),y
	clc
	adc tmp0
	sta tmp0
	bcc .qss_nc
	inc tmp1
.qss_nc
	inc aux_l
	bne .qss_ah
	inc aux_h
.qss_ah
	lda tmp2
	bne .qss_nl
	dec tmp3
.qss_nl
	dec tmp2
	jmp .qss_lp
.qss_done
	rts

; A=0 copy the 13 fixed bytes into the hole. A=1 copy them back.
; Player xy/angle, health/armor/keys, backpack, weapon, episode/level/difficulty.
qs_zp_xfer
	sta tmp4
	ldx #0
.qz
	lda qs_zp_lo,x
	sta tmp2
	lda qs_zp_hi,x
	sta tmp3
	ldy #0
	lda tmp4
	bne .qz_load
	lda (tmp2),y
	sta QS_ZP,x
	jmp .qz_next
.qz_load
	lda QS_ZP,x
	sta (tmp2),y
.qz_next
	inx
	cpx #QS_ZP_N
	bne .qz
	rts

; After a good load. Missiles in the air are dropped (velocities are not saved).
; Do not call start_level — that would respawn from the item layer.
qs_after_load
	lda radsuit_ms
	pha
	lda radsuit_ms + 1
	pha
	jsr flash_lights_init		; re-scan ACT_FLASH_LIGHTS; also clears the suit
	pla
	sta radsuit_ms + 1
	pla
	sta radsuit_ms
	ldx #5				; switch_weapon zeros the live pose
.qsal_push
	lda wpn_pose,x
	pha
	dex
	bpl .qsal_push
	ldx cur_weapon
	lda #$ff
	sta cur_weapon
	jsr switch_weapon		; SMC + sprites
	ldx #0
.qsal_pop
	pla
	sta wpn_pose,x
	inx
	cpx #6
	bne .qsal_pop
	lda #0
	sta MOBJ_ALLOC + MOBJ_PLAYER_ROCKET
	sta MOBJ_ALLOC + MOBJ_MISSILE
	sta wpn_shot_req
	jsr build_sec_flatgrp
	jsr build_sec_wdark
	lda #$ff
	sta last_playera
	sta seen_gen
	jsr update_eye
	lda #1
	sta hud_dirty
	rts

qs_dos_name
	!text "QS"
	!byte 0
ql_dos_name
	!text "QL"
	!byte 0
!if USE_KRILL = 0 {
qs_scratch_qs
	!text "S0:QS"
qs_scratch_ql
	!text "S0:QL"
}

qs_zp_lo
	!byte <playerx, <playerx_h, <playery, <playery_h, <playera
	!byte <health, <armor, <keys, <has_backpack, <cur_weapon
	!byte <episode, <level_num, <difficulty
qs_zp_hi
	!byte >playerx, >playerx_h, >playery, >playery_h, >playera
	!byte >health, >armor, >keys, >has_backpack, >cur_weapon
	!byte >episode, >level_num, >difficulty
!if qs_zp_hi - qs_zp_lo != QS_ZP_N {
	!error "QS zp table length"
}

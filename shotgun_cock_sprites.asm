; Auto-generated from itemgraphics/multicolour/shotgun_cock.png - do not edit
; Six body layers (low VIC # = front): black hi, black lo, dark grey, highlight, brown, orange.
; Placed at SHOTGUN_COCK_SPRITES ($3b80) in VIC bank 0; setup_shotgun_cock redirects $07f8.
; 24x42: blacks 0-20@166 / 21-41@208; grey top; highlight bot;; hand brown rows 10-30 @ Y=186; orange rows 9-29 @ Y=184.
!zone shotgun_cock_sprites

cock_black_hi
	!byte $0e,$00,$00,$1f,$00,$00,$3e,$00
	!byte $00,$1f,$00,$00,$1f,$c0,$00,$1e
	!byte $e0,$00,$1e,$d0,$00,$1e,$e0,$00
	!byte $1e,$e0,$00,$1e,$c0,$00,$1e,$d0
	!byte $00,$1e,$fc,$80,$1e,$e0,$40,$3f
	!byte $fc,$00,$3f,$e0,$c0,$3f,$fc,$20
	!byte $3f,$f1,$00,$3f,$f0,$20,$3f,$be
	!byte $03,$3f,$bf,$e0,$3f,$9f,$e1,$00
cock_black_lo
	!byte $3e,$87,$ff,$3e,$83,$ff,$3e,$81
	!byte $fd,$3e,$f0,$fd,$3e,$f8,$ef,$3e
	!byte $fe,$79,$7e,$ff,$70,$7e,$bf,$c4
	!byte $7e,$ff,$82,$7f,$af,$86,$7f,$7f
	!byte $fc,$7f,$ff,$fc,$6f,$ff,$f0,$6f
	!byte $ff,$e0,$6f,$ff,$f0,$ef,$ff,$f8
	!byte $ff,$ff,$f8,$ef,$ff,$fc,$cf,$ff
	!byte $fc,$ef,$ff,$fc,$ef,$ff,$fc,$00
cock_grey
	!byte $00,$00,$00,$00,$00,$00,$01,$00
	!byte $00,$00,$c0,$00,$00,$20,$00,$01
	!byte $10,$00,$01,$20,$00,$01,$00,$00
	!byte $01,$00,$00,$01,$00,$00,$01,$00
	!byte $00,$01,$00,$00,$21,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
cock_highlight
	!byte $01,$00,$00,$01,$00,$00,$01,$00
	!byte $00,$01,$00,$00,$01,$00,$00,$01
	!byte $00,$00,$01,$00,$00,$01,$00,$00
	!byte $01,$00,$00,$00,$00,$00,$00,$80
	!byte $00,$00,$00,$00,$10,$00,$00,$10
	!byte $00,$00,$10,$00,$00,$10,$00,$00
	!byte $00,$00,$00,$10,$00,$00,$30,$00
	!byte $00,$10,$00,$00,$10,$00,$00,$00
cock_brown
	!byte $00,$0e,$00,$00,$03,$00,$00,$00
	!byte $80,$00,$03,$00,$00,$19,$20,$00
	!byte $02,$50,$00,$08,$c0,$00,$0e,$5c
	!byte $00,$41,$c4,$00,$40,$1d,$00,$60
	!byte $1e,$00,$48,$00,$00,$44,$00,$00
	!byte $66,$02,$00,$07,$02,$00,$07,$10
	!byte $00,$01,$86,$00,$00,$8f,$00,$40
	!byte $3a,$00,$00,$7c,$00,$50,$78,$00
cock_orange
	!byte $00,$20,$00,$00,$21,$00,$00,$00
	!byte $00,$00,$1f,$00,$00,$00,$c0,$00
	!byte $06,$10,$00,$01,$88,$00,$06,$3c
	!byte $00,$01,$82,$00,$00,$38,$00,$00
	!byte $02,$00,$00,$00,$00,$30,$00,$00
	!byte $38,$00,$00,$18,$00,$00,$08,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00

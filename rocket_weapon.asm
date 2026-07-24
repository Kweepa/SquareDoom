; Auto-generated from itemgraphics/multicolour/rocketlauncher.png - do not edit
; Eight contiguous layers (low VIC # = front): hi×2, dark 2×2, pink flash×2.
;   PNG: grey(173) hi over opaque black dark; pink flash behind body.
;   Flash side-by-side @y=0 (+9 above body).
!zone rocket

rocket_hi_top
	!byte $00,$ff,$00,$00,$81,$00,$01,$ff
	!byte $80,$0f,$e7,$f0,$3f,$e7,$fc,$7f
	!byte $c3,$fe,$7f,$ff,$fe,$30,$ff,$0c
	!byte $27,$ff,$e4,$1f,$ff,$f8,$18,$3c
	!byte $18,$01,$ff,$80,$07,$ff,$e0,$0c
	!byte $ff,$30,$4f,$ff,$f2,$0c,$7e,$30
	!byte $27,$ff,$e4,$87,$ff,$e1,$0c,$ff
	!byte $30,$2f,$ff,$e4,$1f,$ff,$f8,$00
rocket_hi_bot
	!byte $4f,$ff,$f2,$0c,$7e,$30,$27,$ff
	!byte $e4,$87,$ff,$e1,$0c,$ff,$30,$2f
	!byte $ff,$e4,$1f,$ff,$f8,$0f,$ff,$f0
	!byte $0f,$00,$f0,$0e,$00,$70,$0f,$ff
	!byte $f0,$0f,$ff,$f0,$0f,$ff,$f0,$1f
	!byte $ff,$f8,$1f,$ff,$f8,$1f,$ff,$f8
	!byte $1f,$ff,$f8,$1f,$ff,$f8,$1f,$ff
	!byte $f8,$3f,$00,$fc,$3c,$00,$3c,$00
rocket_dark_tl
	!byte $00,$00,$10,$00,$00,$70,$00,$00
	!byte $e0,$00,$03,$00,$00,$04,$00,$00
	!byte $08,$02,$00,$18,$00,$00,$3c,$f0
	!byte $00,$7d,$80,$00,$7e,$00,$00,$fe
	!byte $7c,$00,$ff,$e0,$00,$ff,$80,$07
	!byte $ff,$30,$07,$fb,$00,$07,$ff,$38
	!byte $07,$fd,$80,$07,$f7,$80,$07,$ff
	!byte $30,$07,$fd,$00,$07,$fe,$00,$00
rocket_dark_tr
	!byte $08,$00,$00,$0e,$00,$00,$07,$00
	!byte $00,$00,$c0,$00,$00,$20,$00,$40
	!byte $10,$00,$00,$18,$00,$0f,$3c,$00
	!byte $01,$be,$00,$00,$7e,$00,$3e,$7f
	!byte $00,$07,$ff,$00,$01,$ff,$00,$0c
	!byte $ff,$e0,$00,$df,$e0,$1c,$ff,$e0
	!byte $01,$bf,$e0,$01,$ef,$e0,$0c,$ff
	!byte $e0,$01,$bf,$e0,$00,$7f,$e0,$00
rocket_dark_bl
	!byte $07,$fb,$00,$07,$ff,$38,$07,$fd
	!byte $80,$07,$f7,$80,$07,$ff,$30,$07
	!byte $fd,$00,$07,$fe,$00,$07,$ff,$00
	!byte $03,$ff,$0f,$03,$ff,$1f,$01,$ff
	!byte $00,$3f,$ff,$00,$3f,$ff,$00,$7f
	!byte $fe,$00,$7f,$fe,$00,$7f,$fe,$00
	!byte $ff,$fe,$00,$ff,$fe,$00,$ff,$fe
	!byte $00,$ff,$fc,$0f,$3f,$fc,$3f,$00
rocket_dark_br
	!byte $00,$df,$e0,$1c,$ff,$e0,$01,$bf
	!byte $e0,$01,$ef,$e0,$0c,$ff,$e0,$01
	!byte $bf,$e0,$00,$7f,$e0,$00,$ff,$e0
	!byte $f0,$ff,$c0,$f8,$ff,$c0,$00,$ff
	!byte $80,$00,$ff,$fc,$00,$ff,$fc,$00
	!byte $7f,$fe,$00,$7f,$fe,$00,$7f,$fe
	!byte $00,$7f,$ff,$00,$7f,$ff,$00,$7f
	!byte $ff,$f0,$3f,$ff,$fc,$3f,$fc,$00
rocket_flash_left
	!byte $00,$00,$03,$00,$00,$07,$00,$00
	!byte $1f,$00,$00,$3f,$00,$01,$ff,$00
	!byte $03,$ff,$00,$07,$ff,$00,$1f,$ff
	!byte $00,$1f,$ff,$00,$3f,$e0,$00,$3f
	!byte $87,$00,$3f,$00,$00,$7c,$01,$00
	!byte $78,$01,$00,$70,$01,$00,$60,$00
	!byte $00,$c0,$00,$00,$80,$00,$00,$80
	!byte $00,$00,$00,$00,$00,$00,$00,$00
rocket_flash_right
	!byte $e0,$00,$00,$f0,$00,$00,$fc,$00
	!byte $00,$fe,$00,$00,$ff,$00,$00,$ff
	!byte $e0,$00,$ff,$e0,$00,$ff,$fc,$00
	!byte $ff,$fc,$00,$07,$fc,$00,$e1,$fe
	!byte $00,$00,$fe,$00,$80,$3f,$00,$80
	!byte $1f,$00,$80,$0f,$00,$00,$07,$00
	!byte $00,$03,$00,$00,$01,$00,$00,$01
	!byte $00,$00,$00,$00,$00,$00,$00,$00

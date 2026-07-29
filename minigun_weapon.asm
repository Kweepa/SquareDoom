; Auto-generated from minigun_* layer PNGs - do not edit
; Nine blobs: B upper+grey L/R @ MINIGUN_B_SPRITES ($2940), then
;   *= MINIGUN_SPRITES: A upper, lower hi, A grey L/R, black L/R.
;   VIC 0/2/3 swap A↔B on fire; 1/4/5 shared. Muzzle: sprites 6–7.
!zone minigun

minigun_b_upperhighlight
	!byte $00,$00,$00,$02,$00,$30,$07,$00
	!byte $78,$04,$00,$18,$01,$ff,$e0,$1b
	!byte $00,$7c,$9f,$00,$7f,$06,$00,$38
	!byte $06,$00,$30,$0e,$00,$38,$06,$00
	!byte $38,$06,$00,$30,$00,$00,$00,$00
	!byte $00,$00,$00,$08,$00,$00,$08,$00
	!byte $00,$08,$00,$00,$00,$40,$07,$00
	!byte $e0,$00,$00,$02,$00,$00,$00,$00
minigun_b_grey_left
	!byte $00,$00,$00,$00,$00,$7c,$00,$01
	!byte $fe,$00,$03,$ff,$00,$07,$ff,$00
	!byte $0f,$ff,$00,$3f,$ff,$00,$37,$f8
	!byte $00,$00,$60,$01,$01,$f0,$00,$01
	!byte $f0,$00,$00,$f0,$00,$01,$f0,$00
	!byte $04,$70,$00,$0c,$70,$00,$0c,$70
	!byte $00,$08,$70,$00,$08,$79,$00,$00
	!byte $f8,$00,$04,$00,$00,$00,$00,$00
minigun_b_grey_right
	!byte $00,$00,$00,$1f,$00,$00,$3f,$c0
	!byte $00,$ff,$e0,$00,$ff,$f0,$00,$ff
	!byte $f8,$00,$ff,$fe,$00,$0f,$fe,$00
	!byte $03,$8b,$80,$87,$c1,$c0,$07,$c0
	!byte $e0,$87,$c0,$f0,$07,$80,$f0,$81
	!byte $a1,$f8,$81,$91,$fc,$81,$99,$fc
	!byte $81,$89,$0e,$ff,$d8,$06,$3f,$79
	!byte $06,$00,$75,$86,$00,$0d,$83,$00
*=MINIGUN_SPRITES

minigun_a_upperhighlight
	!byte $00,$18,$00,$00,$1c,$00,$00,$1c
	!byte $00,$00,$00,$00,$00,$ff,$00,$08
	!byte $3e,$70,$40,$1c,$04,$00,$18,$02
	!byte $00,$1c,$06,$00,$1c,$03,$00,$00
	!byte $03,$00,$00,$03,$80,$00,$00,$80
	!byte $00,$01,$80,$00,$03,$80,$00,$03
	!byte $00,$00,$03,$00,$00,$01,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
minigun_lowerhighlight
	!byte $00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$7f
	!byte $00,$01,$ff,$80,$30,$00,$0c,$00
	!byte $1c,$00,$00,$18,$00,$00,$00,$00
	!byte $00,$00,$00,$00,$00,$00,$00,$ff
	!byte $80,$1c,$7f,$f8,$c0,$1c,$03,$00
minigun_a_grey_left
	!byte $00,$00,$03,$00,$00,$0f,$00,$00
	!byte $1f,$00,$00,$7f,$00,$1f,$ff,$00
	!byte $3f,$ff,$00,$7f,$ff,$00,$3f,$f3
	!byte $00,$ff,$c3,$01,$ff,$07,$03,$fc
	!byte $07,$06,$3c,$00,$08,$1c,$00,$10
	!byte $3c,$80,$00,$3c,$00,$00,$3c,$88
	!byte $00,$9c,$80,$01,$1c,$9f,$01,$0f
	!byte $bf,$05,$0f,$01,$04,$18,$07,$00
minigun_a_grey_right
	!byte $c0,$00,$00,$f0,$00,$00,$f8,$00
	!byte $00,$fc,$00,$00,$ff,$f0,$00,$ff
	!byte $fc,$00,$ff,$fe,$00,$cf,$fe,$00
	!byte $e7,$ff,$80,$f3,$ff,$80,$f1,$ff
	!byte $c0,$f1,$ff,$f0,$f0,$7f,$f8,$f8
	!byte $7c,$78,$f8,$7e,$3c,$f8,$7f,$1c
	!byte $fc,$ff,$8c,$fd,$ff,$88,$ff,$ff
	!byte $c0,$c1,$df,$c6,$f0,$1b,$e2,$00
minigun_black_left
	!byte $00,$ff,$ff,$01,$ff,$ff,$03,$ff
	!byte $ff,$07,$ff,$ff,$0f,$ff,$ff,$1f
	!byte $ff,$ff,$3f,$ff,$ff,$3f,$ff,$ff
	!byte $7f,$ff,$ff,$7f,$ff,$ff,$7f,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$00
minigun_black_right
	!byte $ff,$ff,$00,$ff,$ff,$80,$ff,$ff
	!byte $c0,$ff,$ff,$e0,$ff,$ff,$f0,$ff
	!byte $ff,$f8,$ff,$ff,$f8,$ff,$ff,$fc
	!byte $ff,$ff,$fc,$ff,$ff,$fc,$ff,$ff
	!byte $fe,$ff,$ff,$fe,$ff,$ff,$fe,$ff
	!byte $ff,$fe,$ff,$ff,$ff,$ff,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$00

; Auto-generated from itemgraphics/multicolour/shotgun_*.png - do not edit
; Six body layers (low VIC # = front): highlight, metal, hand.
;   highlight = light grey(15) over barrel/bodyleft/bodyright dark grey(11),
;   hand = brown(9)+orange(8) Floyd-Steinberg.
;   Shared muzzle flash: muzzle_flash.asm (sprites 6–7).
!zone shotgun_weapon

shotgun_highlight
	!byte $00,$00,$00,$00,$10,$00,$00,$00
	!byte $00,$00,$00,$00,$06,$00,$70,$06
	!byte $00,$60,$00,$00,$00,$00,$00,$00
	!byte $1f,$f7,$f8,$1f,$81,$f8,$00,$00
	!byte $00,$00,$00,$00,$00,$42,$00,$00
	!byte $28,$00,$00,$28,$00,$00,$08,$00
	!byte $00,$20,$00,$00,$08,$00,$00,$20
	!byte $00,$00,$08,$00,$00,$00,$00,$00
shotgun_barrel
	!byte $00,$18,$00,$00,$18,$00,$00,$3c
	!byte $00,$00,$7e,$00,$00,$ff,$00,$00
	!byte $ff,$00,$01,$ff,$80,$01,$ff,$80
	!byte $01,$ff,$80,$03,$ff,$c0,$03,$ff
	!byte $c0,$0f,$ff,$f0,$0f,$ff,$f0,$1f
	!byte $ff,$f8,$1f,$ff,$f8,$1f,$ff,$fc
	!byte $3f,$ff,$fc,$3f,$ff,$fc,$3f,$ff
	!byte $fe,$7f,$ff,$fe,$7f,$ff,$ff,$00
shotgun_bodyleft
	!byte $00,$03,$ff,$00,$03,$ff,$00,$07
	!byte $ff,$00,$07,$ff,$00,$07,$ff,$00
	!byte $0f,$ff,$00,$0f,$ff,$00,$0f,$ff
	!byte $00,$1f,$ff,$00,$1f,$ff,$00,$3f
	!byte $ff,$00,$3f,$ff,$00,$7f,$ff,$00
	!byte $7f,$ff,$00,$7f,$ff,$00,$ff,$ff
	!byte $00,$ff,$ff,$00,$ff,$ff,$01,$ff
	!byte $ff,$01,$ff,$ff,$01,$ff,$ff,$00
shotgun_bodyright
	!byte $fc,$00,$00,$fc,$00,$00,$fe,$00
	!byte $00,$fe,$00,$00,$ff,$00,$00,$ff
	!byte $00,$00,$ff,$00,$00,$ff,$80,$00
	!byte $ff,$80,$00,$ff,$c0,$00,$ff,$c0
	!byte $00,$ff,$e0,$00,$ff,$e0,$00,$ff
	!byte $e0,$00,$ff,$f0,$00,$ff,$f0,$00
	!byte $ff,$f0,$00,$ff,$f8,$00,$ff,$f8
	!byte $00,$ff,$f8,$00,$ff,$f8,$00,$00
shotgun_brown
	!byte $00,$00,$00,$00,$44,$00,$00,$58
	!byte $00,$05,$88,$00,$06,$18,$00,$07
	!byte $40,$00,$04,$90,$00,$07,$10,$00
	!byte $0c,$a0,$00,$0a,$a0,$00,$0d,$40
	!byte $00,$0a,$c0,$00,$03,$80,$00,$1e
	!byte $80,$00,$13,$80,$00,$5d,$00,$00
	!byte $4b,$00,$00,$bf,$00,$00,$52,$00
	!byte $00,$e0,$00,$00,$82,$00,$00,$00
shotgun_orange
	!byte $00,$04,$00,$00,$38,$00,$01,$a0
	!byte $00,$02,$70,$00,$01,$e0,$00,$00
	!byte $b0,$00,$03,$60,$00,$08,$e0,$00
	!byte $03,$40,$00,$05,$40,$00,$02,$80
	!byte $00,$05,$00,$00,$1c,$00,$00,$01
	!byte $00,$00,$2c,$00,$00,$22,$00,$00
	!byte $34,$00,$00,$40,$00,$00,$ac,$00
	!byte $00,$1e,$00,$00,$7c,$00,$00,$00

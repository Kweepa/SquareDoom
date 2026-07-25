; Auto-generated from itemgraphics/*.png — do not edit
; 12×8 atlases: mip0 8×8 left; mips 1–3 on right. Column-major, $ff = clear
; Clear = PNG alpha/tRNS if present, else black RGB. Opaque black only with alpha.
; spawn/enemies skip atlases (nodraw stub / enemy_sprites).
!zone item_bitmaps

ITEM_TYPE_COUNT = 30
ITEM_MIP_COUNT = 4

; mip source width / height / log2 (index = mip 0..3)
item_mip_w
	!byte 8,4,2,1
item_mip_h
	!byte 8,4,2,1
item_mip_ushift
	!byte 3,2,1,0
item_mip_vshift
	!byte 3,2,1,0

; Base address lo/hi: index = typeId * ITEM_MIP_COUNT + mip
item_mip_base_lo
	!byte <item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_barrel_m0,<item_spr_barrel_m1,<item_spr_barrel_m2,<item_spr_barrel_m3,<item_spr_health_m0,<item_spr_health_m1,<item_spr_health_m2,<item_spr_health_m3,<item_spr_shells_m0,<item_spr_shells_m1,<item_spr_shells_m2,<item_spr_shells_m3,<item_spr_shotgun_m0,<item_spr_shotgun_m1,<item_spr_shotgun_m2,<item_spr_shotgun_m3,<item_spr_chaingun_m0,<item_spr_chaingun_m1,<item_spr_chaingun_m2,<item_spr_chaingun_m3,<item_spr_chainsaw_m0,<item_spr_chainsaw_m1,<item_spr_chainsaw_m2,<item_spr_chainsaw_m3,<item_spr_rocketlauncher_m0,<item_spr_rocketlauncher_m1,<item_spr_rocketlauncher_m2,<item_spr_rocketlauncher_m3,<item_spr_greenarmor_m0,<item_spr_greenarmor_m1,<item_spr_greenarmor_m2,<item_spr_greenarmor_m3,<item_spr_bluearmor_m0,<item_spr_bluearmor_m1,<item_spr_bluearmor_m2,<item_spr_bluearmor_m3,<item_spr_backpack_m0,<item_spr_backpack_m1,<item_spr_backpack_m2,<item_spr_backpack_m3,<item_spr_redcard_m0,<item_spr_redcard_m1,<item_spr_redcard_m2,<item_spr_redcard_m3,<item_spr_bluecard_m0,<item_spr_bluecard_m1,<item_spr_bluecard_m2,<item_spr_bluecard_m3,<item_spr_yellowcard_m0,<item_spr_yellowcard_m1,<item_spr_yellowcard_m2,<item_spr_yellowcard_m3,<item_spr_soulsphere_m0,<item_spr_soulsphere_m1,<item_spr_soulsphere_m2,<item_spr_soulsphere_m3,<item_spr_poscorpse_m0,<item_spr_poscorpse_m1,<item_spr_poscorpse_m2,<item_spr_poscorpse_m3,<item_spr_impcorpse_m0,<item_spr_impcorpse_m1,<item_spr_impcorpse_m2,<item_spr_impcorpse_m3,<item_spr_demoncorpse_m0,<item_spr_demoncorpse_m1,<item_spr_demoncorpse_m2,<item_spr_demoncorpse_m3,<item_spr_baroncorpse_m0,<item_spr_baroncorpse_m1,<item_spr_baroncorpse_m2,<item_spr_baroncorpse_m3,<item_spr_skullpile_m0,<item_spr_skullpile_m1,<item_spr_skullpile_m2,<item_spr_skullpile_m3,<item_spr_techcolumn_m0,<item_spr_techcolumn_m1,<item_spr_techcolumn_m2,<item_spr_techcolumn_m3,<item_spr_switch_m0,<item_spr_switch_m1,<item_spr_switch_m2,<item_spr_switch_m3,<item_spr_fireball_m0,<item_spr_fireball_m1,<item_spr_fireball_m2,<item_spr_fireball_m3,<item_spr_plasmaball_m0,<item_spr_plasmaball_m1,<item_spr_plasmaball_m2,<item_spr_plasmaball_m3,<item_spr_rocket_m0,<item_spr_rocket_m1,<item_spr_rocket_m2,<item_spr_rocket_m3
item_mip_base_hi
	!byte >item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_barrel_m0,>item_spr_barrel_m1,>item_spr_barrel_m2,>item_spr_barrel_m3,>item_spr_health_m0,>item_spr_health_m1,>item_spr_health_m2,>item_spr_health_m3,>item_spr_shells_m0,>item_spr_shells_m1,>item_spr_shells_m2,>item_spr_shells_m3,>item_spr_shotgun_m0,>item_spr_shotgun_m1,>item_spr_shotgun_m2,>item_spr_shotgun_m3,>item_spr_chaingun_m0,>item_spr_chaingun_m1,>item_spr_chaingun_m2,>item_spr_chaingun_m3,>item_spr_chainsaw_m0,>item_spr_chainsaw_m1,>item_spr_chainsaw_m2,>item_spr_chainsaw_m3,>item_spr_rocketlauncher_m0,>item_spr_rocketlauncher_m1,>item_spr_rocketlauncher_m2,>item_spr_rocketlauncher_m3,>item_spr_greenarmor_m0,>item_spr_greenarmor_m1,>item_spr_greenarmor_m2,>item_spr_greenarmor_m3,>item_spr_bluearmor_m0,>item_spr_bluearmor_m1,>item_spr_bluearmor_m2,>item_spr_bluearmor_m3,>item_spr_backpack_m0,>item_spr_backpack_m1,>item_spr_backpack_m2,>item_spr_backpack_m3,>item_spr_redcard_m0,>item_spr_redcard_m1,>item_spr_redcard_m2,>item_spr_redcard_m3,>item_spr_bluecard_m0,>item_spr_bluecard_m1,>item_spr_bluecard_m2,>item_spr_bluecard_m3,>item_spr_yellowcard_m0,>item_spr_yellowcard_m1,>item_spr_yellowcard_m2,>item_spr_yellowcard_m3,>item_spr_soulsphere_m0,>item_spr_soulsphere_m1,>item_spr_soulsphere_m2,>item_spr_soulsphere_m3,>item_spr_poscorpse_m0,>item_spr_poscorpse_m1,>item_spr_poscorpse_m2,>item_spr_poscorpse_m3,>item_spr_impcorpse_m0,>item_spr_impcorpse_m1,>item_spr_impcorpse_m2,>item_spr_impcorpse_m3,>item_spr_demoncorpse_m0,>item_spr_demoncorpse_m1,>item_spr_demoncorpse_m2,>item_spr_demoncorpse_m3,>item_spr_baroncorpse_m0,>item_spr_baroncorpse_m1,>item_spr_baroncorpse_m2,>item_spr_baroncorpse_m3,>item_spr_skullpile_m0,>item_spr_skullpile_m1,>item_spr_skullpile_m2,>item_spr_skullpile_m3,>item_spr_techcolumn_m0,>item_spr_techcolumn_m1,>item_spr_techcolumn_m2,>item_spr_techcolumn_m3,>item_spr_switch_m0,>item_spr_switch_m1,>item_spr_switch_m2,>item_spr_switch_m3,>item_spr_fireball_m0,>item_spr_fireball_m1,>item_spr_fireball_m2,>item_spr_fireball_m3,>item_spr_plasmaball_m0,>item_spr_plasmaball_m1,>item_spr_plasmaball_m2,>item_spr_plasmaball_m3,>item_spr_rocket_m0,>item_spr_rocket_m1,>item_spr_rocket_m2,>item_spr_rocket_m3

; Transparent stub for spawn / enemy typeIds (never drawn as items)
item_spr_nodraw
	!byte $ff

; Per-type mip blobs
item_spr_barrel_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0d,$ff,$0d,$ff,$ff,$ff,$ff,$0d
	!byte $0d,$0c,$0d,$0c,$0d,$0d,$05,$0d,$05,$0c,$05,$0c,$05,$05,$05,$05
	!byte $05,$0c,$05,$0c,$05,$05,$05,$05,$05,$0c,$05,$0c,$0c,$05,$05,$05
	!byte $05,$0c,$05,$0c,$05,$05,$05,$05,$05,$ff,$05,$ff,$ff,$ff,$ff,$05
item_spr_barrel_m1
	!byte $0d,$0c,$0d,$05,$05,$0c,$05,$05,$05,$0c,$05,$05,$05,$0c,$05,$05
item_spr_barrel_m2
	!byte $0d,$05,$05,$05
item_spr_barrel_m3
	!byte $05
item_spr_health_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$01,$0f,$01,$01,$01,$01
	!byte $ff,$01,$01,$0f,$01,$05,$01,$01,$ff,$01,$01,$0f,$05,$05,$05,$01
	!byte $ff,$01,$01,$0f,$05,$05,$05,$01,$ff,$01,$01,$0f,$01,$05,$01,$01
	!byte $ff,$ff,$01,$0f,$01,$01,$01,$01,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_health_m1
	!byte $01,$0f,$01,$01,$01,$0f,$05,$01,$01,$0f,$01,$01,$ff,$ff,$ff,$ff
item_spr_health_m2
	!byte $01,$01,$01,$05
item_spr_health_m3
	!byte $05
item_spr_shells_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$07,$02,$0a,$0a,$0a
	!byte $ff,$ff,$ff,$ff,$02,$02,$02,$02,$ff,$ff,$ff,$07,$02,$0a,$0a,$0a
	!byte $ff,$ff,$ff,$ff,$02,$02,$02,$02,$ff,$ff,$ff,$07,$02,$0a,$0a,$0a
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_shells_m1
	!byte $ff,$07,$0a,$0a,$ff,$07,$02,$02,$ff,$07,$0a,$0a,$ff,$ff,$ff,$ff
item_spr_shells_m2
	!byte $07,$0a,$07,$0a
item_spr_shells_m3
	!byte $07
item_spr_shotgun_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$02,$02,$ff,$ff,$ff,$ff,$0c,$ff,$02,$02
	!byte $ff,$ff,$ff,$ff,$ff,$0c,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$0c,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0c,$02,$ff
	!byte $ff,$ff,$ff,$ff,$ff,$0c,$02,$ff,$ff,$ff,$ff,$ff,$ff,$0c,$ff,$ff
item_spr_shotgun_m1
	!byte $ff,$0c,$ff,$02,$ff,$ff,$0c,$02,$ff,$ff,$0c,$ff,$ff,$ff,$0c,$02
item_spr_shotgun_m2
	!byte $ff,$0c,$ff,$0c
item_spr_shotgun_m3
	!byte $0c
item_spr_chaingun_m0
	!byte $ff,$ff,$ff,$0c,$0c,$ff,$02,$02,$ff,$ff,$01,$0c,$0c,$02,$02,$02
	!byte $ff,$ff,$01,$0c,$01,$02,$02,$ff,$ff,$ff,$ff,$0c,$0c,$0c,$ff,$ff
	!byte $ff,$ff,$01,$01,$01,$01,$01,$ff,$ff,$ff,$ff,$0c,$0c,$0c,$ff,$ff
	!byte $ff,$ff,$01,$01,$01,$01,$01,$ff,$ff,$ff,$ff,$0c,$ff,$ff,$ff,$ff
item_spr_chaingun_m1
	!byte $ff,$0c,$ff,$02,$01,$0c,$02,$ff,$ff,$01,$01,$ff,$ff,$0c,$ff,$ff
item_spr_chaingun_m2
	!byte $0c,$02,$01,$ff
item_spr_chaingun_m3
	!byte $0c
item_spr_chainsaw_m0
	!byte $ff,$ff,$ff,$00,$00,$07,$07,$07,$ff,$ff,$00,$ff,$00,$02,$07,$07
	!byte $ff,$ff,$ff,$00,$00,$07,$07,$01,$ff,$ff,$ff,$ff,$01,$0c,$0c,$0c
	!byte $ff,$ff,$ff,$ff,$0c,$0c,$0c,$01,$ff,$ff,$ff,$ff,$01,$0c,$0c,$0c
	!byte $ff,$ff,$ff,$ff,$0c,$0c,$0c,$01,$ff,$ff,$ff,$ff,$ff,$01,$0c,$ff
item_spr_chainsaw_m1
	!byte $00,$ff,$07,$07,$ff,$00,$02,$07,$ff,$ff,$01,$0c,$ff,$ff,$0c,$01
item_spr_chainsaw_m2
	!byte $00,$07,$ff,$0c
item_spr_chainsaw_m3
	!byte $0c
item_spr_rocketlauncher_m0
	!byte $ff,$ff,$ff,$ff,$0f,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$02,$02,$ff,$ff
	!byte $ff,$ff,$ff,$ff,$02,$0c,$0c,$0c,$ff,$ff,$ff,$ff,$02,$0f,$0c,$ff
	!byte $ff,$ff,$ff,$ff,$0f,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$0f,$0c,$ff,$ff
	!byte $ff,$ff,$ff,$0f,$0c,$0c,$0c,$ff,$ff,$ff,$ff,$ff,$0f,$0c,$ff,$ff
item_spr_rocketlauncher_m1
	!byte $ff,$ff,$0f,$ff,$ff,$ff,$02,$0c,$ff,$ff,$0f,$ff,$ff,$0c,$0f,$ff
item_spr_rocketlauncher_m2
	!byte $ff,$0f,$ff,$0f
item_spr_rocketlauncher_m3
	!byte $0f
item_spr_greenarmor_m0
	!byte $07,$07,$ff,$ff,$ff,$ff,$ff,$ff,$07,$07,$07,$05,$07,$05,$07,$ff
	!byte $07,$07,$07,$05,$05,$07,$05,$07,$ff,$07,$05,$07,$07,$07,$07,$07
	!byte $ff,$07,$05,$07,$07,$07,$07,$07,$07,$07,$07,$05,$05,$07,$05,$07
	!byte $07,$07,$07,$05,$07,$05,$07,$ff,$07,$07,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_greenarmor_m1
	!byte $07,$05,$07,$ff,$ff,$07,$05,$07,$ff,$07,$05,$07,$07,$05,$07,$ff
item_spr_greenarmor_m2
	!byte $07,$05,$07,$05
item_spr_greenarmor_m3
	!byte $07
item_spr_bluearmor_m0
	!byte $0e,$0e,$ff,$ff,$ff,$ff,$ff,$ff,$0e,$0e,$0e,$06,$0e,$06,$0e,$ff
	!byte $0e,$0e,$0e,$06,$06,$0e,$06,$0e,$ff,$0e,$06,$0e,$0e,$0e,$0e,$0e
	!byte $ff,$0e,$06,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$06,$06,$0e,$06,$0e
	!byte $0e,$0e,$0e,$06,$0e,$06,$0e,$ff,$0e,$0e,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_bluearmor_m1
	!byte $0e,$06,$0e,$ff,$ff,$0e,$06,$0e,$ff,$0e,$06,$0e,$0e,$06,$0e,$ff
item_spr_bluearmor_m2
	!byte $0e,$06,$0e,$06
item_spr_bluearmor_m3
	!byte $0e
item_spr_backpack_m0
	!byte $ff,$ff,$ff,$ff,$08,$08,$08,$ff,$ff,$08,$08,$08,$09,$08,$08,$08
	!byte $08,$08,$08,$08,$09,$08,$08,$08,$08,$08,$08,$09,$08,$08,$08,$08
	!byte $ff,$08,$09,$08,$08,$08,$08,$09,$ff,$ff,$09,$ff,$ff,$ff,$ff,$09
	!byte $ff,$ff,$ff,$09,$ff,$ff,$09,$ff,$ff,$ff,$ff,$ff,$09,$09,$ff,$ff
item_spr_backpack_m1
	!byte $ff,$08,$09,$08,$08,$09,$08,$08,$ff,$09,$ff,$09,$ff,$ff,$09,$ff
item_spr_backpack_m2
	!byte $08,$08,$ff,$09
item_spr_backpack_m3
	!byte $08
item_spr_redcard_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0a,$0a,$0a,$0a,$0a,$0a
	!byte $ff,$0a,$0a,$07,$07,$0a,$07,$0a,$0a,$0a,$07,$0a,$07,$07,$0a,$0a
	!byte $0a,$02,$02,$02,$02,$02,$02,$0a,$0a,$0a,$02,$02,$0a,$0a,$0a,$0a
	!byte $0a,$02,$02,$02,$02,$02,$02,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a
item_spr_redcard_m1
	!byte $ff,$ff,$ff,$ff,$ff,$0a,$07,$0a,$0a,$02,$02,$0a,$0a,$0a,$0a,$0a
item_spr_redcard_m2
	!byte $0a,$07,$02,$0a
item_spr_redcard_m3
	!byte $0a
item_spr_bluecard_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0e,$0e,$0e,$0e,$0e,$0e
	!byte $ff,$0e,$0e,$03,$03,$0e,$03,$0e,$0e,$0e,$03,$0e,$03,$03,$0e,$0e
	!byte $0e,$06,$06,$06,$06,$06,$06,$0e,$0e,$0e,$06,$06,$0e,$0e,$0e,$0e
	!byte $0e,$06,$06,$06,$06,$06,$06,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e
item_spr_bluecard_m1
	!byte $ff,$ff,$ff,$ff,$ff,$0e,$03,$0e,$0e,$06,$06,$0e,$0e,$0e,$0e,$0e
item_spr_bluecard_m2
	!byte $0e,$03,$06,$0e
item_spr_bluecard_m3
	!byte $0e
item_spr_yellowcard_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$07,$07,$07,$07,$07,$07
	!byte $ff,$07,$07,$02,$02,$07,$02,$07,$07,$07,$02,$07,$02,$02,$07,$07
	!byte $07,$05,$05,$05,$05,$05,$05,$07,$07,$07,$05,$05,$07,$07,$07,$07
	!byte $07,$05,$05,$05,$05,$05,$05,$07,$07,$07,$07,$07,$07,$07,$07,$07
item_spr_yellowcard_m1
	!byte $ff,$ff,$ff,$ff,$ff,$07,$02,$07,$07,$05,$05,$07,$07,$07,$07,$07
item_spr_yellowcard_m2
	!byte $07,$02,$05,$07
item_spr_yellowcard_m3
	!byte $07
item_spr_soulsphere_m0
	!byte $ff,$ff,$06,$06,$06,$06,$ff,$ff,$ff,$06,$0e,$06,$0e,$06,$06,$ff
	!byte $06,$0e,$ff,$01,$0e,$06,$06,$06,$06,$0e,$0e,$ff,$06,$ff,$ff,$0e
	!byte $06,$0e,$0e,$ff,$06,$ff,$ff,$06,$06,$0e,$ff,$01,$0e,$06,$06,$06
	!byte $ff,$06,$0e,$06,$0e,$06,$06,$ff,$ff,$ff,$06,$06,$06,$06,$ff,$ff
item_spr_soulsphere_m1
	!byte $ff,$06,$06,$ff,$06,$0e,$ff,$06,$06,$0e,$ff,$06,$ff,$06,$06,$ff
item_spr_soulsphere_m2
	!byte $0e,$06,$0e,$06
item_spr_soulsphere_m3
	!byte $0e
item_spr_poscorpse_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$02,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0e,$02
	!byte $ff,$ff,$ff,$ff,$ff,$0e,$0e,$0e,$ff,$ff,$ff,$ff,$06,$0e,$06,$ff
	!byte $ff,$ff,$ff,$ff,$0e,$0e,$0e,$ff,$ff,$ff,$ff,$ff,$0e,$0e,$06,$02
	!byte $ff,$ff,$ff,$ff,$0e,$0e,$02,$08,$ff,$ff,$ff,$ff,$06,$0e,$06,$ff
item_spr_poscorpse_m1
	!byte $ff,$ff,$ff,$02,$ff,$ff,$0e,$06,$ff,$ff,$0e,$02,$ff,$ff,$0e,$06
item_spr_poscorpse_m2
	!byte $ff,$0e,$ff,$0e
item_spr_poscorpse_m3
	!byte $0e
item_spr_impcorpse_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$08,$08
	!byte $ff,$ff,$ff,$0c,$ff,$08,$0c,$08,$ff,$ff,$ff,$ff,$08,$08,$09,$ff
	!byte $ff,$ff,$ff,$ff,$08,$08,$08,$ff,$ff,$ff,$ff,$ff,$08,$08,$0c,$08
	!byte $ff,$ff,$ff,$ff,$08,$08,$08,$08,$ff,$ff,$ff,$ff,$0c,$08,$09,$ff
item_spr_impcorpse_m1
	!byte $ff,$ff,$ff,$08,$ff,$ff,$0c,$09,$ff,$ff,$08,$08,$ff,$ff,$08,$09
item_spr_impcorpse_m2
	!byte $ff,$08,$ff,$08
item_spr_impcorpse_m3
	!byte $08
item_spr_demoncorpse_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0a,$0f
	!byte $ff,$ff,$ff,$ff,$0a,$0a,$0a,$0a,$ff,$ff,$ff,$02,$0a,$0a,$02,$ff
	!byte $ff,$ff,$ff,$0a,$0a,$0a,$0a,$ff,$ff,$ff,$ff,$0a,$0a,$0a,$02,$0f
	!byte $ff,$ff,$ff,$0a,$0a,$0a,$0f,$02,$ff,$ff,$ff,$02,$0a,$0a,$02,$ff
item_spr_demoncorpse_m1
	!byte $ff,$ff,$02,$0f,$ff,$02,$0a,$02,$ff,$0a,$0a,$0f,$ff,$0a,$0a,$02
item_spr_demoncorpse_m2
	!byte $ff,$0a,$ff,$0a
item_spr_demoncorpse_m3
	!byte $0a
item_spr_baroncorpse_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0c,$0c
	!byte $ff,$ff,$ff,$ff,$02,$09,$08,$09,$ff,$ff,$ff,$02,$0a,$08,$09,$ff
	!byte $ff,$ff,$ff,$02,$02,$09,$09,$ff,$ff,$ff,$ff,$02,$0a,$08,$0c,$0c
	!byte $ff,$ff,$ff,$0a,$02,$09,$0c,$09,$ff,$ff,$ff,$02,$0a,$02,$09,$ff
item_spr_baroncorpse_m1
	!byte $ff,$ff,$02,$0c,$ff,$02,$0a,$02,$ff,$0a,$02,$0c,$ff,$02,$0a,$02
item_spr_baroncorpse_m2
	!byte $ff,$02,$ff,$0a
item_spr_baroncorpse_m3
	!byte $02
item_spr_skullpile_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$07,$07,$ff,$ff,$ff,$ff,$0c
	!byte $ff,$01,$07,$02,$02,$ff,$0c,$0c,$07,$07,$ff,$ff,$ff,$0c,$0c,$0c
	!byte $01,$07,$ff,$ff,$02,$02,$02,$0c,$ff,$ff,$07,$07,$ff,$ff,$0c,$0c
	!byte $ff,$ff,$01,$07,$ff,$ff,$ff,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_skullpile_m1
	!byte $ff,$07,$ff,$0c,$07,$02,$02,$0c,$ff,$ff,$07,$0c,$ff,$ff,$ff,$ff
item_spr_skullpile_m2
	!byte $07,$0c,$07,$0c
item_spr_skullpile_m3
	!byte $07
item_spr_techcolumn_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$0f,$ff,$ff,$ff,$ff,$0f,$ff
	!byte $0c,$0f,$0c,$0f,$0c,$0f,$0f,$0c,$0c,$0f,$0c,$0f,$0f,$0c,$0f,$0c
	!byte $0c,$0c,$0f,$0c,$0f,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$0f,$0c,$0c
	!byte $ff,$0c,$ff,$ff,$ff,$ff,$0c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_techcolumn_m1
	!byte $ff,$0f,$ff,$0f,$0c,$0c,$0f,$0c,$0c,$0f,$0c,$0c,$ff,$0c,$ff,$0c
item_spr_techcolumn_m2
	!byte $0f,$0f,$0c,$0c
item_spr_techcolumn_m3
	!byte $0c
item_spr_switch_m0
	!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
	!byte $ff,$ff,$0c,$0c,$ff,$ff,$ff,$0c,$ff,$0c,$0c,$0c,$ff,$ff,$0c,$0c
	!byte $0c,$07,$0c,$0c,$0c,$0c,$0c,$0c,$0c,$07,$0c,$0c,$ff,$ff,$0c,$0c
	!byte $0c,$0c,$0c,$ff,$ff,$ff,$ff,$0c,$0c,$0c,$ff,$ff,$ff,$ff,$ff,$ff
item_spr_switch_m1
	!byte $ff,$ff,$ff,$ff,$ff,$0c,$ff,$0c,$0c,$07,$0c,$0c,$0c,$ff,$ff,$0c
item_spr_switch_m2
	!byte $ff,$ff,$07,$0c
item_spr_switch_m3
	!byte $07
item_spr_fireball_m0
	!byte $ff,$ff,$02,$ff,$02,$ff,$02,$ff,$02,$ff,$02,$02,$08,$02,$ff,$ff
	!byte $ff,$02,$08,$07,$07,$08,$02,$02,$02,$08,$07,$07,$07,$07,$02,$ff
	!byte $ff,$02,$07,$07,$07,$07,$08,$02,$02,$02,$08,$07,$07,$08,$02,$ff
	!byte $ff,$ff,$02,$08,$02,$02,$ff,$02,$ff,$02,$ff,$02,$ff,$02,$ff,$ff
item_spr_fireball_m1
	!byte $ff,$02,$02,$ff,$02,$07,$07,$02,$02,$07,$07,$02,$ff,$02,$02,$ff
item_spr_fireball_m2
	!byte $02,$07,$07,$02
item_spr_fireball_m3
	!byte $07
item_spr_plasmaball_m0
	!byte $ff,$ff,$05,$ff,$05,$ff,$05,$ff,$05,$ff,$05,$05,$07,$05,$ff,$ff
	!byte $ff,$05,$07,$0d,$0d,$07,$05,$05,$05,$07,$0d,$0d,$0d,$0d,$05,$ff
	!byte $ff,$05,$0d,$0d,$0d,$0d,$07,$05,$05,$05,$07,$0d,$0d,$07,$05,$ff
	!byte $ff,$ff,$05,$07,$05,$05,$ff,$05,$ff,$05,$ff,$05,$ff,$05,$ff,$ff
item_spr_plasmaball_m1
	!byte $ff,$05,$05,$ff,$05,$0d,$0d,$05,$05,$0d,$0d,$05,$ff,$05,$05,$ff
item_spr_plasmaball_m2
	!byte $0d,$0d,$0d,$0d
item_spr_plasmaball_m3
	!byte $0d
item_spr_rocket_m0
	!byte $ff,$ff,$02,$ff,$02,$ff,$02,$ff,$02,$ff,$02,$02,$08,$02,$ff,$ff
	!byte $ff,$02,$08,$07,$07,$08,$02,$02,$02,$08,$07,$07,$07,$07,$02,$ff
	!byte $ff,$02,$07,$07,$07,$07,$08,$02,$02,$02,$08,$07,$07,$08,$02,$ff
	!byte $ff,$ff,$02,$08,$02,$02,$ff,$02,$ff,$02,$ff,$02,$ff,$02,$ff,$ff
item_spr_rocket_m1
	!byte $ff,$02,$02,$ff,$02,$07,$07,$02,$02,$07,$07,$02,$ff,$02,$02,$ff
item_spr_rocket_m2
	!byte $02,$07,$07,$02
item_spr_rocket_m3
	!byte $07

; Auto-generated from itemgraphics/*.png — do not edit
; 12×8 atlases: mip0 8×8 left; mips 1–3 on right. Column-major, 0 = transparent
; spawn/enemies skip atlases (nodraw stub / enemy_sprites).
!zone item_bitmaps

ITEM_TYPE_COUNT = 23
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
	!byte <item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_nodraw,<item_spr_barrel_m0,<item_spr_barrel_m1,<item_spr_barrel_m2,<item_spr_barrel_m3,<item_spr_health_m0,<item_spr_health_m1,<item_spr_health_m2,<item_spr_health_m3,<item_spr_shells_m0,<item_spr_shells_m1,<item_spr_shells_m2,<item_spr_shells_m3,<item_spr_shotgun_m0,<item_spr_shotgun_m1,<item_spr_shotgun_m2,<item_spr_shotgun_m3,<item_spr_chaingun_m0,<item_spr_chaingun_m1,<item_spr_chaingun_m2,<item_spr_chaingun_m3,<item_spr_chainsaw_m0,<item_spr_chainsaw_m1,<item_spr_chainsaw_m2,<item_spr_chainsaw_m3,<item_spr_greenarmor_m0,<item_spr_greenarmor_m1,<item_spr_greenarmor_m2,<item_spr_greenarmor_m3,<item_spr_bluearmor_m0,<item_spr_bluearmor_m1,<item_spr_bluearmor_m2,<item_spr_bluearmor_m3,<item_spr_backpack_m0,<item_spr_backpack_m1,<item_spr_backpack_m2,<item_spr_backpack_m3,<item_spr_redcard_m0,<item_spr_redcard_m1,<item_spr_redcard_m2,<item_spr_redcard_m3,<item_spr_bluecard_m0,<item_spr_bluecard_m1,<item_spr_bluecard_m2,<item_spr_bluecard_m3,<item_spr_yellowcard_m0,<item_spr_yellowcard_m1,<item_spr_yellowcard_m2,<item_spr_yellowcard_m3,<item_spr_skullpile_m0,<item_spr_skullpile_m1,<item_spr_skullpile_m2,<item_spr_skullpile_m3,<item_spr_techcolumn_m0,<item_spr_techcolumn_m1,<item_spr_techcolumn_m2,<item_spr_techcolumn_m3,<item_spr_switch_opendoor_m0,<item_spr_switch_opendoor_m1,<item_spr_switch_opendoor_m2,<item_spr_switch_opendoor_m3,<item_spr_switch_endlevel_m0,<item_spr_switch_endlevel_m1,<item_spr_switch_endlevel_m2,<item_spr_switch_endlevel_m3,<item_spr_switch_lowerlift_m0,<item_spr_switch_lowerlift_m1,<item_spr_switch_lowerlift_m2,<item_spr_switch_lowerlift_m3
item_mip_base_hi
	!byte >item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_nodraw,>item_spr_barrel_m0,>item_spr_barrel_m1,>item_spr_barrel_m2,>item_spr_barrel_m3,>item_spr_health_m0,>item_spr_health_m1,>item_spr_health_m2,>item_spr_health_m3,>item_spr_shells_m0,>item_spr_shells_m1,>item_spr_shells_m2,>item_spr_shells_m3,>item_spr_shotgun_m0,>item_spr_shotgun_m1,>item_spr_shotgun_m2,>item_spr_shotgun_m3,>item_spr_chaingun_m0,>item_spr_chaingun_m1,>item_spr_chaingun_m2,>item_spr_chaingun_m3,>item_spr_chainsaw_m0,>item_spr_chainsaw_m1,>item_spr_chainsaw_m2,>item_spr_chainsaw_m3,>item_spr_greenarmor_m0,>item_spr_greenarmor_m1,>item_spr_greenarmor_m2,>item_spr_greenarmor_m3,>item_spr_bluearmor_m0,>item_spr_bluearmor_m1,>item_spr_bluearmor_m2,>item_spr_bluearmor_m3,>item_spr_backpack_m0,>item_spr_backpack_m1,>item_spr_backpack_m2,>item_spr_backpack_m3,>item_spr_redcard_m0,>item_spr_redcard_m1,>item_spr_redcard_m2,>item_spr_redcard_m3,>item_spr_bluecard_m0,>item_spr_bluecard_m1,>item_spr_bluecard_m2,>item_spr_bluecard_m3,>item_spr_yellowcard_m0,>item_spr_yellowcard_m1,>item_spr_yellowcard_m2,>item_spr_yellowcard_m3,>item_spr_skullpile_m0,>item_spr_skullpile_m1,>item_spr_skullpile_m2,>item_spr_skullpile_m3,>item_spr_techcolumn_m0,>item_spr_techcolumn_m1,>item_spr_techcolumn_m2,>item_spr_techcolumn_m3,>item_spr_switch_opendoor_m0,>item_spr_switch_opendoor_m1,>item_spr_switch_opendoor_m2,>item_spr_switch_opendoor_m3,>item_spr_switch_endlevel_m0,>item_spr_switch_endlevel_m1,>item_spr_switch_endlevel_m2,>item_spr_switch_endlevel_m3,>item_spr_switch_lowerlift_m0,>item_spr_switch_lowerlift_m1,>item_spr_switch_lowerlift_m2,>item_spr_switch_lowerlift_m3

; Transparent stub for spawn / enemy typeIds (never drawn as items)
item_spr_nodraw
	!byte $00

; Per-type mip blobs
item_spr_barrel_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$0d,$00,$0d,$00,$00,$00,$00,$0d
	!byte $0d,$0b,$0d,$0b,$0d,$0d,$05,$0d,$05,$0b,$05,$0b,$05,$05,$05,$05
	!byte $05,$0b,$05,$0b,$05,$05,$05,$05,$05,$0b,$05,$0c,$0b,$05,$05,$05
	!byte $05,$0b,$05,$0b,$05,$05,$05,$05,$05,$00,$05,$00,$00,$00,$00,$05
item_spr_barrel_m1
	!byte $0d,$0b,$0d,$05,$05,$0b,$05,$05,$05,$0b,$05,$05,$05,$0b,$05,$05
item_spr_barrel_m2
	!byte $0d,$05,$05,$05
item_spr_barrel_m3
	!byte $05
item_spr_health_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$0f,$01,$01,$01,$01
	!byte $00,$01,$01,$0f,$01,$05,$01,$01,$00,$01,$01,$0f,$05,$05,$05,$01
	!byte $00,$01,$01,$0f,$05,$05,$05,$01,$00,$01,$01,$0f,$01,$05,$01,$01
	!byte $00,$00,$01,$0f,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00
item_spr_health_m1
	!byte $01,$0f,$01,$01,$01,$0f,$05,$01,$01,$0f,$01,$01,$00,$00,$00,$00
item_spr_health_m2
	!byte $01,$01,$01,$05
item_spr_health_m3
	!byte $05
item_spr_shells_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$02,$0a,$0a,$0a
	!byte $00,$00,$00,$00,$02,$02,$02,$02,$00,$00,$00,$07,$02,$0a,$0a,$0a
	!byte $00,$00,$00,$00,$02,$02,$02,$02,$00,$00,$00,$07,$02,$0a,$0a,$0a
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
item_spr_shells_m1
	!byte $00,$07,$0a,$0a,$00,$07,$02,$02,$00,$07,$0a,$0a,$00,$00,$00,$00
item_spr_shells_m2
	!byte $07,$0a,$07,$0a
item_spr_shells_m3
	!byte $07
item_spr_shotgun_m0
	!byte $00,$00,$00,$00,$00,$00,$08,$08,$00,$00,$00,$00,$0b,$00,$08,$08
	!byte $00,$00,$00,$00,$00,$0b,$0f,$00,$00,$00,$00,$00,$00,$0b,$00,$00
	!byte $00,$00,$00,$00,$00,$0b,$00,$00,$00,$00,$00,$00,$00,$0b,$08,$00
	!byte $00,$00,$00,$00,$00,$0b,$08,$00,$00,$00,$00,$00,$00,$0b,$00,$00
item_spr_shotgun_m1
	!byte $00,$0b,$00,$08,$00,$00,$0b,$08,$00,$00,$0b,$00,$00,$00,$0b,$08
item_spr_shotgun_m2
	!byte $00,$0b,$00,$0b
item_spr_shotgun_m3
	!byte $0b
item_spr_chaingun_m0
	!byte $00,$00,$00,$0c,$0c,$00,$08,$08,$00,$00,$01,$0c,$0c,$08,$08,$08
	!byte $00,$00,$01,$0c,$01,$08,$08,$00,$00,$00,$00,$0c,$0c,$0c,$00,$00
	!byte $00,$00,$01,$01,$01,$01,$01,$00,$00,$00,$00,$0c,$0c,$0c,$00,$00
	!byte $00,$00,$01,$01,$01,$01,$01,$00,$00,$00,$00,$0c,$00,$00,$00,$00
item_spr_chaingun_m1
	!byte $00,$0c,$00,$08,$01,$0c,$08,$00,$00,$01,$01,$00,$00,$0c,$00,$00
item_spr_chaingun_m2
	!byte $0c,$08,$01,$00
item_spr_chaingun_m3
	!byte $0c
item_spr_chainsaw_m0
	!byte $03,$03,$03,$00,$00,$07,$07,$07,$03,$03,$00,$03,$00,$08,$07,$07
	!byte $03,$03,$03,$00,$00,$07,$07,$01,$03,$03,$03,$03,$01,$0b,$0b,$0c
	!byte $03,$03,$03,$03,$0c,$0b,$0b,$01,$03,$03,$03,$03,$01,$0b,$0b,$0c
	!byte $03,$03,$03,$03,$0c,$0b,$0b,$01,$03,$03,$03,$03,$03,$01,$0c,$03
item_spr_chainsaw_m1
	!byte $00,$03,$07,$07,$03,$00,$08,$07,$03,$03,$01,$0c,$03,$03,$0c,$01
item_spr_chainsaw_m2
	!byte $00,$07,$03,$0c
item_spr_chainsaw_m3
	!byte $0c
item_spr_greenarmor_m0
	!byte $07,$07,$00,$00,$00,$00,$00,$00,$07,$07,$07,$05,$07,$05,$07,$00
	!byte $07,$07,$07,$05,$05,$07,$05,$07,$00,$07,$05,$07,$07,$07,$07,$07
	!byte $00,$07,$05,$07,$07,$07,$07,$07,$07,$07,$07,$05,$05,$07,$05,$07
	!byte $07,$07,$07,$05,$07,$05,$07,$00,$07,$07,$00,$00,$00,$00,$00,$00
item_spr_greenarmor_m1
	!byte $07,$05,$07,$00,$00,$07,$05,$07,$00,$07,$05,$07,$07,$05,$07,$00
item_spr_greenarmor_m2
	!byte $07,$05,$07,$05
item_spr_greenarmor_m3
	!byte $07
item_spr_bluearmor_m0
	!byte $0e,$0e,$00,$00,$00,$00,$00,$00,$0e,$0e,$0e,$06,$0e,$06,$0e,$00
	!byte $0e,$0e,$0e,$06,$06,$0e,$06,$0e,$00,$0e,$06,$0e,$0e,$0e,$0e,$0e
	!byte $00,$0e,$06,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$06,$06,$0e,$06,$0e
	!byte $0e,$0e,$0e,$06,$0e,$06,$0e,$00,$0e,$0e,$00,$00,$00,$00,$00,$00
item_spr_bluearmor_m1
	!byte $0e,$06,$0e,$00,$00,$0e,$06,$0e,$00,$0e,$06,$0e,$0e,$06,$0e,$00
item_spr_bluearmor_m2
	!byte $0e,$06,$0e,$06
item_spr_bluearmor_m3
	!byte $0e
item_spr_backpack_m0
	!byte $00,$00,$00,$00,$08,$08,$08,$00,$00,$08,$08,$08,$09,$08,$08,$08
	!byte $08,$08,$08,$08,$09,$08,$08,$08,$08,$08,$08,$09,$08,$08,$08,$08
	!byte $00,$08,$09,$08,$08,$08,$08,$09,$00,$00,$09,$00,$00,$00,$00,$09
	!byte $00,$00,$00,$09,$00,$00,$09,$00,$00,$00,$00,$00,$09,$09,$00,$00
item_spr_backpack_m1
	!byte $00,$08,$09,$08,$08,$09,$08,$08,$00,$09,$00,$09,$00,$00,$09,$00
item_spr_backpack_m2
	!byte $08,$08,$00,$09
item_spr_backpack_m3
	!byte $08
item_spr_redcard_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0a,$0a,$0a,$0a,$0a,$0a
	!byte $00,$0a,$0a,$07,$07,$0a,$07,$0a,$0a,$0a,$07,$0a,$07,$07,$0a,$0a
	!byte $0a,$08,$08,$08,$08,$08,$08,$0a,$0a,$0a,$08,$08,$0a,$0a,$0a,$0a
	!byte $0a,$08,$08,$08,$08,$08,$08,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a
item_spr_redcard_m1
	!byte $00,$00,$00,$00,$00,$0a,$07,$0a,$0a,$08,$08,$0a,$0a,$0a,$0a,$0a
item_spr_redcard_m2
	!byte $0a,$07,$08,$0a
item_spr_redcard_m3
	!byte $0a
item_spr_bluecard_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0e,$0e,$0e,$0e,$0e,$0e
	!byte $00,$0e,$0e,$03,$03,$0e,$03,$0e,$0e,$0e,$03,$0e,$03,$03,$0e,$0e
	!byte $0e,$06,$06,$06,$06,$06,$06,$0e,$0e,$0e,$06,$06,$0e,$0e,$0e,$0e
	!byte $0e,$06,$06,$06,$06,$06,$06,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e
item_spr_bluecard_m1
	!byte $00,$00,$00,$00,$00,$0e,$03,$0e,$0e,$06,$06,$0e,$0e,$0e,$0e,$0e
item_spr_bluecard_m2
	!byte $0e,$03,$06,$0e
item_spr_bluecard_m3
	!byte $0e
item_spr_yellowcard_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$07,$07,$07,$07,$07
	!byte $00,$07,$07,$08,$08,$07,$08,$07,$07,$07,$08,$07,$08,$08,$07,$07
	!byte $07,$05,$05,$05,$05,$05,$05,$07,$07,$07,$05,$05,$07,$07,$07,$07
	!byte $07,$05,$05,$05,$05,$05,$05,$07,$07,$07,$07,$07,$07,$07,$07,$07
item_spr_yellowcard_m1
	!byte $00,$00,$00,$00,$00,$07,$08,$07,$07,$05,$05,$07,$07,$07,$07,$07
item_spr_yellowcard_m2
	!byte $07,$08,$05,$07
item_spr_yellowcard_m3
	!byte $07
item_spr_skullpile_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$07,$00,$00,$00,$00,$0c
	!byte $00,$01,$07,$08,$08,$00,$0c,$0b,$07,$07,$00,$00,$00,$0c,$0b,$0b
	!byte $01,$07,$00,$00,$08,$08,$08,$0b,$00,$00,$07,$07,$00,$00,$0b,$0b
	!byte $00,$00,$01,$07,$00,$00,$00,$0b,$00,$00,$00,$00,$00,$00,$00,$00
item_spr_skullpile_m1
	!byte $00,$07,$00,$0c,$07,$08,$08,$0b,$00,$00,$07,$0b,$00,$00,$00,$00
item_spr_skullpile_m2
	!byte $07,$0c,$07,$0b
item_spr_skullpile_m3
	!byte $07
item_spr_techcolumn_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$00,$00,$00,$00,$0f,$00
	!byte $0b,$0f,$0b,$0f,$0b,$0f,$0f,$0b,$0b,$0f,$0b,$0f,$0f,$0b,$0f,$0b
	!byte $0b,$0b,$0f,$0b,$0f,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b,$0f,$0b,$0b
	!byte $00,$0b,$00,$00,$00,$00,$0b,$00,$00,$00,$00,$00,$00,$00,$00,$00
item_spr_techcolumn_m1
	!byte $00,$0f,$00,$0f,$0b,$0b,$0f,$0b,$0b,$0f,$0b,$0b,$00,$0b,$00,$0b
item_spr_techcolumn_m2
	!byte $0f,$0f,$0b,$0b
item_spr_techcolumn_m3
	!byte $0c
item_spr_switch_opendoor_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$0c,$0b,$00,$00,$00,$0c,$00,$0c,$0c,$0b,$00,$00,$0c,$0c
	!byte $0c,$07,$0c,$0b,$0b,$0c,$0b,$0c,$0c,$07,$0c,$0b,$00,$00,$0b,$0b
	!byte $0c,$0c,$0b,$00,$00,$00,$00,$0b,$0c,$0b,$00,$00,$00,$00,$00,$00
item_spr_switch_opendoor_m1
	!byte $00,$00,$00,$00,$00,$0c,$00,$0c,$0c,$07,$0b,$0c,$0c,$00,$00,$0b
item_spr_switch_opendoor_m2
	!byte $00,$00,$07,$0c
item_spr_switch_opendoor_m3
	!byte $07
item_spr_switch_endlevel_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$0c,$0b,$00,$00,$00,$0c,$00,$0c,$0c,$0b,$00,$00,$0c,$0c
	!byte $0c,$07,$0c,$0b,$0b,$0c,$0b,$0c,$0c,$07,$0c,$0b,$00,$00,$0b,$0b
	!byte $0c,$0c,$0b,$00,$00,$00,$00,$0b,$0c,$0b,$00,$00,$00,$00,$00,$00
item_spr_switch_endlevel_m1
	!byte $00,$00,$00,$00,$00,$0c,$00,$0c,$0c,$07,$0b,$0c,$0c,$00,$00,$0b
item_spr_switch_endlevel_m2
	!byte $00,$00,$07,$0c
item_spr_switch_endlevel_m3
	!byte $07
item_spr_switch_lowerlift_m0
	!byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	!byte $00,$00,$0c,$0b,$00,$00,$00,$0c,$00,$0c,$0c,$0b,$00,$00,$0c,$0c
	!byte $0c,$07,$0c,$0b,$0b,$0c,$0b,$0c,$0c,$07,$0c,$0b,$00,$00,$0b,$0b
	!byte $0c,$0c,$0b,$00,$00,$00,$00,$0b,$0c,$0b,$00,$00,$00,$00,$00,$00
item_spr_switch_lowerlift_m1
	!byte $00,$00,$00,$00,$00,$0c,$00,$0c,$0c,$07,$0b,$0c,$0c,$00,$00,$0b
item_spr_switch_lowerlift_m2
	!byte $00,$00,$07,$0c
item_spr_switch_lowerlift_m3
	!byte $07

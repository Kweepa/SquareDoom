; Build tmp/sprites.bin — 4032-byte image at VIC_SPRITES ($C800–$D7BF).
; Copied to runtime under $01=$34 (PRG must not LOAD into $D000).
!cpu 6502
!to "tmp/sprites.bin", plain
!source "mem_vic.asm"
*=MINIGUN_B_SPRITES
!source "minigun_weapon.asm"
*=FIST_RIGHT_SPRITES
!source "fist_righthand.asm"
*=FIST_PUNCH_SPRITES
!source "fist_punch.asm"
*=CHAINSAW_BLADE_HI2_SPRITES
!source "chainsaw_weapon.asm"
*=ROCKET_SPRITES
!source "rocket_weapon.asm"
*=SHOTGUN_SPRITES
!source "shotgun_weapon.asm"
*=PISTOL_SPRITES
!source "pistol_sprites.asm"
*=MUZZLE_FLASH_SPRITES
!source "muzzle_flash.asm"
*=SHOTGUN_COCK_SPRITES
!source "shotgun_cock_sprites.asm"
!if * != VIC_SPRITES + SPRITE_BYTES {
	!error "sprites.bin end=$", *, " expected $", VIC_SPRITES + SPRITE_BYTES
}

; MENU.PRG — menu UI overlay at MENU_BASE (play buffers after UI_LOAD_MAX)
!cpu 6502
!to "screens/menu.prg", cbm
!source "menu_imports.asm"
* = MENU_BASE
!source "menu_overlay.asm"
!if * > MENU_LIMIT {
	!error "menu overlay past COL_CLIP_END; end=$", *, " limit=$", MENU_LIMIT
}
!warn "menu overlay end=$", *, " free to MENU_LIMIT =", MENU_LIMIT - *

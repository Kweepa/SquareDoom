; Controls help text — load address $c800 (FRAMEBUFFER)
!to "screens/help.prg", cbm
* = $c800
	!scr "^controls^",0
	!scr " ",0
	!scr "move forward      w",0
	!scr "move backward     s",0
	!scr "strafe left       a",0
	!scr "strafe right      d",0
	!scr "turn left         j",0
	!scr "turn right        l",0
	!scr "use               k",0
	!scr "fire              space",0
	!scr "toggle map        f1",0
	!scr " ",0
	!scr "switch weapon    12345",0
	!scr "menu              runstop",0
	!scr " ",0
	!scr "press a key",0
	!byte 0

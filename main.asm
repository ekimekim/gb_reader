include "debug.asm"
include "ioregs.asm"

Section "Core Stack", WRAM0

CoreStackBase:
	ds 64
CoreStack::


Section "Core Functions", ROM0


Start::

	; Disable LCD and audio.
	; Disabling LCD must be done in VBlank.
	; On hardware start, we have about half a normal vblank, but this may depend on the hardware variant.
	; So this has to be done quick!
	xor A
	ld [SoundControl], A
	ld [LCDControl], A

	Debug "Debug messages enabled"

	; Use core stack
	ld SP, CoreStack

	call GraphicsInit
	call ReadInit

	; Enable graphics
	ld A, [LCDControl]
	or %10000000
	ld [LCDControl], A

	; Disable all interrupts but enable interrupt flag.
	; This makes halt a true halt forever.
	xor A
	ld [InterruptsEnabled], A
	ei

	jp HaltForever

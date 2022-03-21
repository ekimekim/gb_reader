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
	; Interrupts will be selectively enabled as needed.
	xor A
	ld [InterruptsEnabled], A
	ei

	; Display initial screen
	call ReadScreen

	jp InputLoop


InputLoop:
	; Very simlified input scheme. It waits for a joypad interrupt,
	; then looks for a single pressed key. Does nothing if multiple are pressed.
	; Afterwards, it waits for another joypad interrupt, which requires releasing all keys.

	; Init joypad to only consider d-pad
	ld A, JoySelectDPad
	ld [JoyIO], A

.loop
	; clear any existing joypad interrupt
	xor A
	ld [InterruptFlags], A
	; wait for joypad interrupt by masking all other interrupts
	ld A, IntEnableJoypad
	ld [InterruptsEnabled], A
	halt

	; read joypad. unset bits in bottom 4 bits are pressed buttons
	ld A, [JoyIO]
	; invert and mask to get a number 0-15, just to make things easier
	cpl
	and $0f

	; check for 4 exact values, so any multiple presses do nothing

	; Right: Advance page
	cp 1
	jr nz, .no_right
	ld C, 18
	call AdvanceScreen
	jr .loop

.no_right
	; Left: Rewind page
	cp 2
	jr nz, .no_left
	ld C, 18
	call RollbackScreen
	jr .loop

.no_left
	; Up: Rewind line
	cp 4
	jr nz, .no_up
	ld C, 1
	call RollbackScreen
	jr .loop

.no_up
	; Down: Advance line
	cp 8
	jr nz, .loop
	ld C, 1
	call AdvanceScreen
	jr .loop

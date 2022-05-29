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

; Takes two args Buttons and DPad. If the arg is 1, the corresponding button set is selected
; in JoyIO.
; Clobbers A.
JoySelect: MACRO
	; The meaning is inverted here, so we start at 0x30 and minus the constants
	; (unsetting the bit) if selected.
	ld A, $30 - (((\1) * $20) + ((\2) * $10))
	ld [JoyIO], A
	; We need to wait for 6 cycles for the new value to take effect
	REPT 6
	nop
	ENDR
ENDM

; Read joypad state and return it in A as (highest to lowest bit, set means pressed)
; (Start, Select, B, A, Down, Up, Left, Right).
; Clobbers B.
ReadJoypad:
	JoySelect 1, 0
	ld A, [JoyIO]
	and $0f
	swap A
	ld B, A ; store first half in B
	JoySelect 0, 1
	ld A, [JoyIO]
	and $0f
	or B ; combine with first half
	cpl ; invert, because unset bits mean pressed
	ret

InputLoop:
	; Very simlified input scheme. It waits for a joypad interrupt,
	; then looks for a single pressed key. Does nothing if multiple are pressed.
	; Afterwards, it waits for another joypad interrupt, which requires releasing all keys.

.loop
	; Set joypad to detect any press, so interrupt fires for any
	JoySelect 1, 1

	; clear any existing joypad interrupt
	xor A
	ld [InterruptFlags], A
	; wait for joypad interrupt by masking all other interrupts
	ld A, IntEnableJoypad
	ld [InterruptsEnabled], A
	halt

	call ReadJoypad ; A = (Start, Select, B, A, Down, Up, Left, Right)
	; check for exact values, so any multiple presses do nothing

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
	jr nz, .no_down
	ld C, 1
	call AdvanceScreen
	jr .loop

.no_down
	; Select: Show/hide block numbers
	cp 64
	jr nz, .no_select
	call ToggleBlockNumbers
	; Avoid bouncing input by waiting for next frame before accepting more input
	; TODO We still have bouncing problems on release.
	call WaitForFrame
	jr .loop

.no_select
	; Start: Suspend
	cp 128
	jr nz, .loop
	call Suspend
	jr .loop


WaitForFrame:
	xor A
	ld [InterruptFlags], A
	ld A, IntEnableVBlank
	ld [InterruptsEnabled], A
	halt
	ret


Suspend:
	; Stop is complicated. To properly enter stop mode, we need to ensure
	; no selected buttons are pressed in JoyIO (or else we only enter halt mode).
	; It won't exit stop mode until a selected button in JoyIO is pressed.
	; So you can't just deselect everything.
	; We're going to abuse the fact that we only call this when Start is pressed,
	; and set it up so you can only exit by pressing a DPad button.
	JoySelect 0, 1

	; Stop generally (not always!) skips the next instruction on return.
	stop
	nop

	; We still hit issues here where the input used to end the Stop bounces and then also
	; gets taken as an actual input.

	ret

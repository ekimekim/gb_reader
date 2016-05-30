; Sets up default interrupt handlers at default interrupt table location (I = $00)
; Default handlers do nothing but re-enable interrupts and return

section "VBlank Interrupt handler", ROM0 [$40]
	VBlankInt::
		ei
		reti

section "LCD Status Interrupt handler", ROM0 [$40]
	LCDStatusInt::
		ei
		reti

section "Timer Overflow Interrupt handler", ROM0 [$40]
	TimerInt::
		ei
		reti

section "Serial Link Interrupt handler", ROM0 [$40]
	SerialInt::
		ei
		reti

section "Joypad Press Interrupt handler", ROM0 [$40]
	JoypadInt::
		ei
		reti



include "macros.asm"
include "hram.asm"
include "ioregs.asm"

; TODO this should be SRAM but bgb won't allow it?
SECTION "Reader state", WRAM0

; These 8 bytes must match "gbreader". If they don't, we assume SRAM is uninitialized.
SaveMagic:
	ds 8

; Tail refers to the position at the start of the most-back rendered line.
; Each is a pair consisting of a bank byte and an addr. Addr is assumed to always
; be a ROMX addr (ie. 0x4000-0x7fff).
ReadTailBank:
	ds 1
ReadTailAddr:
	ds 2

SECTION "Reader RAM", WRAM0

; Data is copied from the ROM to here so that it can be rendered.
; Since the thinnest character is 2 bits, the max chars in two lines is 4 * 20 * 18
ReadData:
	ds 4 * 20 * 18

SECTION "Reader methods", ROM0

SaveMagicCheck:
	db "gbreader"

; Initialize graphics and other state.
; Assumes screen is off.
ReadInit::
	call SRAMInit
	ret


; Initalize SRAM state if needed
SRAMInit:
	; Check if SaveMagic is correct
	ld HL, SaveMagic
	ld DE, SaveMagicCheck
	ld B, 8
.magic_check
	ld A, [DE]
	cp [HL]
	jr nz, .magic_failed
	inc DE
	inc HL
	dec B
	jr nz, .magic_check

	; magic passed
	ret

.magic_failed
	; init tail to (2, $4000)
	ld A, 2
	ld [ReadTailBank], A
	ld A, $40
	ld [ReadTailAddr], A
	xor A
	ld [ReadTailAddr+1], A
	; write magic. we only do this once sram is initialized to prevent races.
	ld HL, SaveMagicCheck
	ld DE, SaveMagic
	ld B, 8
	Copy

	ret


ReadScreen::
	; Ensure correct bank is loaded
	ld A, [ReadTailBank]
	SetROMBank
	; Load ReadTail into HL
	ld A, [ReadTailAddr]
	ld H, A
	ld A, [ReadTailAddr+1]
	ld L, A
	; Write to WRAM
	ld DE, ReadData
	; Write 18 lines
	ld B, 18

.loop
	ld A, [HL]
	; Check if char is end-of-bank
	inc A ; if [HL] == ff, set z
	jr z, .advance_bank

.line_loop
	ld A, [HL+]
	ld [DE], A
	inc DE
	and A ; set z if end of line
	jr nz, .line_loop

	dec B
	jr nz, .loop

	ld DE, ReadData
	call RenderScreen

	ret

.advance_bank
	ld A, [ReadTailBank]
	inc A
	SetROMBank
	; reset read head to start of ROMX
	ld HL, $4000
	jr .loop

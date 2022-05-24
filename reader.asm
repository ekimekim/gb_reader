
include "macros.asm"
include "hram.asm"
include "ioregs.asm"

; text.asm defines its own SECTIONs in ROMX
include "assets/text.asm"

SECTION "Text data sentinel", ROM0[$3fff]
	; This is used as a marker so we know when we've scrolled backwards off the start of a bank
	db $ff

; TODO this should be SRAM but bgb won't allow it?
SECTION "Reader state", WRAM0

; These 8 bytes must match "gbreader". If they don't, we assume SRAM is uninitialized.
SaveMagic:
	ds 8

; Tail refers to the position at the start of the most-back rendered line.
; Each is a pair consisting of a bank byte and an addr. Addr is assumed to always
; be a ROMX addr (ie. 0x4000-0x7fff).
ReadTailBank::
	ds 1
ReadTailAddr::
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


; Adjusts screen position forward by C lines.
; The result is clamped to end of book.
AdvanceScreen::
	; Ensure correct bank is loaded, and save it in B
	ld A, [ReadTailBank]
	ld B, A
	SetROMBank

	; Load ReadTail into HL
	ld A, [ReadTailAddr]
	ld H, A
	ld A, [ReadTailAddr+1]
	ld L, A

.loop
	ld A, [HL+]
	inc A ; set z if A = ff, ie. next bank
	jr z, .advance_bank
	dec A
	dec A ; set z if A = 1, ie. EOF
	jr z, .eof
	inc A ; set z if A = 0, ie. newline
	jr nz, .loop ; if not newline, loop
	dec C ; count a line
	jr nz, .loop

.done
	; save result bank and addr
	ld A, B
	ld [ReadTailBank], A
	ld A, H
	ld [ReadTailAddr], A
	ld A, L
	ld [ReadTailAddr+1], A

	call ReadScreen ; refresh screen for new position
	ret

.advance_bank
	inc B
	ld A, B
	SetROMBank
	ld HL, $4000
	jr .loop

.eof
	; adjust HL back 1, since we previously incremented it past the EOF marker
	dec HL
	; and stop here, even if we have more lines to do
	jr .done


; As AdvanceScreen but moves backwards. Will not scroll past start of book.
RollbackScreen::
	; Ensure correct bank is loaded, and save it in B
	ld A, [ReadTailBank]
	ld B, A
	SetROMBank

	; Load ReadTail into HL
	ld A, [ReadTailAddr]
	ld H, A
	ld A, [ReadTailAddr+1]
	ld L, A

	; we start just before a newline, which we don't want to count.
	; so we want to go 1 more newline than lines requested.
	inc C

.loop
	dec HL
.loop_no_dec
	ld A, [HL]
	inc A ; set z if A = ff, ie. prev bank
	jr z, .rollback_bank
	dec A ; set z if A = 0, ie. newline
	jr nz, .loop ; if not newline, loop
	dec C ; count a line
	jr nz, .loop

.done
	; at this point HL points at the newline immediately before
	; the position we want. So we inc HL to put it in the right place.
	inc HL

	; save result bank and addr
	ld A, B
	ld [ReadTailBank], A
	ld A, H
	ld [ReadTailAddr], A
	ld A, L
	ld [ReadTailAddr+1], A

	call ReadScreen ; refresh screen for new position
	ret

.rollback_bank
	dec B
	ld A, B
	cp TEXT_START_BANK ; set c if A < TEXT_START_BANK, ie. if we're at start of text
	jr c, .start
	; otherwise set bank and keep going
	SetROMBank
	; seek backwards until we find $ff marker
	ld HL, $7fff
.rollback_loop
	ld A, [HL-]
	inc A ; set z if A = ff
	jr nz, .rollback_loop
	jr .loop_no_dec

.start
	; adjust bank forward 1, since we previously decremented it past the start bank
	inc B
	; and stop here, even if we have more lines to do
	jr .done


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

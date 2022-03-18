include "hram.asm"
include "ioregs.asm"
include "macros.asm"
include "vram.asm" ; TEMP

SECTION "Font data", ROMX[$4000], BANK[1]

FontData EQUS "(FontWidths + 256)"
FontWidths:

include "assets/varfont.asm"

SECTION "Text rendering methods", ROM0


; Renders 20 lines from DE to the staging data area.
; Note: Clobbers loaded WRAM and ROM banks.
RenderScreen::
	ld A, Bank(FontWidths)
	SetROMBank
	; First 10 lines go into first staging area
	ld A, Bank(StagingData)
	ld [CGBWRAMBank], A
	xor A ; TEMP
	ld [CGBVRAMBank], A ; TEMP
	ld HL, BaseTileMap ;TEMP StagingData
REPT 10
	call RenderLine
ENDR
	; Second 10 lines go into second staging area
	ld A, Bank(StagingData2)
	ld [CGBWRAMBank], A
	ld A, 1 ; TEMP
	ld [CGBVRAMBank], A ; TEMP
	ld HL, BaseTileMap ;TEMP StagingData2
REPT 10
	call RenderLine
ENDR
;TEMP	call CopyStagingData
	ret


; Renders a single line of text to the staging data area. Inputs:
;   HL: Points to first tile of the line in the staging data area (WRAM bank should already be set)
;   DE: Points to the first char of the line of text to render (which must be accessibly with current rom bank)
; Current rom bank must be the font data.
; On return:
;   HL: Points to first tile of next line
;   DE: Points to first char of next line
RenderLine:
	ld B, 0 ; 32 * current rendition
	ld A, 20
	ld [Scratch], A ; number of tiles in this row still uninitialized

.render_char
	ld A, [DE] ; load character
	inc DE
	sub 32 ; characters from DE are ascii, but table indexes start at char 32 (space)
	jp c, .newline ; if char < 32, we've hit end of line, break.
	push DE

	; Grab the char width. This is easier to do now so we can reuse DE.
	; Note FontWidths is 256-byte aligned.
	ld D, High(FontWidths)
	ld E, A ; DE = FontWidths + character
	ld A, [DE]
	ld C, A ; C = char width
	ld A, E ; restore character back to A

	; Calculate start of character rendition
	add High(FontData) << 1 ; FontData is in ROM so top bit is 0, so shifting left is safe.
	                        ; This also clears carry.
	rra ; Since carry is 0, this is a right shift. Bottom bit of A is now in carry.
	ld D, A ; D = High(FontData) + (character >> 1)
	ld E, B
	rr E ; E = 128 * carry + (B >> 1) = 128 * bottom bit of character + 16 * rendition
	; ergo DE = High(FontData) + 128 * character + 16 * rendition = start of target rendition
	; (Note FontData is 256-byte aligned)

	; special case: rendition is 0. In this case we want to directly overwrite instead of ORing.
	ld A, B
	and A
	jr z, .overwrite

	; for each row of character pixels in first half, OR in the new pixels.
REPT 8
	; get pixels for row
	ld A, [DE]
	inc DE
	; combine into HL via bitwise OR
	or [HL]
	; write back to HL twice - each row is repeated in order to set high and low bits.
	; we don't care about setting them differently since we're black-and-white.
	ld [HL+], A
	ld [HL+], A
ENDR

.overwrite_return
	; Add char width to rendition. Note both are in units of 32 * bit width.
	; Because of this, we wrap at a width of 8 (32 * 8 = 256).
	ld A, B
	add C ; set carry if we overflow to next char
	ld B, A
	jr nc, .no_overflow

	; Check if rendition = 0, ie. we perfectly filled a tile.
	; In this case we can skip the second write loop, saving some time
	; (plus correctness if we've just filled a line). We also don't want to reset HL.
	; Note however that this leaves the next char uninitialized, and we have a corresponding
	; special case in the first half to handle that (this special case is also needed for the
	; first char).
	jr z, .skip_overflow

	; First time writing to a tile, decrement [Scratch]
	ld A, [Scratch]
	dec A
	ld [Scratch], A

	; for each row of character pixels in second half, copy them without OR-ing
	; (overwriting old values)
REPT 8
	; get pixels for row
	ld A, [DE]
	inc DE
	; write to HL twice, see above
	ld [HL+], A
	ld [HL+], A
ENDR

.no_overflow
	; Reset HL to the start of the current tile. This is 6 cycles which is marginally faster
	; than stashing it on the stack (7 bytes ideally, but has problems with whether we overflowed).
	dec HL ; Since tiles are 16-byte aligned, this fixes the high byte if needed.
	ld A, L
	sub 15
	ld L, A

.skip_overflow
	pop DE
	jr .render_char

.overwrite
	; First time writing to a tile, decrement [Scratch]
	ld A, [Scratch]
	dec A
	ld [Scratch], A

REPT 8
	; get pixels for row
	ld A, [DE]
	inc DE
	; write to HL twice, see above
	ld [HL+], A
	ld [HL+], A
ENDR
	jr .overwrite_return

.newline
	; From here we need to fill the rest of the line with blank.
	; First, we need to check if the current tile is partially written, by checking the rendition in B.
	ld A, B
	and A ; set z if 0
	jr z, .no_next_tile

	; Advance HL to the next tile. Reverse of earlier "reset HL" op, uses the fact it's 16-byte aligned.
	ld A, L
	add 15
	ld L, A
	inc HL

.no_next_tile
	; We've saved the number of remaining uninitialized tiles in Scratch, which may be 0.
	ld A, [Scratch]
	and A ; set z if 0
	ret z ; if we've written to all tiles, we're done
	ld B, A
	xor A

.blank_loop
REPT 16
	ld [HL+], A
ENDR
	dec B
	jr nz, .blank_loop

	ret

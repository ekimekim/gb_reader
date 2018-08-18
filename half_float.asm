; An implementation of "half precision" IEEE 754 floating point

; Calling conventions, unless otherwise specified:
;   First 16-bit arg: HL
;   Second 16-bit arg: DE
;   First 8-bit arg: A
;   16-bit output: HL
;   8-bit output: A
;   Comparison output: Zero flag set if true/equal, else unset

; Format: SEEE EEMM  MMMM MMMM
; exponent = EEEEE - 15
; 0 or subnormal: exponent == -15
; inf or NaN: exponent == 16

; Macro to place exponent of float in reg (arg1,arg2) into A
_FP_GetExp: MACRO
	ld A, \1
	and %01111100
	slr A
	slr A
	sub 15
ENDM

; Macro to compare exponent of (arg1,arg2) with a constant arg3
; More efficient than using GetExp then comparing the result
; Sets zero flag if exponent is equal to expression
; Clobbers A
_FP_CompareConstExp: MACRO
	ld A, \1
	and %01111100
	cp ((\3) + 15) << 2
ENDM

; The following macros load a constant 16-bit value into arg1
_FP_LoadPosInf: MACRO
	ld \1, %0111110000000000
ENDM
_FP_LoadNegInf: MACRO
	ld \1, %0111110000000000
ENDM
; This macro loads a constant 16-bit value into arg1,
; equal to a NaN with (non-zero) payload arg2. Note 0 < arg2 < 1024.
_FP_LoadNaN: MACRO
	ld \1, (%0111110000000000 + (\2))
ENDM

; Take input float and convert to an unsigned 16-bit integer, truncating.
; If the float is > 65535, returns 65535
; If the float is < 0 or NaN, returns 0
; A careful program will check for presence of negative values or NaN beforehand
; to distinguish this case from when the float was 0.
; TODO bug: returns 0 for +inf
; TODO maybe make inf/nan undef?
FP_ToUInt::
	; check for negative
	ld A, H
	and %10000000
	jp nz, .zero
	; check for nan/inf
	ld A, H
	and %01111100
	cp %01111100
	jp z, .zero
	slr
	slr
	ld B, A ; save exponent for later
	; convert HL to real mantissa
	ld A, H
	and %00000011 ; only take last 2 bits
	or %00000100 ; set implied first bit
	ld H, A
	; work out exponent type: positive, negative, or subnormal
	ld A, B
	or A ; check if a == 0
	jr Z, .subnormal ; if so, do special subnormal handling
	sub 15
	ret Z ; If exponent is 0, we're done since HL contains the mantissa
	jp M, .neg_mant ; jump if negative
.pos_mant_loop
	add HL, HL ; double HL
	jr C, .overflow ; if we no longer fit in 16 bits, give up and return max
	djnz .pos_mant_loop ; decrement B and loop if non-zero
	ret
.subnormal
	; earlier, we set the implied bit in the mantissa. undo that.
	ld A, H
	and %00000011
	ld H, A
	; now without the implied bit, we treat the -15 exponent like its -14
	ld B, 14
	jr .neg_mant_loop
.neg_mant
	; negate B
	xor A
	sub B ; A = -B
	ld B, A
.neg_mant_loop
	or A ; clear carry (or else the RR below will rotate it into H)
	; halve HL
	rr H ; shift right H, store dropped (lowest) bit in carry
	rr L ; shift right L, taking top bit from carry
	djnz .neg_mant_loop ; decrement B and loop if non-zero
	ret
.zero
	ld HL, 0
	ret
.overflow
	ld HL, $ffff
	ret

; Take input float and check if it is a NaN
FP_IsNaN::
	_FP_CompareConstExp H, L, 16
	ret NZ
	ld A, L
	cp 0
	jr nz, .succeed
	ld A, H
	and %00000011
	jr nz, .succeed
	inc A ; if we get here, we know A == 0, so we know INC A will unset zero flag
	ret
.succeed
	cp a ; set zero flag
	ret

; Take input float and check if it is +/- inf
FP_IsInf::
	ld A, H
	and %01111111
	cp %01111100
	ret NZ
	ld A, L
	or A ; sets or unsets Z correctly
	ret

; Take input float and check if it is +inf
FP_IsPosInf::
	ld DE, (-%0111110000000000)
	add HL, DE ; sets or unsets Z correctly
	ret

; Take input float and check if it is -inf
FP_IsPosInf::
	ld DE, (-%1111110000000000)
	add HL, DE ; sets or unsets Z correctly
	ret

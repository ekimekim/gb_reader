; A default header that jumps to the Start symbol
; We do not define Start here.

import Start

section "Header", ROM0 [$100]
	; This must be nop, then a jump, then blank up to 150
	_Start:
		nop
		jp Start
	_Header::
		; Linker will fill this in
		ds $150 - _Header

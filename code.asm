.dseg
.equ BAUD = 25
.equ FRAME = $86
.equ CHAN = 0x18
.cseg
reset: rjmp init_stack
.org $32

init_stack:					;initializes stack
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16

init:						;initializes external memory interface and LCD
	rcall init_mcu
	rcall init_uart
	rcall initial_start

main:
	rcall poweru_banner

fini: rjmp fini

;-------------------------------
init_mcu:					;initializes the external memory interface
	ldi r17, $80
	out MCUCR, r17
	RET

init_uart: ;Serial port initialization routine
	ldi R16, 0 ;always zero (mostly)
	out UBRRH, R16
	ldi R16, BAUD
	out UBRRL, R16 ;config. Tx baud rate w/equ value
	ldi R16, CHAN
	out UCSRB, R16 ;enable transmit only (see p.156)
	ldi R16, FRAME
	out UCSRC, R16
	RET
initial_start:				;initializes LCD
	rcall delay40ms

	ldi r17, $38
	sts $2000, r17
	rcall delay40us

	ldi r17, $38
	sts $2000, r17
	rcall delay40us

	ldi r17, $0F
	sts $2000, r17
	rcall delay40us

	ldi r17, $01
	sts $2000, r17
	rcall delay2ms

	ldi r17, $06
	sts $2000, r17
	rcall delay40us

	RET

poweru_banner:
	rcall ban_msg
	rcall second_line
	rcall id_num
	RET	

delay40ms:					;delays intialization 
	ldi r16, 40
	rcall msdelay1
	RET

delay2ms:
	ldi r16, 2
	rcall msdelay1
	RET

delay1ms:
	ldi r16, 1
	rcall msdelay1
	RET

msdelay1:
	ldi r17, 100

msdelay2:					;repeats 100 times (loop has 10 cycles) (1ms)
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	dec r17
	brne msdelay2

	dec r16
	brne msdelay1
	RET

delay40us:
	ldi r16, 4

usdelay:					;repeats 4 times (loop has 10 cycles) (40us)
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	NOP
	dec r16
	brne usdelay
	RET

banner_msg: .db "SCADA Mon v1.0",$04
ban_msg: 
	ldi r30, LOW(banner_msg<<1)	;Loads flash address of banner_msg into z register
	ldi r31, HIGH(banner_msg<<1)
	RCALL out_filt
	RET

out_filt:					;Checks for end character
	;clr r18
	lpm r18, z+
	cpi r18, $04
	brne lcd_outs
	RET

lcd_outs:					;sends character to LCD
	sts $2100, r18
	rcall delay1ms
	rcall outch
	rjmp out_filt

second_line:				;Places the cursor on the second line
	ldi r17, $C0
	sts $2000, r17

	ldi r18, $0A			;Line feed for serial communication
	rcall outch
	ldi r18, $0D
	rcall outch
	RET

idmsg: .db "1835111",$04
id_num: 
	ldi r30, LOW(idmsg<<1)	;Loads flash address of idmsg into z register
	ldi r31, HIGH(idmsg<<1)
	RCALL out_filt

	ldi r18, $0A			;Line feed for serial communication
	rcall outch
	ldi r18, $0D
	rcall outch
	RET

outch:
	out UDR,r18				;txmt char. out the TxD
	RCALL poll_sts
	RET

poll_sts:
	 in R18, UCSRA			;read status
	andi R18, $20			;check for tx complete
	breq poll_sts
	RET
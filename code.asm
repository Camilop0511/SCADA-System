.dseg
samples: .byte 256

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
	rcall lcd_init
	rcall init_portb
	rcall init_reg

main:
	rcall poweru_banner
	rcall mode_sel
	rcall delay4s
	;rcall poweru_banner

fini:
	;rjmp fini
	rcall mode_sel
	rjmp fini

;-----------------------------------------------------------------------------------
init_mcu:					;initializes the external memory interface
	ldi r17, $80
	out MCUCR, r17
	RET

init_uart:					;Serial port initialization routine
	ldi R16, 0				;always zero (mostly)
	out UBRRH, R16
	ldi R16, BAUD
	out UBRRL, R16			;config. Tx baud rate w/equ value
	ldi R16, CHAN
	out UCSRB, R16			;enable transmit only (see p.156)
	ldi R16, FRAME
	out UCSRC, R16
	RET
lcd_init:				;initializes LCD
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

init_portb:
	ldi r16, $0
	out DDRB, r16
	RET

init_reg:
	ldi r23, $0
	ldi r24, $0
	ldi r19, $87			;trim level calibrated(in theory is $7F)
	RET

poweru_banner:
	rcall ban_msg
	rcall second_line_lcd
	rcall new_line
	rcall id_num
	rcall delay4s
	rcall clear_dis
	rcall clr_terminal
	RET	

clear_dis:
	ldi r17, $01
	sts $2000, r17
	rcall delay2ms
	RET

delay40ms:					;delays intialization 
	ldi r27, 0
	ldi r26, 40
	rcall msdelay1
	RET

delay2ms:
	ldi r27, 0
	ldi r26, 2
	rcall msdelay1
	RET

delay1ms:
	ldi r27, 0
	ldi r26, 1
	rcall msdelay1
	RET

delay4s:
	ldi r27, $0F
	ldi r26, $A0
	rcall msdelay1
	RET	

delay2s:
	ldi r27, $07
	ldi r26, $d0
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

	sbiw x,1
	brne msdelay1
	RET

delay40us:	ldi r29, HIGH(samples)
	ldi r28, LOW(samples)
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
	rcall out_filt_lcd

	rcall clr_terminal
	ldi r30, LOW(banner_msg<<1)	;Loads flash address of banner_msg into z register
	ldi r31, HIGH(banner_msg<<1)
	rcall out_filt_term
	RET

out_filt_lcd:					;Checks for end character
	lpm r18, z+
	cpi r18, $04
	brne lcd_outs
	RET

lcd_outs:					;sends character to LCD
	sts $2100, r18
	rcall delay1ms
	rjmp out_filt_lcd
	RET

second_line_lcd:				;Places the cursor on the second line
	ldi r17, $C0
	sts $2000, r17
	rcall delay2ms
	RET

idmsg: .db "1835111",$04
id_num: 
	ldi r30, LOW(idmsg<<1)	;Loads flash address of idmsg into z register
	ldi r31, HIGH(idmsg<<1)
	rcall out_filt_lcd

	ldi r30, LOW(idmsg<<1)	;Loads flash address of idmsg into z register
	ldi r31, HIGH(idmsg<<1)
	rcall out_filt_term
	RET

out_filt_term:					;Checks for end character
	lpm r18, z+
	cpi r18, $04
	brne outch
	RET

outch:
	out UDR,r18				;txmt char. out the TxD
	rcall poll_sts
	rjmp out_filt_term

poll_sts:
	in R16, UCSRA			;read status
	andi R16, $20			;check for tx complete
	breq poll_sts
	ret

newli_cmd: .db $0A, $0D, $04
new_line:

	ldi r30, LOW(newli_cmd<<1)	;Loads flash address of idmsg into z register
	ldi r31, HIGH(newli_cmd<<1)
	rcall out_filt_term

	RET
;--------------------------------------

clr_com: .db $1B,"[2J",$1B,"[H",$04			;Escape sequence to clear emulator
clr_terminal:
	ldi r30, LOW(clr_com<<1)				;Loads flash address of clr_com into z register
	ldi r31, HIGH(clr_com<<1)
	rcall out_filt_term
	RET
	
mode_sel:									;selects mode depending on input on PORTB
	in r22, PINB
	andi r22, 1

	cpi r22, 1
	breq mode_sel_super
	cpi r22, 0
	breq mode_sel_node
	RET

mode_sel_super:
	rcall mode_super_comp
	;rcall getch
	;rcall outch2
	RET

mode_super_comp:
	cpi r23, $0
	breq super_m
	RET

mode_sel_node:
	rcall mode_node_comp
	;rcall node_m
	rcall getch
	mov r18, r25
	rcall outch2
	rcall mode_node_comm
	RET

mode_node_comp:
	cpi r24, $0
	breq node_m
	cpi r24, $1
	breq node_m2
	RET

getch:				;gets char typed by user
	in r25, UCSRA
	rcall standb_mes
	andi r25, $80	;receive complete
	breq getch
	in r25, UDR
	RET

supm_msg: .db "Supervisor Mode", $04
super_prompt: .db "Svr#", $04
super_m:
	rcall clear_dis
	rcall clr_terminal

	ldi r30, LOW(supm_msg<<1)	;Loads flash address of supm_msg into z register
	ldi r31, HIGH(supm_msg<<1)
	rcall out_filt_lcd

	ldi r30, LOW(supm_msg<<1)	;Loads flash address of supm_msg into z register
	ldi r31, HIGH(supm_msg<<1)
	rcall out_filt_term
	rcall new_line

	ldi r30, LOW(super_prompt<<1)	;Loads flash address of super_prompt into z register
	ldi r31, HIGH(super_prompt<<1)
	rcall out_filt_term
	rcall standb_mes

	ldi r23, 1
	ldi r24, 0
	RET


nodem_msg: .db "Node Mode", $04
node_prompt: .db "Node>", $04
node_m:
	rcall clear_dis
	rcall clr_terminal

	ldi r30, LOW(nodem_msg<<1)	;Loads flash address of nodem_msg into z register
	ldi r31, HIGH(nodem_msg<<1)
	rcall out_filt_lcd

	ldi r30, LOW(nodem_msg<<1)	;Loads flash address of nodem_msg into z register
	ldi r31, HIGH(nodem_msg<<1)
	rcall out_filt_term
	
	

node_m2:
	
	rcall new_line
	ldi r30, LOW(node_prompt<<1)	;Loads flash address of node_prompt into z register
	ldi r31, HIGH(node_prompt<<1)
	rcall out_filt_term
	

	ldi r23, 0
	ldi r24, 1
	RET

stndb_msg: .db "Mode Standby", $04
standb_mes:
	rcall second_line_lcd
	ldi r30, LOW(stndb_msg<<1)	;Loads flash address of stndb_msg into z register
	ldi r31, HIGH(stndb_msg<<1)
	rcall out_filt_lcd
	RET

;---------------------------------------------------------
;-----------------------Node Mode-------------------------

mode_node_comm:			;Node Mode commands selection
	cpi r18, 'A'
	breq adc_monitor_init
	/*cpi r16, 'S'
	breq super_sum
	cpi r16, 'T'
	breq new_trim*/
	;rjmp mode_sel
	RET

adc_monitor_init:
	ldi r25, 0			;counters
	ldi r20, 0
	
	ldi r29, HIGH(samples)
	ldi r28, LOW(samples)

adc_monitor:
	lds r21, $6000
	
	st y+, r21
	
	;mov r18, r21
	;rcall outch2

	inc r25
	rcall delay2ms
	cp r20, r25
	brne adc_monitor
	rcall samples_num_init
	RET

outch2:
	out UDR,R18 ;txmt char. out the TxD
	RCALL poll_sts
	RET

samples_num_init:
	ldi r29, HIGH(samples)
	ldi r28, LOW(samples)

	;clr r20, 0
	clr r5
	;ldi r25, 0
	clr r6
	clr r0
	ldi r17, 0
	

sample_num:
	ld r21, y+

	;mov r18, r21
	;rcall outch2


	cp r17,r0
	;brlo digit2asci_init
	inc r0
	breq digit2ascii_lcd

	cp r21, r19
	brlo sample_lower
	cp r21, r19
	brsh sample_higher 
	RET

sample_lower:
	;inc r20
	inc r5
	rjmp sample_num
	RET

sample_higher:
	;inc r25
	inc r6
	rjmp sample_num
	RET

digit2ascii_lcd:
	;mov r16, r20
	mov r16, r5
	rcall hex2asc

	;mov r18, r16		;sample_lower msb
	mov r10, r16
	;rcall outch2
	;rcall delay40us
	;mov r18, r17		;sample_lower lsb
	mov r11, r17
	;rcall outch2

	mov r16, r6
	rcall hex2asc

	;mov r18, r16		;sample_higher msb
	mov r12, r16
	;rcall outch2
	;rcall delay40us
	;mov r18, r17		;sample_higher lsb
	mov r13, r17
	;rcall outch2


	rcall clear_second_line_init
	rcall LandHdisplay_init
	RET

clear_second_line_init:
	clr r5
	ldi r16, 16
	ldi r21, $20
	rcall second_line_lcd

clear_second_line:		;clears second line of lcd only

	sts $2100, r21
	rcall delay2ms
	inc r5
	cp r5, r16
	brlo clear_second_line
	rcall second_line_lcd
	RET

LandHdisplay_init:
	ldi r16, $4c		;L
	ldi r20, $3a		;:
	ldi r22, $48		;H

LandHdisplay:
	sts $2100, r16		;L
	rcall delay2ms
	sts $2100, r20		;:
	rcall delay2ms
	sts $2100, r10		;sample_lower msb
	rcall delay2ms
	sts $2100, r11		;sample_lower lsb
	rcall delay2ms
	sts $2100, r21		;space
	rcall delay2ms
	sts $2100, r22		;H
	rcall delay2ms
	sts $2100, r20		;:
	rcall delay2ms
	sts $2100, r12		;sample_higher msb
	rcall delay2ms
	sts $2100, r13		;sample_higher lsb
	rcall com_comp
	RET

com_completed: .db $0A,$0D,"Command Completed!", $04
com_comp:
	ldi r30, LOW(com_completed<<1)	;Loads flash address of nodem_msg into z register
	ldi r31, HIGH(com_completed<<1)
	
	rcall out_filt_term
	rcall delay2s
	RET
	
	
.nolist
.include "numio.inc"   ;append library subroutines from same folder

/*
 * Lab1.asm
 *
 *  Created: 11/15/2016 8:22:25 AM
 *   Author: nikni292
 */ 


	.def	time = r21		; 
	.def	byte = r020		; 
	.def	letter = r19	; if we should print
	.def	flag = r18		; 

	ldi		r16, HIGH(RAMEND)	
	out		SPH, r16	
	ldi		r16, LOW(RAMEND) 
	out		SPL, r16 
	call	INIT 
RESET:
	clr		letter			; clear letter 
LISTEN: 
	sbis	PINA,0			; 
	jmp		LISTEN			; if not signal, keep listening
	call	DELAY_2			; if signal wait T/2 
	sbis	PINA,0			; 
	jmp		LISTEN			; it was a disturbance in the force
	call	FULL_READ		; do one full read 
	ldi		r16, $FF		; 
	cpse	flag, r16		; flag == 1111 1111
	jmp		RESET			; start over if stopbit not == 0 
	call	PRINT			; else print letter 
	jmp		RESET			; start over 
FULL_READ: 
	call	DELAY				; wait T 
	call	READ				; read b0 
	call	DELAY				; wait T 
	call	READ				; read b1 
	call	DELAY				; wait T 
	call	READ				; read b2 
	call	DELAY				; wait T 
	call	READ				; read b3 
	call	DELAY				; wait T
	call	READ_END			; read stopbit
	ret 
READ: 
	in		byte, PINA			; byte is now xxx xxxb 
	andi	byte, $01			; 0000 0001
	ror		byte				; carry is now b 
	rol		letter				; insert carry into letter 
	ret
READ_END:
	sbic	PINA,0				; 
	ldi		flag, $00			; stop bit is 1, start over
	ldi		flag, $FF			; stop bit is 0, print
	ret 
DELAY: 
	sbi		 PORTB,7 
	mov		r16, time
delayYttreLoop: 
	ldi		r17,$FF
delayInreLoop: 
	dec		r17
	brne	delayInreLoop 
	dec		r16
	brne	delayYttreLoop
	cbi		PORTB, 7 
	ret 
DELAY_2: 
	sbi		PORTB,7
	mov		r17, time 
	lsr		r17 
	mov		r16, r17 
	jmp		delayYttreLoop
INIT: 
	clr		r16					; 0000 0000 
	out		DDRA,r16			; A0 in 
	ldi		r16, $0F			; 0000 1111 
	out		DDRB, r16			; b3-b0 out 
	ldi		r16,$FF				; 
	out		PORTA, r16			; weak pull up 
	ldi		time, 84			; set time 
	ret 
PRINT: 
	; uncomment to invert bits 
	;ldi		r16, $FF		; r16 = 1111 1111 
	;eor		letter, r16		; xor wigth 1111 1111
	out		PORTB, letter		; prints 
	ret 


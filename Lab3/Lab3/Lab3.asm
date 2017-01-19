	jmp		RESET
	jmp		EXT_INT0
	jmp		EXT_INT1
RESET:
	.def	current = r24
	.def	param = r23
	clr		current
	clr		param
	clr		r22				; xx:x0 
	clr		r21				; xx:0x
	clr		r20				; x0:xx
	clr		r19				; 0x:xx
	clr		r18				;
	clr		r16				; Clear and set stackpointer
	
	ldi		r16,HIGH(RAMEND)
	out		SPH,r16
	ldi		r16,LOW(RAMEND)
	out		SPL,r16

	clr		r16				; Configure PORTB and A
	ldi		r16,$FF
	out		DDRA,r16
	ldi		r16,$0F
	out		DDRB,r16

	ldi		ZH,HIGH(TABLE*2); Set zpointer to point to TABLE
	ldi		ZL,LOW(TABLE*2)	;

	ldi		YH,HIGH(TIME*2) ; Set Ypointer to point to TIME
	ldi		YL,LOW(TIME*2)	;

	ldi		r16,$06
	sts		$100,r16		; Leet clock 
	ldi		r16,$4F
	sts		$101,r16		
	sts		$102,r16
	ldi		r16,$07
	sts		$103,r16
			
	; Activate INT1 and INT0 
	ldi		r16, (1<<ISC01) | (0<<ISC00) | (1<<ISC11) | (0<<ISC10)
	out		MCUCR, r16

	ldi		r16,(1<<INT0) | (1<<INT1) 
	out		GICR, r16

	; Enable global interrupts
	sei
MAIN:
	jmp		MAIN		 
	;
	;	main loop, does nothing... :(
	;
INC_MOD_TEN:
	inc		param			; Increase second with one
	mov		r16,param		; Copy param to r16
	subi	r16,$0A			; Modulo 10
	ret
INC_MOD_SIX:
	inc		param			; Increase second with one
	mov		r16,param		; Copy param to r16
	subi	r16,$06			; Modulo 6
	ret
EXT_INT0:					
	push	r16				; Save current state 
	in		r16, SREG		;
	push	r16
	clr		r16
	
	add		YL,current		; Y+0, Y+1 ...
	ld		r16,Y			; Load number
	sub		YL,current		; return state
	out		PORTA,r16
	
	out		PORTB,current	; Which number to print
	inc		current			; Lastly, increase to next
	sbrc	current,2
	clr		current
	pop		r16				; Return to state
	in		SREG, r16		;
	pop		r16				;
	reti
EXT_INT1:
	push	r16				; Save current state 
	in		r16, SREG		; 
	push	r16				; 
	;Count up;

	mov		param,r22		; Push first number
	call	INC_MOD_TEN		; Increase and mod nine
	mov		r22,param		; If zero flag is cleared,  
	brne	DONE			; go to sleep
	clr		r22				;
	mov		param,r21		;
	call	INC_MOD_SIX		; 
	mov		r21,param		;
	brne	DONE			; done go back to main loop
	clr		r21				;
	mov		param,r20		; Push first number
	call	INC_MOD_TEN		; Increase and mod nine
	mov		r20,param		; If zero flag is cleared,  
	brne	DONE			; go to sleep
	clr		r20				;
	mov		param,r19		;
	call	INC_MOD_SIX		; 
	mov		r19,param		;
	brne	DONE			; done go back to main loop
	clr		r19				;
DONE:
	; Update display ;
	clr		r16
	add		ZL,r22			; move z pointer x steps
	lpm		r16,Z			; read it
	st		Y,r16			; Set xx:x0
	sub		ZL,r22			; reset z pointer

	add		ZL,r21			; move z pointer x steps
	lpm		r16,Z			; read it
	std		Y+1,r16			; Set xx:0x
	sub		ZL,r21			; reset z pointer

	add		ZL,r20			; move z pointer x steps
	lpm		r16,Z			; read it
	std		Y+2,r16			; Set x0:xx
	sub		ZL,r20			; reset z pointer

	add		ZL,r19			; move z pointer x steps
	lpm		r16,Z			; read it
	std		Y+3,r16			; Set 0x:xx
	sub		ZL,r19			; reset z pointer

	pop		r16				; Return state 
	in		r16, SREG		; 
	pop		r16				; 
	reti					; RETI

TABLE:.db		$3F,$06,$5B,$4F,$66,$6D,$7D,$07,$7F,$67
	.dseg
	.org	$100 
TIME: .byte 4
	.cseg
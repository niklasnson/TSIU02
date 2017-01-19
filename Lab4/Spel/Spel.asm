	; --- lab4_skal.asm

	.equ	VMEM_SZ     = 5		; #rows on display
	.equ	AD_CHAN_X   = 0		; ADC0=PA0, PORTA bit 0 X-led
	.equ	AD_CHAN_Y   = 1		; ADC1=PA1, PORTA bit 1 Y-led
	.equ	GAME_SPEED  = 70	; inter-run delay (millisecs)
	.equ	PRESCALE    = 7		; AD-prescaler value
	.equ	BEEP_PITCH  = 40	; Victory beep pitch
	.equ	BEEP_LENGTH = 150	; Victory beep length
	
	; ---------------------------------------
	; --- Memory layout in SRAM
	.dseg
	.org	SRAM_START
POSX:	.byte	1	; Own position
POSY:	.byte 	1
TPOSX:	.byte	1	; Target position
TPOSY:	.byte	1
LINE:	.byte	1	; Current line	
VMEM:	.byte	VMEM_SZ ; Video MEMory
SEED:	.byte	1	; Seed for Random

	; ---------------------------------------
	; --- Macros for inc/dec-rementing
	; --- a byte in SRAM
	.macro INCSRAM	; inc byte in SRAM
		lds	r16,@0
		inc	r16
		sts	@0,r16
	.endmacro

	.macro DECSRAM	; dec byte in SRAM
		lds	r16,@0
		dec	r16
		sts	@0,r16
	.endmacro

	; ---------------------------------------
	; --- Code
	.cseg
	.org 	$0
	jmp	START
	.org	INT0addr
	jmp	MUX

START:
	ldi		r16,HIGH(RAMEND)	;Stackpointer
	out		SPH,r16
	ldi		r16,LOW(RAMEND)
	out		SPL,r16

	call	HW_INIT	
	call	WARM
RUN:
	call	JOYSTICK
	call	ERASE
	call	UPDATE
	call	SHORTWAIT
	
	lds		r16,POSX
	lds		r17,TPOSX
	cp		r16,r17			; Same X?
	brne	NO_HIT			; Nope
	lds		r16,POSY
	lds		r17,TPOSY
	cp		r16,r17			; Same Y?
	brne	NO_HIT			; Nope
	ldi		r16,BEEP_LENGTH
	call	BEEP
	call	WARM
NO_HIT:
	jmp	RUN

	; ---------------------------------------
	; --- Multiplex display
	; --- Uses: r16, r17
	; --- LINE + $20
	; --- Mod result mod $A0 
MUX:	
	push	r16
	push	r17
	push	ZH
	push	ZL

	ldi		ZH,HIGH(LINE)	;Load Zpointer with Line
	ldi		ZL,LOW(LINE)

	ld		r16,Z			; Load line to r16
	ldi		r17, $10		; Adder 
	add		r16, r17 
	cpi		r16, $50		; Are we $50
	brne	MUX_NOMOD
	ldi		r16, $00		; Reset Line
MUX_NOMOD:
	out		PORTA,r16		; Setting which line to show
	st		Z,r16			; Store current line number

	ldi		ZL,LOW(VMEM)	;
	ldi		ZH,HIGH(VMEM)	;

	swap	r16				; Turn $10 to $01 etc.
	add		ZL,r16
	ld		r16,Z			; Setting which line to output
	out		PORTB,r16

	; increase seed
	INCSRAM SEED

	pop		ZL
	pop		ZH
	pop		r17
	pop		r16
	reti
		
	; ---------------------------------------
	; --- JOYSTICK Sense stick and update POSX, POSY
	; --- Uses:
JOYSTICK:	

;;*** 	skriv kod som ökar eller minskar POSX beroende 	***
;;*** 	på insignalen från A/D-omvandlaren i X-led...	***

	; Sätt igång omvandlingen
	push	r16
	; Setup ADC to listen on PINA0
	clr		r16
	ldi		r16, (1<<REFS1) | (1<<REFS0); | (0<<ADLAR) ; 1100000
	out		ADMUX,r16
	; Setup ADC to start conversion
	clr		r16
	; Enabling,Starting conversion and Prescaling 128
	ldi		r16, (1<<ADEN) | (1<<ADSC) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)
	out		ADCSRA,r16

LISTEN1:
	sbic	ADCSRA,6	; Listen for conversion done
	jmp		LISTEN1

	in		r16, ADCH	; Get most significant bits
	andi	r16, $03	; and 0000 0011 Clean

	cpi		r16, $03	; is it 0000 0011 ?
	breq	JOYINCX
	cpi		r16, $00	; is it 0000 0000 ?
	breq	JOYDECX
	jmp		JOYREADY

JOYINCX:
	INCSRAM POSX
	jmp JOYREADY
JOYDECX:
	DECSRAM	POSX
JOYREADY:
	; Setup ADC to listen on PINA1
	clr		r16
	ldi		r16, (1<<REFS1) | (1<<REFS0) | (1<<MUX0) ; 1100001
	out		ADMUX,r16
	; Setup ADC to start conversion
	clr		r16
	; Enabling,Starting conversion and Prescaling 128
	ldi		r16, (1<<ADEN) | (1<<ADSC) | (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0)
	out		ADCSRA,r16

LISTEN2:
	sbic	ADCSRA,6	; Listen for conversion done
	jmp		LISTEN2
	
	in		r16, ADCH	; Get most significant bits
	andi	r16, $03	; clean

	cpi		r16, $03	; is it 0000 0011 ?
	breq	JOYINCY
	cpi		r16, $00	; is it 0000 0000 ?
	breq	JOYDECY
	jmp		JOY_LIM
JOYINCY:
	lds r20, POSY
	INCSRAM POSY
	lds r16, POSY
	jmp		JOY_LIM
JOYDECY:
	DECSRAM	POSY

JOY_LIM:
	call	LIMITS		; don't fall off world!
	pop		r16
	ret

	; ---------------------------------------
	; --- LIMITS Limit POSX,POSY coordinates	
	; --- Uses: r16,r17
LIMITS:
	lds		r16,POSX	; variable
	ldi		r17,7		; upper limit+1
	call	POS_LIM		; actual work
	sts		POSX,r16
	lds		r16,POSY	; variable
	ldi		r17,5		; upper limit+1
	call	POS_LIM		; actual work
	sts		POSY,r16
	ret

POS_LIM:
	ori		r16,0		; negative?
	brmi	POS_LESS	; POSX neg => add 1
	cp		r16,r17		; past edge
	brne	POS_OK
	subi	r16,2
POS_LESS:
	inc	r16	
POS_OK:
	ret

	; ---------------------------------------
	; --- UPDATE VMEM
	; --- with POSX/Y, TPOSX/Y
	; --- Uses: r16, r17, Z
UPDATE:	
	clr		ZH 
	ldi		ZL,LOW(POSX)
	call 	SETPOS
	clr		ZH
	ldi		ZL,LOW(TPOSX)
	call	SETPOS
	ret

	; --- SETPOS Set bit pattern of r16 into *Z
	; --- Uses: r16, r17, Z
	; --- 1st call Z points to POSX at entry and POSY at exit
	; --- 2nd call Z points to TPOSX at entry and TPOSY at exit
SETPOS:
	ld		r17,Z+  	; r17=POSX
	call	SETBIT	; r16=bitpattern for VMEM+POSY
	ld		r17,Z		; r17=POSY Z to POSY
	ldi		ZL,LOW(VMEM)
	add		ZL,r17		; Z=VMEM+POSY, ZL=VMEM+0..4
	ld		r17,Z		; current line in VMEM
	or		r17,r16		; OR on place
	st		Z,r17		; put back into VMEM
	ret
	
	; --- SETBIT Set bit r17 on r16
	; --- Uses: r16, r17
SETBIT:
	ldi		r16,$01		; bit to shift
SETBIT_LOOP:
	dec 	r17			
	brmi 	SETBIT_END	; til done
	lsl 	r16		; shift
	jmp 	SETBIT_LOOP
SETBIT_END:
	ret

	; ---------------------------------------
	; --- Hardware init
	; --- Uses:
HW_INIT:

;;*** 	Konfigurera hårdvara och MUX-avbrott enligt ditt elektriska schema. Konfigurera	flanktriggat avbrott på INT0 (PD2).***

	ldi		r16, (1<<ISC01) | (0<<ISC00) | (1<<ISC11) | (0<<ISC10)	; Set up INT0 && INT1
	out		MCUCR, r16

	ldi		r16,(1<<INT0) | (1<<INT1)
	out		GICR, r16

	ldi		r16,$FF			; setup PORTB
	out		DDRB,r16	
	ldi		r16,$F0			; setup PORTA
	out		DDRA,r16

	ldi		r16,$00			; Clear PORTA & PORTB
	out		PORTA,r16
	out		PORTB,r16

	ldi		ZH,HIGH(LINE)	; Load Zpointer with Line
	ldi		ZL,LOW(LINE)

	st		Z,r16			; Reset line number
	sei						; display on
	ret

	; ---------------------------------------
	; --- WARM start. Set up a new game
	; --- Uses:
WARM:

;;*** 	Sätt startposition (POSX,POSY)=(0,2)		***
	push	ZH
	push	ZL
	push	r16

	ldi		ZL,LOW(POSX)
	ldi		ZH,HIGH(POSX)

	ldi		r16,$00		; X HARDCODED BITCHES
	st		Z+,r16		;	
	ldi		r16,$02		; Y
	st		Z+,r16		; 

	push	r0			; Pushing random registers
	push	r0			; Pushing random registers 
	call	RANDOM		; RANDOM returns TPOSX, TPOSY on stack
	
	pop		r16			; Get TPOSX
	st		Z+,r16		; SET TPOSX
	pop		r16			; GET TPOSY
	st		Z,r16		; SET TPOSY	

	call	ERASE

	pop		r16
	pop		ZL
	pop		ZH
	ret

	; ---------------------------------------
	; --- RANDOM generate TPOSX, TPOSY
	; --- in variables passed on stack.
	; --- Usage as:
	; ---	push r0 
	; ---	push r0 
	; ---	call RANDOM
	; ---	pop TPOSX 
	; ---	pop TPOSY
	; --- Uses: r16
RANDOM:
	push	r16
	push	r17
	push	ZH
	push	ZL

	in		r16,SPH		; COPY the stackpointer to Z pointer
	mov		ZH,r16
	in		r16,SPL
	mov		ZL,r16

	lds		r16,SEED	; Get the seed	

	ldi		r17,$07		;
	and		r17,r16		; r17 now holds TPOSX
	cpi		r17,$05		; Mod 5
	brmi	RIN			; branch if minus 
	subi	r17,$05		; minus bithces	
RIN:inc		r17 		; Plus 2
	inc		r17			; Get out of player bound
	std		Z+7,r17		; Return TPOSX to stack

	ldi		r17,$38		;
	and		r17,r16		; r17 now holds TPOSY
	lsr		r17			; 000YYY00
	lsr		r17			; 0000YYY0
	lsr		r17			; 00000YYY
	cpi		r17,$05		; Mod 5
	brmi	RDO			; branch if minus 
	subi	r17,$05		; 	
RDO:std		Z+8,r17		; Return TPOSY to stack
	pop		ZL
	pop		ZH
	pop		r17
	pop		r16
	ret

	; ---------------------------------------
	; --- ERASE videomemory
	; --- Clears VMEM..VMEM+4
	; --- Uses:
ERASE:
	push ZL
	push ZH
	push r16

	ldi	r16,$00

	ldi ZL,LOW(VMEM)
	ldi ZH,HIGH(VMEM)

	st Z+,r16
	st Z+,r16
	st Z+,r16
	st Z+,r16
	st Z+,r16

	pop r16
	pop ZH
	pop ZL

	ret

	; ---------------------------------------
	; --- BEEP(r16) r16 half cycles of BEEP-PITCH
	; --- Uses:
BEEP:	
	; r16 har beep_length
	ldi		r18, BEEP_PITCH
	ldi		r16, BEEP_LENGTH
BSTART:
	sbi		PORTB,7
	call	SMALLDELAY
	cbi		PORTB,7		
	call	SMALLDELAY
	dec		r16
	brne	BSTART

	ldi		r18, 20
	ldi		r16, BEEP_LENGTH
BSTART2:
	sbi		PORTB,7
	call	SMALLDELAY
	cbi		PORTB,7		
	call	SMALLDELAY

	dec		r16
	brne	BSTART2
	
	ldi		r18, 10
	ldi		r16, BEEP_LENGTH
BSTART3:
	sbi		PORTB,7
	call	SMALLDELAY
	cbi		PORTB,7		
	call	SMALLDELAY

	dec		r16
	brne	BSTART3

	ret

SMALLDELAY:
	push	r16

	mov		r16, r18
SD1:ldi		r17,$FF
SD2:dec		r17
	brne	SD2
	dec		r16
	brne	SD1

	pop		r16
	ret
;;;;;;;;
	; ---------------------------------------
	; --- SHORTWAIT(r16)  loops 256
	; --- Uses: r16
SHORTWAIT:
	push	r16
	push	ZH
	push	ZL

	ldi		ZH,HIGH(GAME_SPEED)
	ldi		ZL,LOW(GAME_SPEED)

	ld		r16,Z

SWA:call	ONEMSWAIT
	dec		r16
	brne	SWA
	
	pop		ZL
	pop		ZH
	pop		r16
	ret

ONEMSWAIT:
	push	r16
	push	r17
	
	ldi		r16,21
DYT:ldi		r17,$FF
DIT:dec		r17
	brne	DIT
	dec		r16
	brne	DYT
	
	pop		r17
	pop		r16
	ret
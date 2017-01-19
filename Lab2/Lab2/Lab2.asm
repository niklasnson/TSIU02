/*
 * Lab2.asm
 *
 *  Created: 11/18/2016 9:33:16 AM
 *   Author: nikni292
 */ 
		.def	zero = r22			; zero, weee
		.def	space = r21			; space
		.def	time = r20			; The delay
		.def	char = r19			; Current char
		.def	charMorse = r18		; current char in morse
		.def	freq = r17			; 
		ldi		r16,HIGH(RAMEND)
		out		SPH,r16
		ldi		r16,LOW(RAMEND)
		out		SPL,r16
DONE:	call	INIT
		call	BETWEEN_WORDS		;
MORSE:
		call	GET_CHAR			; Get one character
		cpi		char,$00			; Are we done?
		breq	DONE				;
		call	SEND_CHAR			; Send Character
		jmp		MORSE				; Main Loop
INIT:
		ldi		zero,$00			; oh lord..
		ldi		space,$20			; 
		ldi		time,$FF			; Time delay for 1
		ldi		freq,$FF			; Sound frequence
		clr		char				;
		clr		charMorse			;
		ldi		ZH,HIGH(STRING*2)	; Load string into
		ldi		ZL,LOW(STRING*2)	; Z pointer
		ldi		r16,$FF				;
		out		DDRB,r16			;
		ret
GET_CHAR:
		lpm		char,Z+				; r16 = Z++
		ret
SEND_CHAR:
		call	LOOKUP				; Translate char to binary morse
		cpse	char,space			; is it a space?
		call	BEEPCHAR			; Is translated! Let's get beeping!
		cpse	charMorse,zero		; is it zero?
		call	BETWEEN_WORDS		; silence!
		ret
LOOKUP:
		push	ZH					; Save letter position
		push	ZL					; to stack
		ldi		ZH,HIGH(DBMORSE*2)	; Load DB into
		ldi		ZL,LOW(DBMORSE*2)	; Z pointer
		call	IN_RANGE			; Get the true char
		mov		r16,char			; copy into working register
		subi	r16,$20				; get characters into 0,1,2,3,4...
XLOOP:	cpi		r16,$00				;
		breq	XDONE				;
		dec		r16					;
		adiw	ZH:ZL,1				; Z++
		jmp		XLOOP
XDONE:
		lpm		charMorse,Z			; Get morse
		pop		ZL					; pop back string
		pop		ZH					; 
		ret

BEEPCHAR:
		lsl		charMorse			; 0110 0000 -> 0 C
		brcc	BEEP_SHORT			; Bit == 0, pip
		cpi		charMorse,$00		; is it done?
		brne	BEEP_LONG			; Was not stop bit, beep long
BDONE:	
		cpi		charMorse,$00		; is it done?
		brne	BEEPCHAR			; nope, beep char again
		call	NOBEEP				; 
		call	NOBEEP				; Two silences for end of character
		ret
BEEP_SHORT:
		;; Beep 1 beep ;;
		call	BEEP				; Beep 1 t
		call	NOBEEP				; silence 1 t
		jmp		BDONE
BEEP_LONG:
		;; Beep 3 beeps ;;
		call	BEEP				; Beep 1 t
		call	BEEP				; Beep 2 t
		call	BEEP				; Beep 3 t
		call	NOBEEP				; silence 1 t
		jmp		BDONE				;
BEEP:
		;; One beep ;;
		mov		r16,time			; Load time
BON:								;
		sbi		PORTB,7				; Send 1
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
BOFF:	
		cbi		PORTB,7				; Send 0
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		dec		r16					; Big delay, time
		brne	BON					; Do one turn again if not done
		ret

NOBEEP:
		;; One beep ;;
		mov		r16,time			; Load time
NBON:								;
		cbi		PORTB,7				; Send 1
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
NBOFF:	
		cbi		PORTB,7				; Send 0
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		call	DELAY_FREQ			; delay according to freq
		dec		r16					; Big delay, time
		brne	NBON					; Do one turn again if not done
		ret

DELAY_FREQ:
		;; Delays for 1 * freq ;;
		mov		r28,freq			; Load frequency		
FDELAY:	dec		r28					; Small inner delay loop
		brne	FDELAY				;
		ret							;


DELAY:
		;; Delay 1 t ;;
		mov		r16,time			; load time
DELAY_1:							;
		ldi		r28,$FF				;
DELAY_2:							;
		dec		r28					;
		brne	DELAY_2				;
		dec		r16					;
		brne	DELAY_1				;
		ret

IN_RANGE:
		;; Function checks if char is in our table ;;
		mov		r16,char			;
		subi	r16,$20				; Subtract the Offset
		brmi	OUTOFBOUND			;
		mov		r16,char			; Reset
		subi	r16,$5E				; Is in Table range (5D+1)
		brpl	OUTOFBOUND			;
		ret							; All is well
OUTOFBOUND:
		ldi		char,$20			; Set to space
		ret	
BETWEEN_WORDS:
		call NOBEEP
		call NOBEEP
		call NOBEEP
		call NOBEEP
		call NOBEEP
		call NOBEEP
		call NOBEEP
		ret































































STRING:	.db		"SOS HELP", $00			;
DBMORSE:.db		$01, $01, $4A, $01, $01, $01, $01, $7A, $B4, $B6, $01, $01, $CE, $86, $56 ,$94, $FC, $7C, $3C, $1C, $0C, $04, $84, $C4, $E4, $F4, $E2, $AA, $01, $8C, $01, $32, $01, $60, $88, $A8, $90, $40, $28, $D0, $8, $20, $78, $B0, $48, $E0, $A0, $F0, $68, $D8, $50, $10, $C0, $30, $18, $70, $98, $B8, $C8, $58, $E8, $6C
	
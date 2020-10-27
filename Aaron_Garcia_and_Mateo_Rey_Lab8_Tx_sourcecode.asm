;***********************************************************
;*
;*	Mateo_Rey-Rosa_And_Aaron_Garcia_Lab8_Tx_SourceCode.asm
;*
;*	This program acts as a remote to a corresponding robot
;*	that will execute the given commands transmitted using 
;*	USART1. The LED  on the remote will momentarily show 
;*	the button that was pressed.
;*
;***********************************************************
;*
;*	 Author: Aaron Garcia and Mateo Rey-Rosa
;*	   Date: 11/20/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	waitcnt = r23						; Wait Loop Counter
.def	ilcnt = r24							; Inner Loop Counter
.def	olcnt = r25							; Outer Loop Counter
.def	inter = r17							; Used to store Pin configuration for each cycle
.equ	EngEnR = 4							; Right Engine Enable Bit
.equ	EngEnL = 7							; Left Engine Enable Bit
.equ	EngDirR = 5							; Right Engine Direction Bit
.equ	EngDirL = 6							; Left Engine Direction Bit

; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	Freeze =  (0b11111000)							; Freeze action code
.equ    BotId  =  (0b00011000)						    ; Remote Id
.equ	WTime = 30										; Time to wait in wait loop



;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt


.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, low(RAMEND)
		out		SPL, mpr				; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr				; Load SPH with high byte of RAMEND

	;I/O Ports

	; Initialize Port B for output
		ldi		mpr, $FF				; Set Port B Data Direction Register
		out		DDRB, mpr				; for output
		ldi		mpr, $00				; Initialize Port B Data Register
		out		PORTB, mpr				; so all Port B outputs are low

	; Set all buttons except for 3:2 for LED output and set pin 2 for USART1 transmit
		ldi		mpr, 0b00000100			; Set Port D Data Direction Register
		out		DDRD, mpr				; for input
		ldi		mpr, 0b11111111			; Initialize Port D Data Register
		out		PORTD, mpr				; so all Port D inputs are Tri-State

	; Set double the transmission speed
		ldi		mpr, (1<<U2X1)			; double the transmission speed
		sts		UCSR1A, mpr				; Write double transmission bit to UCS1A

		; set async mode
		; Transmitted Data Changed on Rising Edge and Received Data Sampled Falling edge
		; Disable parity bit
		; 2 stop bits
		; Configure 8 bit character size
		ldi		mpr, (0<<UMSEL1)|(0<<UCPOL1) |(0<<UPM10)|(0<<UPM11)|(1<<USBS1)|(1<<UCSZ11)|(1<<UCSZ10)
		sts		UCSR1C, mpr				; Write to UCS1RC

		; Enable the USART1 trnsmitter
		ldi		mpr, (1<<TXEN1)			; Enable transmit bit
		sts UCSR1B, mpr					; Write to the UCS1B

		; Set baud rate to 2400 (16^6/(8*2400)) - 1 = 832
		ldi		mpr, $03				; high of 832
		sts		UBRR1H, mpr				; write to the high byte of UBR1H

		ldi		mpr, $40				; low of 832
		sts		UBRR1L, mpr				; write to the low byte of UBR1L

	
		

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in	inter, PIND				; Get input from Port D
		ldi mpr, 0					; Set default to all LEDs off
		out PORTB, mpr				; Write to PORTB

TryBackwards:
		cpi		inter, (0b01111111)	; Check for pin 7 push
		brne	TryFowards			; Continue with next check
		rcall	MoveBack			; call move back
		rjmp	MAIN				; jump to main
TryFowards: 
		cpi inter, 0b10111111		; Check for pin 6 push
		brne TryLeft				; continue with next check
		rcall MoveForward			; call move forward
		rjmp Main					; jump to main
TryLeft:
		cpi inter, 0b11101111		; check for pin 4 push
		brne TryRight				; continue with next check
		rcall TurnLeft				; call turn left
		rjmp Main					; return to main
TryRight:
		cpi inter, 0b11011111		; check for pin 5 push
		brne TryHalt				; continue with next check
		rcall TurnRight				; call turn right
		rjmp Main					; jump to main
TryHalt:	
		cpi inter, 0b11111101		; check for pin 1 push
		brne TryFreeze				; continue with next check
		rcall HaltFunc				; call halt function
		rjmp Main					; jump to main
TryFreeze:
		cpi inter, 0b11111110		; check for pin 0 push
		brne MAIN					; branch if not equal to main
		rcall FreezeFunc			; call the freeze function
		rjmp Main					; jump to main

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: LEFFromMpr
; Desc: Outputs the configuration in mpr to PORTB, which
;       configures the LEDs
;-----------------------------------------------------------
LEDFromMpr:     
	out     PORTB, mpr				; Write to PORTB from mpr
	ret								; return
;-----------------------------------------------------------
; Func: TransmitFromMpr
; Desc: Outputs the configuration in mpr to UDR1, essentially
;		sending the contents of UDR1 to transmit
;-----------------------------------------------------------
TransmitFromMpr:
	sts UDR1, mpr						; Send the information via UDR1
	ret									; Return

;-----------------------------------------------------------
; Func: TransmitBotId
; Desc: Loads the BotId into mpr and then calls the transmit
;		function to send the botId
;-----------------------------------------------------------
TransmitBotId:
	ldi mpr, BotId						; Load the bot Id into mpr
	rcall TransmitFromMpr				; Send the information via UDR1
	ret

;-----------------------------------------------------------
; Func: FreezeFunc
; Desc: Uses mpr to load LED config, BotId, Freeze cmd and calls 
;		transmit function and waits
;-----------------------------------------------------------
FreezeFunc:
	ldi     mpr, (0b00000001)			; Configure 1st LED
	rcall LEDFromMpr					; Turn on 1st LED
	rcall TransmitBotId					; Transmit the BotID
	ldi mpr,	Freeze					; Load the Freeze bit action command
	rcall TransmitFromMpr				; Transmit the freeze action

	ldi		waitcnt, WTime				; Wait for 1 second
	rcall	WaitFunc					; Call wait function
	ret									; return

;-----------------------------------------------------------
; Func: HaltFunc
; Desc: Uses mpr to load LED config, BotId, Halt cmd cmd and calls 
;		transmit function and waits
;-----------------------------------------------------------
HaltFunc:
	ldi     mpr, (0b00000010)			; Configure 2nd LED
	rcall LEDFromMpr					; Turn on 2nd LED
	rcall TransmitBotId					; Transmit the BotID
	ldi mpr,Halt						; Load the Halt bit action command
	rcall TransmitFromMpr				; Transmit the halt action
	ldi		waitcnt, WTime				; Wait for 1 second
	rcall	WaitFunc					; Call wait function
	ret									; Return

;----------------------------------------------------------
; Func: TurnLeft
; Desc: Uses mpr to load LED config, BotId, turnleft cmd and calls 
;		transmit function and waits
;-----------------------------------------------------------
TurnLeft:
	ldi     mpr, (0b00010000)			; Configure 5th LED
	rcall LEDFromMpr					; Turn on 5th LED
	rcall TransmitBotId					; Transmit the BotID
	ldi mpr,TurnL						; Load the Turn left bit action command
	rcall TransmitFromMpr				; Transmit the Turn left action
	ldi		waitcnt, WTime				; Wait for 1 second
	rcall	WaitFunc					; Call wait function
	ret									; return

;-----------------------------------------------------------
; Func: TurnRight
; Desc: Uses mpr to load LED config, BotId, turn right cmd and calls 
;		transmit function and waits
;-----------------------------------------------------------
TurnRight:
	ldi     mpr, (0b00100000)			; Configure 6th LED
	rcall LEDFromMpr					; Turn on 6th LED
	rcall TransmitBotId					; Transmit BotId
	ldi mpr,TurnR						; Load the Turn right bit action command
	rcall TransmitFromMpr				; transmit the turn right command
	ldi		waitcnt, WTime				; Wait for 1 second
	rcall	WaitFunc					; Call wait function
	ret									; return

;-----------------------------------------------------------
; Func: MoveForward
; Desc: Uses mpr to load LED config, BotId, move forward cmd and calls 
;		transmit function and waits
;-----------------------------------------------------------
MoveForward:
	ldi     mpr, (0b01000000)			; Configure the 6th LED
	rcall LEDFromMpr					; Turn on the 6th LED
	rcall TransmitBotId					; Transmit BotId
	ldi mpr,MovFwd						; Load the move forward bit action command
	rcall TransmitFromMpr				; Transmit the move forward command
	ldi		waitcnt, WTime				; Wait for 1 second
	rcall	WaitFunc					; Call wait function
	ret									; return
	
;-----------------------------------------------------------
; Func: MoveBack
; Desc: Uses mpr to load LED config, BotId, move back cmd and calls 
;		transmit function and waits
;-----------------------------------------------------------
MoveBack:
	ldi     mpr, (0b10000000)			; Configure the 7th LED
	rcall LEDFromMpr					; Turn on the 7th LED
	rcall TransmitBotId					; Transmit BotID
	ldi mpr,MovBck						; Load the move back cmd
	rcall TransmitFromMpr				; Transmit the move forward command
	ldi		waitcnt, WTime				; Wait for 1 second
	rcall	WaitFunc					; Call wait function
	ret									; return

;-----------------------------------------------------------
; Func: WaitFunc
; Desc: A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;-----------------------------------------------------------
WaitFunc:							

		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt			; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt			; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt			; Restore olcnt register
		pop		ilcnt			; Restore ilcnt register
		pop		waitcnt			; Restore wait register
		ret						; Return from subroutine



;***********************************************************
;*	Stored Program Data
;***********************************************************

;***********************************************************
;*	Additional Program Includes
;***********************************************************
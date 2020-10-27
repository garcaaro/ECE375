;***********************************************************
;*
;*	Aaron_Garcia_lab7_sourcecode.asm
;*
;*	Lab 7 source code assembly file
;*
;*	This is the skeleton file for Lab 7 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Aaron Garcia
;*	   Date: 11/19/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	counter = r17
.def	speed = r0				; Holds speed value
.def	waitcnt = r20			; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter

.equ	WTime = 10				; Time to wait in wait loop
.equ	EngEnR = 4				; right Engine Enable Bit
.equ	EngEnL = 7				; left Engine Enable Bit
.equ	EngDirR = 5				; right Engine Direction Bit
.equ	EngDirL = 6				; left Engine Direction Bit

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed
.org	$0002
		rjmp	maxSpeed
		RETI

.org	$0004
		rjmp	addSpeed
		RETI

.org	$0006
		rjmp	subSpeed
		RETI

.org	$0008
		rjmp	minSpeed
		RETI

.org	$0046					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer

		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND
		
		; Configure I/O ports

			; Initialize Port B for output
		ldi		mpr, $FF		; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are low			

			; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State

		; Configure External Interrupts, if needed

		ldi		mpr, $AA
		sts		EICRA, mpr		; Load interrupt modes 
		ldi		mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)|(1<<INT3)
		out		EIMSK, mpr		; Enable external interrupts 0-3

		; Configure 8-bit Timer/Counters

		ldi		mpr, $69
		sts		0x53, mpr		; Store correct settings at TCCR0 and TCCR2
		sts		0x45, mpr
		ldi		mpr, $00
		sts		OCR0, mpr		; Load initial compare value of 0 to both timers
		sts		OCR2, mpr

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL)

		sbi		PORTB, EngDirR
		sbi		PORTB, EngDirL

		; Set initial speed, display on Port B pins 3:0

		clr		speed			; Set our counter variables to zero
		clr		counter
		rcall	updateSpeed		; Verifys correct outputs are written

		; Enable global interrupts (if any are used)
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		rjmp	MAIN			; return to top of MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	addSpeed
; Desc:	Adds 17 to the speed register
;-----------------------------------------------------------
addSpeed:	
		mov		mpr, speed		
		cpi		mpr, $FF		; Checks if value stored in speed register is 255
		breq	atMax			; If it is, no operation is performed
		ldi		mpr, $11
		add		speed, mpr		; If not, counter is incremented and speed is increased by 17
		inc		counter
		rcall	updateSpeed
atMax:
		rcall	Wait			; Wait function to prevent bounces from registering as multiple presses
		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret

;-----------------------------------------------------------
; Func:	subSpeed
; Desc:	Subtracts 17 from the speed register
;-----------------------------------------------------------
subSpeed:	
		mov		mpr, speed		; Check if speed is equal to zero
		cpi		mpr, $00
		breq	atMin			; If it is zero, then move to end of function without performing an operation
		mov		mpr, speed
		subi	mpr, $11		; If not, subtract 17 from speed and decrement counter
		mov		speed, mpr
		dec		counter
		rcall	updateSpeed		; Updates visual interface and pwm output
atMin:
		rcall	Wait
		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret

;-----------------------------------------------------------
; Func:	maxSpeed
; Desc:	Sets speed register to 255
;-----------------------------------------------------------
maxSpeed:	
		ldi		mpr, $FF		; Stores 255 to speed and 15 to counter
		mov		speed, mpr
		ldi		counter, $0F
		rcall	updateSpeed		; Updates visual interface and pwm output
		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret

;-----------------------------------------------------------
; Func:	minSpeed
; Desc:	Sets speed register to 0
;-----------------------------------------------------------
minSpeed:	
		ldi		mpr, $00
		mov		speed, mpr
		ldi		counter, $00
		rcall	updateSpeed		; Updates visual interface and pwm output
		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret

;-----------------------------------------------------------
; Func:	updateSpeed
; Desc:	Updates the speed shown on PORTB 3:0 and the pwm signals at 4, 7
;-----------------------------------------------------------
updateSpeed:
		out		OCR0, speed		; Loads new values into output comparators
		out		OCR2, speed
		in		mpr, PORTB		; Stores the current output values
		cbr		mpr, $0F		; Deletes the last 4 bits
		or		mpr, counter	; Performs logical or between modified port number and the value stored in counter
		out		PORTB, mpr		; Stores new output value
		ret
;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine
;***********************************************************
;*	Stored Program Data
;***********************************************************
		; This program does not need any stored data

;***********************************************************
;*	Additional Program Includes
;***********************************************************
		; There are no additional file includes for this program
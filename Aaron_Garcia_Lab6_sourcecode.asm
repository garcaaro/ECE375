;***********************************************************
;*
;*	 Author: Aaron Garcia
;*	   Date: 11/12/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	waitcnt = r23			; Wait Loop Counter
.def	ilcnt = r24				; Inner Loop Counter
.def	olcnt = r25				; Outer Loop Counter 
.def	leftcount = r3			; Holder for amount of left Wisker strikes
.def	rightcount = r4			; Holder for amount of right Wisker strikes
.def	counter = r2			; Counter for reading strings

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
.equ	WTime = 100				; Time to wait in wait loop
.equ	leftlength = 6			; Length of left string 
.equ	rightlength = 7			; Length of right string
.equ	asciioffset = 48

.equ	MovFwd = (1<<EngDirR|1<<EngDirL); Move Forward Command
.equ	MovBck = $00			; Move Backward Command
.equ	TurnR = (1<<EngDirL)	; Turn Right Command
.equ	TurnL = (1<<EngDirR)	; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)	; Halt Command

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

		; Set up interrupt vectors for any interrupts being used

.org	$0002
		rjmp	Hitright
		RETI

.org	$0004
		rjmp	Hitleft
		RETI

.org	$0006
		rjmp	Clrright
		RETI

.org	$0008
		rjmp	Clrleft
		RETI

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; Initialize Stack Pointer

		ldi		mpr, low(RAMEND)
		out		SPL, mpr		; Load SPL with low byte of RAMEND
		ldi		mpr, high(RAMEND)
		out		SPH, mpr		; Load SPH with high byte of RAMEND
		
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

		; Initialize hit count holders to zero

		clr		leftcount		; Set left counter to zero
		clr		rightcount		; Set right counter to zero

		; Initialize LCD display

		rcall	LCDInit			; Initialize lcd display
		rcall	Updatescreen	; Set initial screen condition

		; Initialize external interrupts
		; Set the Interrupt Sense Control to falling edge

		ldi		mpr, $AA
		sts		EICRA, mpr		; Load interrupt modes 

		; Configure the External Interrupt Mask

		ldi		mpr, (1<<INT0)|(1<<INT1)|(1<<INT2)|(1<<INT3)
		out		EIMSK, mpr		; Enable interrupts 1-4

		; Turn on interrupts
		
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program
		ldi		mpr, MovFwd		; Load FWD command
		out		PORTB, mpr		; Send to output
		rjmp	MAIN			; Create an infinite while loop to signify the 
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************


;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	Handles functionality of the TekBot when the right whisker
;		is triggered.
;----------------------------------------------------------------
HitRight:
		rcall	addright

		; Move Backwards for a second
		ldi		mpr, MovBck		; Load Move Backward command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Waitt			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL		; Load Turn Left Command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Waitt			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd		; Load Move Forward command
		out		PORTB, mpr		; Send command to port

		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret						; Return from subroutine

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	Handles functionality of the TekBot when the left whisker
;		is triggered.
;----------------------------------------------------------------
HitLeft:	
		rcall	Addleft			; Increment left counter

		; Move Backwards for a second
		ldi		mpr, MovBck		; Load Move Backward command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Waitt			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR		; Load Turn Left Command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Waitt			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd		; Load Move Forward command
		out		PORTB, mpr		; Send command to port

		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret						; Return from subroutine

;----------------------------------------------------------------
; Sub:	Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Waitt:
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

;-----------------------------------------------------------
; Func: Addright
; Desc:  Adds 1 to the right counter and reprints the LCD
;-----------------------------------------------------------
Addright:
		inc		rightcount		; Increment right hit counter
		rcall	Updatescreen	; Update screen for new value
		ret

;-----------------------------------------------------------
; Func: Addleft
; Desc: Adds 1 to the left counter and reprints the LCD
;-----------------------------------------------------------
Addleft:
		inc		leftcount		; Increment left hit counter
		rcall	Updatescreen	; Update screen for new value
		ret

;-----------------------------------------------------------
; Func: Clrright
; Desc: Clears the right counter and reprints the LCD
;-----------------------------------------------------------
Clrright:
		clr		rightcount		; Set the right count to zero
		rcall	Updatescreen	; Update screen for new value
		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret

;-----------------------------------------------------------
; Func: Clrleft
; Desc: Clears the left counter and reprints the LCD
;-----------------------------------------------------------
Clrleft:
		clr		leftcount		; Set the left count to zero
		rcall	Updatescreen	; Update screen for new value
		ldi		mpr, $FF		; Store FF in mpr
		out		EIFR, mpr		; Write FF to EIFR to clear queued interrupts
		sei
		ret

;-----------------------------------------------------------
; Func: Updatescreen
; Desc: Clears current screen, and reprints current values of counters
;-----------------------------------------------------------
Updatescreen:
		rcall	LCDClr			;clear anything currently on the screen	
		ldi		ZH, high(STRING1_BEG<<1); Initialize z pointer to address of first letter in string1 
		ldi		ZL, low(STRING1_BEG<<1)
		ldi		YH, high(LCDLn1Addr)	; Initialize y pointer to address of first line of LCD
		ldi		YL, low(LCDLn1Addr)
		ldi		mpr, leftlength
		mov		counter, mpr	; Initialize counter to length of first string
LINE1:
		lpm		mpr, Z+			; Grab ascii value of next character from address pointed to by z, move z to address of next character
		st		Y+, mpr			; Store next ascii character value at the address of that bit of the display, move to next display bit
		dec		counter			; Decrement remaining string lenght counter
		brne	LINE1			; Loop if entire string has not been passed in
		mov		mpr, leftcount	; Move left count into a temporary register to add ascii offset without affecting the count
		ldi		r23, $30		; Store ascii offset in another temporary register
		add		mpr, r23		; Add ascii offset to x register so numbers are printed correctly
		st		Y, mpr			; Stores offset number to last screen address for line 1
		ldi		ZH, high(STRING2_BEG<<1); Initialize z pointer to address of first letter in string2 
		ldi		ZL, low(STRING2_BEG<<1)
		ldi		YH, high(LCDLn2Addr)	; Initialize y pointer to address of second line of LCD
		ldi		YL, low(LCDLn2Addr)
		ldi		mpr, rightlength
		mov		counter, mpr	; Initialize counter to length of second string
LINE2:
		lpm		mpr, Z+			; Grab ascii value of next character from address pointed to by z, move z to address of next character
		st		Y+, mpr			; Store next ascii character value at the address of that bit of the display, move to next display bit
		dec		counter			; Decrement remaining string lenght counter
		brne	LINE2			; Loop if entire string has not been passed in
		mov		mpr, rightcount ; Move left count into a temporary register to add ascii offset without affecting the count
		ldi		r23, $30		; Store ascii offset in another temporary register
		add		mpr, r23		; Add ascii offset to x register so numbers are printed correctly
		st		Y, mpr			; Stores offset number to last screen address for line 1
		rcall LCDWrite			; Writes new values to LCD
		ret

;***********************************************************
;*	Stored Program Data
;***********************************************************

STRING1_BEG:
.DB		"Left: "

STRING2_BEG:
.DB		"Right: "	

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"

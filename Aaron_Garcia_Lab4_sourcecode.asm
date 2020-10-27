;***********************************************************
;*
;*	main.asm
;*
;*	Runs lab4 program on ATMega128
;*
;*	This is the skeleton file for Lab 4 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Aaron Garcia
;*	   Date: 10/30/2019
;*
;***********************************************************

.include "m128def.inc"
  ; include definition file


;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register is
								; required for LCD Driver

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp INIT				; Reset interrupt

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; Initialize Stack Pointer
		ldi		mpr, low(RAMEND)
		out		SPL, mpr        
		ldi		mpr, high(RAMEND)
		out		SPH, mpr  ; use multipurpose register to load the low and high bits of the stack pointer

		rcall LCDInit			; initialize lcd display
		rcall LCDClr			; clear lcd display in case it is not done in initialization

		; Initialize Port D for input
		ldi		mpr, $00		; Set Port D Data Direction Register
		out		DDRD, mpr		; for input
		ldi		mpr, $FF		; Initialize Port D Data Register
		out		PORTD, mpr		; so all Port D inputs are Tri-State


		; Port D initialization code snippet borrowed from LAB1 example code

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:	
				
		in		mpr, PIND       ; stores pind input to multipurpose register
		cpi		mpr, 0b01111111	; checks if reset button has been pressed
		brne	NEXT1			; if not, continue to NEXT1
		rcall	LCDClr			; if so, call lcdclear function
		rjmp	MAIN			; and return back to top of main
NEXT1:	cpi		mpr, 0b11111110 ; checks if button 0 has been pressed
		brne	NEXT2			; if not, continue to NEXT2
		rcall	PRINT12			; if so, run PRINT12 function
		rjmp	MAIN			; and return back to top of main
NEXt2:	cpi		mpr, 0b11111101 ; checks if button 1 has been pressed
		brne	MAIN			; if not, returns to top of main
		rcall	PRINT21			; if so, runs PRINT21 funciton
		rjmp	MAIN			; and returns to top of main

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: PRINT12
; Desc: Prints string 1 then string 2 to lcd
;-----------------------------------------------------------
PRINT12:						
		
		rcall LCDClr		; Clear anything already on the screen

		; Move string1 from Program Memory to Data Memory
		ldi ZH, high(STRING1_BEG<<1); Initialize Z-pointer
		ldi ZL, low(STRING1_BEG<<1) 
		ldi		YL, low(LCDLn1Addr) ; Initialize y pointer
		ldi		YH, high(LCDLn1Addr)
		ldi		r23, 12		; Temporary register to hold how many times we want to run LINE1

LINE1:
		lpm r16, Z+			; Load constant from Program
		st  Y+, r16			; Store constant to one past the address pointed to by Y
		dec		r23			; Decrement Read Counter
		brne	LINE1		; Return back to the start of LINE1 if zero flag is 0
		
		; Move string2 from Program Memory to Data Memory
		ldi ZH, high(STRING2_BEG<<1); Initialize Z-pointer
		ldi ZL, low(STRING2_BEG<<1)
		ldi		YL, low(LCDLn2Addr) ; Initialize y-pointer
		ldi		YH, high(LCDLn2Addr)
		ldi		r23, 12		; Temporary register to hold how many times we want to run LINE2

LINE2:
		lpm r16, Z+			; Load constant from Program
		st  Y+, r16			; Store constant to one past the address pointed to by Y
		dec		r23			; Decrement Read Counter
		brne	LINE2		; Return back to the start of LINE1 if zero flag is 0

		rcall	LCDWrite	; Write new values to lcd
		ret					; End a function with RET


;-----------------------------------------------------------
; Func: PRINT21
; Desc: Prints string 2 then string 1 to lcd
;-----------------------------------------------------------
PRINT21:  ;same as PRINT12 just string order is switched

		rcall LCDClr
				
		ldi ZH, high(STRING2_BEG<<1)
		ldi ZL, low(STRING2_BEG<<1)
		ldi		YL, low(LCDLn1Addr)
		ldi		YH, high(LCDLn1Addr)
		ldi		r23, 12

LINE3:
		lpm r16, Z+ ; 
		st  Y+, r16
		dec		r23			
		brne	LINE3
		
		ldi ZH, high(STRING1_BEG<<1)
		ldi ZL, low(STRING1_BEG<<1)
		ldi		YL, low(LCDLn2Addr)
		ldi		YH, high(LCDLn2Addr)
		ldi		r23, 12

LINE4:
		lpm r16, Z+
		st  Y+, r16
		dec		r23		
		brne	LINE4

		rcall LCDWrite
		ret				


;***********************************************************
;*	Stored Program Data
;***********************************************************

STRING1_BEG:
.DB		"Aaron Garcia"	

STRING2_BEG:
.DB		"Hello World!"	

;***********************************************************
;*	Additional Program Includes
;***********************************************************

.include "LCDDriver.asm"
		; Include the LCD Driver


;***********************************************************
;*
;*	 Aaron_Garcia_And_Mateo_Rey_Lab8_Rx_SourceCode.asm
;*
;*	 Tekbot program that can also be controlled by a remote with a matching bot id
;*
;*	 This is the RECEIVE skeleton file for Lab 8 of ECE 375
;*
;***********************************************************
;*
;*	 Author: Aaron Garcia and Mateo Rey
;*	 Date: 12/4/2019
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register 
.def	freezes = r18			; Counts how many times the robot has been frozen
.def	ilcnt = r19				; Inner loop counter for wait function
.def	olcnt = r20				; Outer loop counter for wait function
.def	waitcnt = r21			; Register to hold how many milliseconds you want the wait function to wait for
.def	canexec = r22			; Flag for if the program has received a matching bot id

.equ	WTime = 100				; Wait time for 1 second
.equ	WTime2 = 250			; Wait time for 2.5 seconds

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = 0b00011000;(Enter your robot's address here (8 bits))

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

.org	$0002					; Right whisker interrupt
		rcall	HitRight
		reti

.org	$0004					; Left whisker interrupt
		rcall	HitLeft
		reti

.org	$003C					; USART receive interrupt
		rjmp	Receive
		reti

.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi		mpr, high(RAMEND)
		out		SPH, mpr
		ldi		mpr, low(RAMEND)
		out		SPL, mpr

	;I/O Ports
		ldi		mpr, 0b00001100	; Set Port D Data Direction Register
		out		DDRD, mpr		; for input (except on send and recieve pins)
		ldi		mpr, 0b00000011	; Initialize Port D Data Register
		out		PORTD, mpr		; so both inputs are tri-state

		ldi		mpr, $FF	 	; Set Port B Data Direction Register
		out		DDRB, mpr		; for output
		ldi		mpr, $00		; Initialize Port B Data Register
		out		PORTB, mpr		; so all Port B outputs are default low		
	;USART1
		;Set baudrate at 2400bps
		ldi		mpr, high(832)	; 832 corresponds to the 2400 bps baud rate on a double data rate connection
		sts		UBRR1H, mpr

		ldi		mpr, low(832)
		sts		UBRR1L, mpr
		
		;Enable 2x data rate
		ldi		mpr, (1<<U2X1)	
		sts		UCSR1A, mpr

		;Enable transmitter, receiver and enable receive interrupts
		ldi		mpr, (1<<TXEN0 | 1<<RXEN0 | 1<<RXCIE0)
		sts		UCSR1B, mpr

		;Set frame format: 8 data bits, 2 stop bits, asynchronous
		ldi		mpr, (0<<UMSEL1 | 1<<USBS0 | 1<<UCSZ11 | 1<<UCSZ10)
		sts		UCSR1C, mpr

	;External Interrupts
		;Set the External Interrupt Mask
		ldi		mpr, (1<<INT0 | 1<<INT1)
		out		EIMSK, mpr		
		
		;Set the Interrupt Sense Control to falling edge detection
		ldi		mpr, $0A
		sts		EICRA, mpr

	;Enable global interrupts
		sei
	;Send initial move foward command
		ldi		mpr, MovFwd
		out		PORTB, mpr
	;Clear global flags and counters that are not initialized before use
		clr		freezes
		clr		canexec

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		rjmp	MAIN	; Creates infinite loop in main
;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func: Receive
; Desc: Gets a 8-bit transmission when USART1's receive ready interrupt is triggered. Handles the transmission in the proper way before returning.
;-----------------------------------------------------------
Receive:
		lds		mpr, UDR1		; Loads 8-bit transmission into mpr
		cpi		mpr, BotAddress	; Checks if mpr is holding the robot's bot id
		breq	CanGetCmd		; If so then enters CanGetCmd subfunction
		cpi		mpr, 0b01010101	; Checks to see if mpr is holding the global freeze command from another bot 
		breq	GetFrozen		; If so then enters the GetFrozen subfunction
		cpi		canexec, $00	; Checks if robot has not recieved the correct bot id in the previous transmission
		breq	almostend		; If so then jump to end to finish up
		cpi		mpr, 0b10110000	; Checks if mpr is holding the forward command from its own remote
		breq	Forward			; If so enters Forward subfunction
		cpi		mpr, 0b10000000	; Checks to see if mpr is holding the backward command
		breq	Backward		; If so enters the Backward subfunction
		cpi		mpr, 0b10100000	; Checks to see if mpr is holding the right command
		breq	Right			; If so then enters the Right subfunction
		cpi		mpr, 0b10010000	; Checks if mpr is holding the left command from its own remote
		breq	Left			; If so enters the Left subfunction
		cpi		mpr, 0b11001000	; Checks if mpr is holding the halt command from its own remote
		breq	Haltfunc		; If so enters the Haltfunc subfunction
		cpi		mpr, 0b11111000	; Checks if mpr is holding the freeze command from its own remote
		breq	SendFreeze		; If so enters the SendFreeze subfunciton
		rjmp	end				; Jumps to end to finish up incase that an input does not enter a seperate subfunction (incorrect/corrupted input from remote only)

Forward:
		ldi		mpr, MovFwd		; Loads move forwards command into mpr
		out		PORTB, mpr		; Outpus move fowards command to PORTB
		ldi		canexec, $00	; Since this was a valid command, to run another valid command need to get correct bot id first
		rjmp	end				; Jumps to end to finish up
Backward:
		ldi		mpr, MovBck		; Loads move backwards command into mpr
		out		PORTB, mpr		; Outputs move backwards command to PORTB
		ldi		canexec, $00	; Since this was a valid command, to run another valid command need to get correct bot id first
		rjmp	end				; Jumps to end to finish up
Right:
		ldi		mpr, TurnR		; Loads the turn right command into mpr
		out		PORTB, mpr		; Outputs turn right command to PORTB
		ldi		canexec, $00	; Since this was a valid command, to run another valid command need to get correct bot id first
		rjmp	end				; Jumps to end to finish up
Left: 
		ldi		mpr, TurnL		; Loads turn left command into mpr
		out		PORTB, mpr		; Outputs turn left command to PORTB
		ldi		canexec, $00	; Since this was a valid command, to run another valid command need to get correct bot id first
		rjmp	end				; Jump to end to finish up

almostend:
		rjmp	end				; Link to end for branches that are out of range of end 

Haltfunc:
		ldi		mpr, Halt		; Loads halt command into mpr
		out		PORTB, mpr		; Outputs halt command to PORTB
		ldi		canexec, $00	; Since this was a valid command, to run another valid command need to get correct bot id first
		rjmp	end				; Jumps to end to finish up

CanGetCmd:
		ldi		canexec, 1		; Sets canexec flag to 1
		rjmp	end				; Jumps to end to finish up

GetFrozen:
		rcall	TurnOffRx		; Turns off the Receiver so that the bot cannot receive an Rx interrupt until it has finished freezing
		ldi		canexec, 0		; GetFrozen is only called when the robot receives an 8-bit instruction, therefore we can reset the canexec flag in the case that the previous transmission received was a correct bot id and the next transmission is a valid command
		inc		freezes			; Increments freeze counter
		cpi		freezes, 3		; Check if freeze has been received 3 times
		breq	Brick			; Calls the brick function to stop the robot

		in		mpr, PORTB		; Saves the current state of the robot
		push	mpr				; Pushes that save to the stack
		ldi		mpr, Halt		; Loads the halt command
		out		PORTB, mpr		; Outputs the halt command to PORTB

		ldi		waitcnt, WTime2	; Loads the waitcnt for 2.5 seconds
		rcall	Wait			; Calls Wait twice to make a combined delay of 5 seconds 
		rcall	Wait			; 

		pop		mpr				; Gets previous state from stack
		out		PORTB, mpr		; Restores the previous state of the robot
		rcall	TurnOnRx		; Enables the receiver
		rjmp	end				; Jumps to the end to finish up

SendFreeze:
		rcall	TurnOffRx		; Disables the receiver so that the robot cannot send signals to itself
Transmit:
		lds		mpr, UCSR1A		; Loads the current value of UCSR1A into the mpr to be compared
		sbrs	mpr, 5			; Checks if bit 5 of UCSR1A is set
		rjmp	Transmit		; Loops until bit 5 is not set (until UDR1 is empty and another transmission can be sent)
		ldi		mpr, 0b01010101	; Loads freeze command into mpr so it can be transmitted
		sts		UDR1, mpr		; Stores freeze command into UDR1 so it can be transmitted
		ldi		waitcnt, 20		; Loads a value of 20 into waitcnt register to be used in the Wait function
		rcall	Wait			; Waits for 200 ms to prevent the receiver from turning on while the bot is still transmitting the freeze signal
		rcall	TurnOnRx		; Enables Receiver
		rjmp	end				; Jumps to end to finish up 

Brick:
		rcall	TurnOffRx		; Turns off the receiver so the bot cannot receive any signals
		ldi		mpr, Halt		; Loads halt command as per the freeze requirement
		out		PORTB, mpr		; Outputs halt command to PORTB
		rjmp	Brick			; Creates an infinite loop so the bot can never enter another state

end:
		ldi		mpr, $03		; Load 0b00000011 to mpr to clear queued interrupts
		out		EIFR, mpr		; Write mpr to EIFR to clear interrupts
		sei						; Re enable global interrupts
		ret						; Returns from Receive function


;-----------------------------------------------------------
; Func: HitRight
; Desc: Stops, backs up, turns, then continues forward when a interrupt is triggered for the right whisker
;-----------------------------------------------------------
HitRight:
		rcall	TurnOffRx		; Disable receiver so bot cannot queue more actions
		push	mpr				; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG		; Save program state
		push	mpr				;

		; Move Backwards for a second
		ldi		mpr, MovBck		; Load Move Backward command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL		; Load Turn Left Command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd		; Load Move Forward command
		out		PORTB, mpr		; Send command to port

		pop		mpr				; Restore program state
		out		SREG, mpr		;
		pop		waitcnt			; Restore wait register
		pop		mpr				; Restore mpr
		ldi		mpr, $03		; Load 0b00000011 to mpr to clear queued interrupts
		out		EIFR, mpr		; Write mpr to EIFR to clear interrupts
		sei						; Re enable global interrupts
		rcall	TurnOnRx		; Enables the receiver
		ret						; Return from subroutine


;-----------------------------------------------------------
; Func: HitLeft
; Desc:	Stops, backs up, turns, then continues forward when a left whisker interrupt is triggered
;-----------------------------------------------------------
HitLeft:
		rcall	TurnOffRx		; Disables receiver so the bot cannot queue actions
		push	mpr				; Save mpr register
		push	waitcnt			; Save wait register
		in		mpr, SREG		; Save program state
		push	mpr				;

		; Move Backwards for a second
		ldi		mpr, MovBck		; Load Move Backward command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR		; Load Turn Left Command
		out		PORTB, mpr		; Send command to port
		ldi		waitcnt, WTime	; Wait for 1 second
		rcall	Wait			; Call wait function

		; Move Forward again	
		ldi		mpr, MovFwd		; Load Move Forward command
		out		PORTB, mpr		; Send command to port

		pop		mpr				; Restore program state
		out		SREG, mpr		;
		pop		waitcnt			; Restore wait register
		pop		mpr				; Restore mpr
		ldi		mpr, $03		; Load 0b00000011 to mpr to clear queued interrupts
		out		EIFR, mpr		; Write mpr to EIFR to clear interrupts
		sei						; Re enable global interrupts
		rcall	TurnOnRx		; Enables the receiver
		ret						; Return from subroutine


;-----------------------------------------------------------
; Func: Wait
; Desc: busy waits for 10ms*waitcnt
;-----------------------------------------------------------
Wait:
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
; Func: TurnOffRx
; Desc: Turns off the two bits that control the receiver of USART1
;-----------------------------------------------------------
TurnOffRx:
		ldi		mpr, (1<<TXEN1 | 0<<RXEN1 | 0<<RXCIE1) ; Writes 0 to the Rx enable bits in USCR1B
		sts		UCSR1B, mpr		; Stores new value in USCR1B
		ret						; Returns from TurnOffRx


;-----------------------------------------------------------
; Func: TurnOnRx
; Desc: Turns on the two bits that control the receiver of USART1
;-----------------------------------------------------------
TurnOnRx:
		ldi		mpr, (1<<TXEN1 | 1<<RXEN1 | 1<<RXCIE1) ; Writes 1 to the Rx enable bits in USCR1B
		sts		UCSR1B, mpr		; Stores new value in USCR1B
		ret						; Returns from TurnOnRx


;***********************************************************
;*	Stored Program Data
;***********************************************************
	;No stored program data for this assignment
;***********************************************************
;*	Additional Program Includes
;***********************************************************
	;There are no additional includes for this assignment
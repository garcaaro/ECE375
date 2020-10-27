/*
Aaron Garcia
10/9/2019
ECE 375 lab 2
Wednesday 12-2

This code will cause a TekBot connected to the AVR board to
move forward and when it touches an obstacle, it will reverse
and turn away from the obstacle and resume forward motion.

PORT MAP
Port B, Pin 4 -> Output -> Right Motor Enable
Port B, Pin 5 -> Output -> Right Motor Direction
Port B, Pin 6 -> Output -> Left Motor Direction
Port B, Pin 7 -> Output -> Left Motor Enable
Port D, Pin 1 -> Input -> Left Whisker
Port D, Pin 0 -> Input -> Right Whisker
*/

#define F_CPU 16000000
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>

int main(void)
{
	DDRB=0b11110000;  //initialize port b for output on pins 4-7
	PORTB=0b11110000;  //send all outputs 1 to enable them
	DDRD=0b00000000;  //initialize port d for input on pins 0 & 1
	PIND=0b11111100;  //send inputs 0 to enable them

	
	while (1) // loop forever
	{		
		PORTB=0b01100000; //start moving forward	

		//left wisker or both wiskers sense have the same behavior
		if((PIND == 0b11111101) | (PIND == 0b11111100)){
			PORTB = 0b00000000;  //move backwards				
			_delay_ms(1000);  //wait 1 second
			PORTB = 0b01000000;  //turn right
			_delay_ms(1000); //wait 1 second
			PORTB = 0b01100000; //continue forward			
		}
		//right wisker sense
		else if(PIND == 0b11111110){
			PORTB = 0b00000000;  //move backwards
			_delay_ms(1000);  //wait 1 second
			PORTB = 0b00100000;  //turn left
			_delay_ms(1000); //wait 1 second
			PORTB = 0b01100000; //continue forward
		}
	}
}


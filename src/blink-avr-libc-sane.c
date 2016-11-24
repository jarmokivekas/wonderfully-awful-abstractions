/*
This is a version of the blinky that is still sane.
It is implemented using conventional avr abstractions.
*/

#include <avr/io.h>
#include <avr/interrupt.h>

int main (void) {

	// Set pin mode to output
	DDRB |= (1 << PB5);

	for(;;){
		PORTB |= (1 << PB5);
		_delay_ms(1000);
		PORTB &= ~(1 << PB5);
		_delay_ms(1000);
	}
	return 0;
}

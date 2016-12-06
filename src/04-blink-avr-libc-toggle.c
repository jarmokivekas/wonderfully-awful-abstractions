/*
This is a version of the blinky that is still sane.
It is implemented using conventional avr abstractions.
*/

#include <avr/io.h>
#include <util/delay.h>

int main (void) {

	// Set pin mode to output
	DDRB |= (1 << PB5);

	while(1){
		PORTB ^= (1 << PB5);
		_delay_ms(1000);
	}
	return 0;
}

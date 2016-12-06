; this file is a manually commented version
; of the mnemonic assembly file that gcc produced
; command:
; avr-gcc -S -o 03-blink-avr-libc-sane-asm.s 02-blink-avr-libc-sane.c -O1 -Wall -mmcu=atmega328p -DF_CPU=16000000UL


	.file	"02-blink-avr-libc-sane.c"
__SP_H__ = 0x3e
__SP_L__ = 0x3d
__SREG__ = 0x3f
__tmp_reg__ = 0
__zero_reg__ = 1
	.text
.global	main
	.type	main, @function
main:
/* prologue: function */
/* frame size = 0 */
/* stack size = 0 */
.L__stack_usage = 0
; this sets the pin mode (DDR register)
	sbi 0x4,5
; L2 is the start of the while loop
.L2:
; light on
	sbi 0x5,5
; first delay starts here, registers are first
; initialized based on clock frequency and delay length
	ldi r18,lo8(3199999)
	ldi r24,hi8(3199999)
	ldi r25,hlo8(3199999)
1:	subi r18,1 ; the the delay loop is entered, it consists of 4 instructions
	sbci r24,0
	sbci r25,0
	brne 1b ; jump to start of loop if not done
	rjmp .  ; relaive jump to this address, basically a no-operation
	nop     ; an actual no-operation ()
; light off
	cbi 0x5,5
; start the next delay loop
	ldi r18,lo8(3199999)
	ldi r24,hi8(3199999)
	ldi r25,hlo8(3199999)
1:	subi r18,1
	sbci r24,0
	sbci r25,0
	brne 1b
	rjmp .
	nop
; move back to the start of the while(1) loop
; when the light has blinked and both 1 sec delays are done
	rjmp .L2
	.size	main, .-main
	.ident	"GCC: (GNU) 4.9.2"

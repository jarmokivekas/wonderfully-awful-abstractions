

# Wonderfully awful abstractions

The code in this repository is a submission to the Hackaday 1kB microcode contest.

# Rationale

The purpose of this project is not to be especially esoteric, to implement some novel application, or even to push the boundaries of what can be done in 1kB of machine code.
Instead the purpose of the project is be an exploration into abstractions and optimization.
Abstractions, while wonderful and useful, also have significant impact on the size of a program.
Perhaps this project could serve as a example for "Why Would One Ever Want To Know Assembly?"

This project includes multiple functionally equivalent versions of the Arduino IDE *Blink* example program.
The documented implementations get progressively smaller in binary size, and reduce in the levels of abstraction used.

# Prerequisites


# Blink.ino, the example program

```c
void setup() {
    pinMode(13, OUTPUT);
}

void loop() {
    digitalWrite(13, HIGH);
    delay(1000);
    digitalWrite(13, LOW)
    delay(1000);
}
```

All the files used for building, the build output itself, and various intermediate files are placed by the Arduino IDE into a directory structure in `/tmp/build-<large-random-sting>.tmp`.
Among those files is the final binary that is flashed onto the micro controller.
Initially loading the Blink.ino example program, and compiling it for the ATmega328 yields a 1066 byte binary, even when not considering any bootloader.

```
> avr-size blink.ino.elf
text    data    bss     dec     hex   filename
1066    0       9       1075    433   Blink.ino.elf
```

The IDE doesn't really show it, but what is actually given to the complier is more like what's below.
The main method in Arduino sketches is always the same, but the `setup()` and `loop()` functions are linked from the sketch's .ino file.

As can be seen, the IDE's main method does a lot of convenient initialization of hardware peripherals, which is also why even a simple blink program is relatively large.

```c
#include <Arduino.h>

// Declared weak in Arduino.h to allow user redefinitions.
int atexit(void (* /*func*/ )()) { return 0; }

// Weak empty variant initialization function.
// May be redefined by variant files.
void initVariant() __attribute__((weak));
void initVariant() { }

void setupUSB() __attribute__((weak));
void setupUSB() { }

int main(void)
{
	init();
	initVariant();
#if defined(USBCON)
	USBDevice.attach();
#endif

	setup();
	for (;;) {
		loop();
		if (serialEventRun) serialEventRun();
	}
	return 0;
}



```

IDE does not give very granular control of compile options, and as far as the code goes, there isn't really anything sane we can do about it while staying within constraints of the IDE and the Wiring abstractions.
Some other solution is required.


# Moving to Plain avr-gcc

While it has it's uses, and many have gotten their start in the familiar environment of the Arduino IDE, it will now be ditched in favor of a more plain toolchain: the `avr-gcc` command line.

Pins are addressed somewhat differently when using the AVR-libc abstractions.
The syntax can seem strange to begin with, but using the different `DDR` and `PORT` registers instead of `pinMode()` and `digitalWrite()` respectively gives more granular control, and it is a better representation of what is happening in hardware inside the micro controller chip.
The minutia of how these registers are used is outside the scope of this particular exploration into blinking lights.

Below is a minimal implementation using avr-libc that performs the same blinking action as the Blink.ino example

```c
#include <avr/io.h>
#include <util/delay.h>

int main (void) {
	// Set pin mode to output
	DDRB |= (1 << PB5);

	while(1){
		PORTB |= (1 << PB5);  // light on
		_delay_ms(1000);
		PORTB &= ~(1 << PB5); // light off
		_delay_ms(1000);
	}
	return 0;
}
```

Overlooking the change in syntax, this new implementation is still very similar to the example Blink sketch from the IDE.
However, the machine code size is significantly smaller, since it is lacking the overhead caused by the hardware initialization routines that are present in Sketches.

`avr-size` reports the size to be 176 bytes, almost an order of magnitude difference to the 1066 bytes of the earlier version.

```
> make size
text	   data	    bss	    dec	    hex	filename
 176	      0	      0	    176	     b0	build/02-blink-avr-libc-sane.elf

```

Once again, we are reaching the limit of how much the code can be optimized with the tools that are in use. Next!

# Generating (Dis)Assembly


There are several good ways for generating assembly from C source code.
One option is to pass the `-S` (capital s) flag to `avr-gcc`, which will cause the command to output mnemonic assembly instructions instad of machine code.

Another excellent option is to produce disassembly output using `avr-objdump`.
Some useful flags are `-Mintel`,  `--source`, and `--disassemble-all`.
The output of `avr-objdump` can be made even more verbose if the file being disassembled was compiled with debuggig symbols, i.e. the `-g` flag in gcc.


By disassembling the machine code into something more (but maybe not quite?) human readable, we can find what actually makes our latest binary to be 176 bytes in size.

# Dissection

Looking at the very start of the file, starting at offset 0x00, there is a section labeled `<__vectors>`
For the sake of brevity, the entire section is not listed below, but save for the first instruction, they are all `jmp 0x7c`.
That's an unconditional jump to address `0x7c`.

```
00000000 <__vectors>:
   0:	0c 94 34 00 	jmp	0x68	; 0x68 <__ctors_end>
   4:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
   8:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
   c:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  10:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  {{lines snipped for brevity}}
  58:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  5c:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  60:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  64:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
```

So what's at `0x7c`, one might ask, since seemingly everyone wants to jump there?
Well, another unconditional jump, to address `0x00`, which in turn is an unconditional jump to `0x68`, labeled `<__ctors_end>`
```
00000068 <__ctors_end>:
  68:	11 24       	eor	r1, r1
  6a:	1f be       	out	0x3f, r1	; 63
  6c:	cf ef       	ldi	r28, 0xFF	; 255
  6e:	d8 e0       	ldi	r29, 0x08	; 8
  70:	de bf       	out	0x3e, r29	; 62
  72:	cd bf       	out	0x3d, r28	; 61
  74:	0e 94 40 00 	call	0x80	; 0x80 <main>
  78:	0c 94 56 00 	jmp	0xac	; 0xac <_exit>

0000007c <__bad_interrupt>:
  7c:	0c 94 00 00 	jmp	0	; 0x0 <__vectors>
```

In the simple blinky, no interrupts are actually in use, and all these excess `jmp 0x7c` instruction, the interrupt vector table, is a waste of space.
The next step of this exploration is to take the relevant parts of the assembly code and start using that as our source for compiling new binaries.

# Modifying the Assembly

This would probably be a good time to point out that, please, [Don't Be Clever](http://embedded.fm/episodes/2015/3/25/dont-be-clever).

# Making Assumptions

# Slowing Things Down


# How slow can we go?

# Way Slow

# Tools

- avr-gcc
- avrdude
- avr-size
- avr-objdump
- make
- PCBmode
- Inkscape

    apt-get install binutils-avr gcc-avr avrdude avr-libc


# Sandbox

    "/home/jarmo/tools/arduino-1.6.8/hardware/tools/avr/bin/avr-g++" -c -g -Os -Wall -Wextra -std=gnu++11 -fno-exceptions -ffunction-sections -fdata-sections -fno-threadsafe-statics -MMD -mmcu=atmega328p -DF_CPU=16000000L -DARDUINO=10608 -DARDUINO_AVR_UNO -DARDUINO_ARCH_AVR   "-I/home/jarmo/tools/arduino-1.6.8/hardware/arduino/avr/cores/arduino" "-I/home/jarmo/tools/arduino-1.6.8/hardware/arduino/avr/variants/standard" "/tmp/build648fca7e0bb0b014d8e4a7971690ff82.tmp/sketch/Blink.ino.cpp" -o "/tmp/build648fca7e0bb0b014d8e4a7971690ff82.tmp/sketch/Blink.ino.cpp.o"

---

"/home/jarmo/tools/arduino-1.6.8/hardware/tools/avr/bin/avr-gcc" -c -g -x assembler-with-cpp -mmcu=atmega328p -DF_CPU=16000000L -DARDUINO=10608 -DARDUINO_AVR_UNO -DARDUINO_ARCH_AVR   "-I/home/jarmo/tools/arduino-1.6.8/hardware/arduino/avr/cores/arduino" "-I/home/jarmo/tools/arduino-1.6.8/hardware/arduino/avr/variants/standard" "/home/jarmo/tools/arduino-1.6.8/hardware/arduino/avr/cores/arduino/wiring_pulse.S" -o "/tmp/build648fca7e0bb0b014d8e4a7971690ff82.tmp/core/wiring_pulse.S.o"



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

All the files used for building, the build output, and intermediate files are placed by the Arduino IDE into a directory structure in `/tmp/build-<large-random-sting>.tmp`.
Among those files is the final binary that is flash onto the micro controller.
Initially loading the Blink.ino example program, and compiling it for the ATmega328 yields a 1066 byte binary without, even when not counting any bootloader.

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


# Moving to plain avr-gcc

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



# Optimizing the Assembly

This would probably be a good time to point out that Don't Be Clever


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

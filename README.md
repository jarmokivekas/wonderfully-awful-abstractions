

# Wonderfully awful abstractions

The code in this repository is a submission to the Hackaday 1kB microcode contest.

# Rationale

The purpose of this project is not to be *especially* esoteric, to implementsome novel application, or even push the boundaries of what can be done in 1kB of code. Instead the purpose of the project is to show how abstractions, while wonderful and useful, also have significant impact on the size of program. Perhaps this project could serve as a example for "Why Would One Ever Want To Know Assembly?"

This project includes multiple functionally equivalent versions of the Arduino IDE *Blink* example program. The decumented implementations get progressively smaller in binary size, and reduce the levels of abstraction used.

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
Initially loading the Blink.ino example program, and compiling it for the ATmega328 yields a 1066 byte binary without, even when not counting any bootloader.

```
> avr-size blink.ino.elf
text    data    bss     dec     hex   filename
1066    0       9       1075    433   Blink.ino.elf
```

It doesn't really show it, but what is actually given to the complier is more like what's below. The main method in Arduino sketches is always the same, but the `setup()` and `loop()` functions are linked from the sketch's .ino file.

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

So, the IDE does not give very granular control of compile options, and as far as the code goes, there isn't really anything sane we can do about it while staying within the IDE and the Wiring abstractions. Some other solution is required.


# Moving to plain avr-gcc

While it has it's uses, and many have gotten their start in the familiar environment of the Arduino IDE, it will now be ditched in favor of a more plain toolchain: the `avr-gcc` command line.



```c
#include <avr/io.h>
#include <avr/interrupt.h>

int main (void) {

	while(1){
		_delay_ms(1000);

		_delay_ms(1000);
	}
	return 0;
}
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

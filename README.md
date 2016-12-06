

# Wonderfully awful abstractions


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
 176	      0	      0	    176	     b0	build/02-blink-avr-libc.elf

```



# Generating (Dis)Assembly

In order to make more optimizations, it's helpful to have a better visibility into the machine code that is being generated. There are several good ways for generating assembly from C source code.
One option is to pass the `-S` (capital s) flag to `avr-gcc`, which will cause the command to output mnemonic assembly instructions instead of machine code. This is useful, since the assembly listing produced by `avr-gcc -S ...` can be altered manually, and then complied into a binary.


Another excellent option is to produce disassembly output using `avr-objdump`.
Some useful flags are `-Mintel`,  `--source`, and `--disassemble-all`. In this project disassembly listing are produced using the command

    `avr-objdump --disassemble-all {input-file}  >  {output-file}`

The output of `avr-objdump` can be made even more verbose if the file being disassembled was compiled with debugging symbols, i.e. the `-g` flag in gcc. The `--source` flag will create a listing with C code intermixed with the disassembly listing.


By disassembling the machine code into something more (but maybe not quite?) human readable, we can find what actually makes our latest binary to be 176 bytes in size.

# Dissection

This section takes a deeper look at the disassembly of the avr-libc implementation of th e blink program.

    build/02-blink-avr-libc.disasm: build/02-blink-avr-libc.elf
        avr-objdump -D $< > $@


The bulk of the disassembly listing are tabs separated file with the following fileds:

 - memory address, e.g `5c:`
 - raw hex representation of the machine code instruction, e.g. `0c 94 3e 00`
 - mnemonic representation of the machine code instruction, e.g. `jmp 0x7c`
 - a automatically generated comment, usually address labels, of decimal representation of hexadecimal values in the mnemonic instruction field.


## The Interrupt Vector Table

Looking at the very start of disassembly the file, starting at offset adress `0`, there is a section labeled `<__vectors>`
For the sake of brevity, the entire section is not listed below, but save for the first instruction, they are all `jmp 0x7c`.
That's an unconditional jump to address `0x7c`.



```
00000000 <__vectors>:
   0:	0c 94 34 00 	jmp	0x68	; 0x68 <__ctors_end>
   4:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
   8:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
   c:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  {{lines snipped for brevity}}
  5c:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  60:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
  64:	0c 94 3e 00 	jmp	0x7c	; 0x7c <__bad_interrupt>
```

So what's at `0x7c`, one might ask, since seemingly everyone wants to jump there?
Well, another unconditional jump, to address `0x00`, which in turn is an unconditional jump to `0x68`, labeled `<__ctors_end>`:


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

The section labeled `<__vectors>` is called an _interrupt vector table_ of a _jump table_. However, since in the simple blink program, no interrupts are actually in use, and all these excess `jmp 0x7c` instruction are not doing anything. If the processor would for some reason end up jumping to any of the entries in the `<__vectors>` section, it would simply jump via `<__bad_interrupt> ` to `<__ctros_end>`. Most micro-controllers, including the atmega328p, have hardware timers and i/o peripherals that can be used to interrupt the main program and execute an _interrupt service routine_ (ISR) when the peripheral reaches a particular state (e.g a timer overflows, an i/o pin's state goes from HIGH to LOW, or an serial communication peripheral receives a byte of data).


## Calling the Main Method

All ISR entries in the vector jump table end up at `<__ctors_end>`, so what does that section actually do?

Mnemonic listing of `<__ctors_end>` (same as in the previous sectio, but with different formatting):

```
00000068 <__ctors_end>:
eor   r1, r1
out   0x3f, r1
ldi   r28, 0xFF
ldi   r29, 0x08
out   0x3e, r29
out   0x3d, r28
call  0x80
jmp   0xac
```


 - `eor   r1, r1`:

    The `eor` instruction stands for _Exlusively OR_.
    A pseudo code for this could be `r1 = r1 XOR r1`, or more simple `r1 = 0`, since XORing a value with itself will always result in 0.
 - `out   0x3f, r1`:

    The `out` instruction writes the value of a register into a given RAM address.
    The processor datasheet lists `0x3f` as _"SREG – AVR Status Register"_

 - `ldi   r28, 0xFF`

 - `ldi   r29, 0x08`

 - `out   0x3e, r29`

 - `out   0x3d, r28`

    These four instructions reset the values of the `SPH` and `SPL` registers to their defaults.
    These regisers are the _"Stack Pointer High and Stack Pointer Low Register"_.
    The stack is construct that is used for passing function arguments and return values within the program.

 - `call  0x80; 0x80 <main>`:

    The call instruction is similar to an unconditional jump `(jmp`) instruction, but in addition to jumping, it leaves a pointer to its own address on the stack, so that when the called function returns, the processor knows where to continue.

    The address `0x80` in this case is the start of out `main()` function if the C source code.
 - `jmp   0xac        ; 0xac <_exit>`:

    Unconditional jump to the `<_exit>` subroutine. In the case of the blink program, this should never be reached, as the `<main>` section includes an infinite loop, and thus the previous `call 0x80` instruction will never complete.

    The disassembly listing at `<_exit>` looks like the following:

    ```
    000000ac <_exit>:
      ac:   f8 94   cli

    000000ae <__stop_program>:
      ae:   ff cf   rjmp .-2 ; 0xae <__stop_program>
    ```

    The `cli` instruction in `<_exit>` disables all interrupts. Since there is no return or jump instruction, the program will continue execution at the next instruction, which is the `rjmp .-2` in `<__stop_program>`.
    This is a _relative jump_ instruction that jumps 2 bytes backward in the machine code.
    Notice that the hex for `rjmp .-2` is two bytes long (`ff cf`). This causes an infinite loop, where the instruction jumps to itself, which jumps to itself, which jumps to itself, and so on.
    Since interrupts have been disabled by `cli`, the only thing that can alter the program's behavior at this point is a hardware reset.

## Removing Non-essential Sections

The `<__vectors>` interrupt table, the `<__ctors_end>` initialization code, and the exit sections `<_exit>` and `<__stop_program>` don't actually do anything that is essential for the blink program.
They are nice things to have for a larger program that does more complex things, but since the goal is to implement blink with as few bytes as possible, these sections should we removed.

The atmega328p's processing will correctly execute any binary that has instructions at address `0`. All of the extra sections that are created during the compilation process can be excluded by using the `-c` flag in `avr-gcc`.
The `-c` flag will cause the compilation process to create a _relocatable object file_ that contains only instructions for the functions that were defined in the input source code file (whether that file is a `.c` file with C code, or a `.s` with mnemonic assembly code).
On more complex systems, a relocatable object file would not be executable on its own, but instead multiple object files are combined into one executable binary by the _linker_ stage of the compilation process.
As long as the `main()` function end up at address `0` of the object file, it will be correctly executed by the atmega328p's processor.

## The Main Method
# Flipping bits

# Modifying the Assembly

The next step of this exploration is to take the relevant parts of the assembly code and start using that as our source for compiling new binaries.


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

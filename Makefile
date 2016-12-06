CC=avr-gcc
INCLUDEFAGS=
DEBUGFLAGS=#-D NODEBUG
CFLAGS=$(INCLUDEFALGS) $(DEBUGFLAGS) -O1 -Wall -mmcu=atmega328p -DF_CPU=16000000UL
LDFLAGS=-Wall


build/01-blink.ino.elf:
	# blink.ino: Nothing to be done

build/02-blink-avr-libc.elf: src/02-blink-avr-libc.c
	# complie elf binary from the c file
	avr-gcc -o $@ $< $(CFLAGS)

build/02-blink-avr-libc.s: src/02-blink-avr-libc.c
	# output assembly language from the c file
	avr-gcc -S -o $@ $< $(CFLAGS)

build/02-blink-avr-libc.disasm: build/02-blink-avr-libc.elf
	# output assembly language from the elf file
	avr-objdump $< > $@

build/03-avr-libc-ams.elf: src/02-blink-avr-libc.c
	# convert previous C file to mnemonic assembly
	avr-gcc -S -o $@ $< $(CFLAGS)


build/04-blink-avr-libc-toggle.elf: src/04-blink-avr-libc-toggle.c
	# convert previous C file to mnemonic assembly
	avr-gcc  -o $@ $< $(CFLAGS)

build/04-blink-avr-libc-toggle.s: src/04-blink-avr-libc-toggle.c
	# output assembly language from the c file
	avr-gcc -S -o $@ $< $(CFLAGS)

build/05-blink-avr-libc-toggle-from-s.elf: build/04-blink-avr-libc-toggle.s
	# output assembly language from the c file
	avr-gcc -o $@ $< $(CFLAGS)

build/06-blink-avr-libc-toggle-from-s-object.elf: build/04-blink-avr-libc-toggle.s
	# output assembly language from the c file
	avr-gcc -c -o $@ $< $(CFLAGS)

build/07-blink-avr-libc-toggle-from-s-object.disasm: build/06-blink-avr-libc-toggle-from-s-object.elf
	# output assembly language from the c file
	avr-objdump $< -D > $@
# avr-libc-sane.elf: src/avr-libc-sane.s

size:
	avr-size build/*.elf


#simple_beater_flash:
#	avrdude -c arduino -p atmega328p -P /dev/ttyACM0 -U flash:w:bin/AVR/simple_beater.hex
#simple_beater_hex:bin/AVR/simple_beater.o
#	avr-objcopy -O ihex $^ bin/AVR/simple_beater.hex


#--------cleaning up
clean:
	rm -f build/*elf build/*.disasm

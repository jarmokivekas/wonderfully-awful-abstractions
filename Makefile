CC=avr-gcc
INCLUDEFAGS=
DEBUGFLAGS=#-D NODEBUG
CFLAGS=$(INCLUDEFALGS) $(DEBUGFLAGS) -O1 -Wall -mmcu=atmega328p -DF_CPU=16000000UL
LDFLAGS=-Wall


avr-libc-sane: src/02-blink-avr-libc-sane.c
	avr-gcc -o build/02-blink-avr-libc-sane.elf $< $(CFLAGS)

size:
	avr-size build/*.elf


bin/AVR/%.o: src/%.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

src/%.s: src/%.c
	$(CC) -S -o $@ $< $(CFLAGS)

#--------all inclusive bytebeater
bytebeater_flash:
	avrdude -c arduino -p atmega328p -P /dev/ttyACM0 -U flash:w:bin/AVR/bytebeater.hex
bytebeater_hex:bin/AVR/bytebeater.o
	avr-objcopy -O ihex $^ bin/AVR/bytebeater.hex
bin/AVR/bytebeater.o:                 \
	bin/AVR/log/log_serial.o          \
	bin/AVR/struct/beat_context.o     \
	bin/AVR/language/stack_machine.o  \
	bin/AVR/language/tokenizer.o      \
	bin/AVR/language/interpreter.o    \
	bin/AVR/bytebeater/timer.o        \
	bin/AVR/bytebeater/interface.o    \
	bin/AVR/bytebeater/main.o
	$(CC) -o $@ $^ $(LDFLAGS)

#--------simple version of the bytebeater
simple_beater_flash:
	avrdude -c arduino -p atmega328p -P /dev/ttyACM0 -U flash:w:bin/AVR/simple_beater.hex
simple_beater_hex:bin/AVR/simple_beater.o
	avr-objcopy -O ihex $^ bin/AVR/simple_beater.hex
bin/AVR/simple_beater.o:          \
	src/simple_beater/main.c      \
	src/simple_beater/UART_puts.c \
	src/simple_beater/TIMER_beat.c \
	src/simple_beater/ADC_read.c
	$(CC) -o $@ $^ $(CFLAGS)

#--------sandbox, a place to try AVR code
sand_flash:
	avrdude -c arduino -p atmega328p -P /dev/ttyACM0 -U flash:w:bin/AVR/sand.hex
sand_hex:bin/AVR/sand.o
	avr-objcopy -O ihex $^ bin/AVR/sand.hex
bin/AVR/sand.o:\
	src/sandbox/main.c
	$(CC) -o $@ $^ $(CFLAGS)

#--------cleaning up
clean:
	rm -f build/*elf

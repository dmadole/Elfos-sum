
all: sum.bin

lbr: sum.lbr

sum.bin: sum.asm include/bios.inc include/kernel.inc
	asm02 -L -b sum.asm
	-rm -f sum.build

crc: crc.c
	cc -o crc crc.c

sum.lbr: sum.bin
	lbradd sum.lbr sum.bin

clean:
	-rm -f sum.lst
	-rm -f sum.bin
	-rm -f sum.lbr


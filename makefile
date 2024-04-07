
all: sum.bin

lbr: sum.lbr

sum.bin: sum.asm crc.asm include/bios.inc include/kernel.inc
	asm02 -L -b sum.asm
	-rm -f sum.build

crctab: crctab.c
	cc -o crctab crctab.c

crc.asm: crctab
	./crctab > crc.asm

sum.lbr: sum.bin
	lbradd sum.lbr sum.bin

clean:
	-rm -f sum.lst
	-rm -f sum.bin
	-rm -f sum.lbr
	-rm -f crc.asm
	-rm -f crctab

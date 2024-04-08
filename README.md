# Elfos-sum

> [!NOTE]
>This repository has a submodule for the include files needed to build it. You can have these pulled automatically if you add the  --
recurse option to your git clone command.

This is a work-alike for the standard Elf/OS crc command but that is many times faster. This uses a pre-calculated table of input byte factors to greatly speed the calculation of CRC for the file specified. The output CRCs match those used by crc so this file can be put in place of crc if desired.

As of build 2, this implements two options:
* -x: Output CRC that would result if file was XMODEM-padded.
* -b: Output both the plain CRC and the XMODEM-padded CRC, separated with a slash.

This remains a drop-in replacement for the standard crc command, just faster. On the basetools40.lbr file, which is 21,769 bytes:

crc: 26 seconds
sum: 3 seconds

So, sum is almost ten times faster. If you need both checksums and so would have to run crc twice, then sum is about twenty times faster! These times are with turbo installed, both would have been around 13 seconds longer without.

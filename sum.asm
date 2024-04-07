
;  Copyright 2021, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


           ; Include kernal API entry points

#include include/bios.inc
#include include/kernel.inc


           ; Executable program header

           org     2000h - 6
           dw      start
           dw      end-start
           dw      start

start:     org     2000h
           br      main


           ; Build information

           db      8+80h              ; month
           db      8                  ; day
           dw      2021               ; year
           dw      2                  ; build

           db      'See github.com/dmadole/Elfos-sum for more info',0


           ; Main code starts here, check provided argument

main:      ldi     128                ; output raw crc only
           phi     r8

skipspac:  lda     ra                 ; skip any spaces
           lbz     argsfail
           smi     ' '
           lbz     skipspac

           dec     ra                 ; if starts with dash then option
           lda     ra
           smi     '-'
           lbnz    nooption

           lda     ra                 ; check x option
           smi     'x'
           lbnz    notxopt

           ldi     64                 ; output xmodem crc only
           phi     r8
           lbr     skipspac

notxopt:   smi     'b'-'x'            ; check b option
           lbnz    argsfail

           ldi     192                ; output raw and xmodem crc
           phi     r8
           lbr     skipspac

nooption:  dec     ra
           glo     ra                 ; remember start of name
           plo     rf
           ghi     ra
           phi     rf

skipchar:  lda     ra                 ; end at null or space
           lbz     openfile
           smi     ' '
           lbnz    skipchar
           str     ra


           ; Open file for input and initialize CRC parameters

openfile:  ldi     fd.1               ; get file descriptor
           phi     rd
           ldi     fd.0
           plo     rd

           ldi     0                  ; create + truncate
           plo     r7

           sep     scall              ; open file
           dw      o_open
           lbdf    openfail

           ldi     0                  ; initialize CRC to zero
           plo     r7
           phi     r7

           plo     r8                 ; count of bytes processed

           ldi     crctablo.1         ; pointer to crc lsb table
           phi     ra

           ldi     crctabhi.1         ; pointer to crc msb table
           phi     rb


           ; Loops back to here to get another chunk from the file

readmore:  ldi     buffer.1           ; pointer to data buffer
           phi     rf
           ldi     buffer.0
           plo     rf

           ldi     512.1              ; length to read at a time
           phi     rc
           ldi     512.0
           plo     rc

           sep     scall              ; read from file
           dw      o_read

           dec     rc                 ; adjust so that we only need to
           ghi     rc                 ; test the msb in the loop later
           adi     1
           phi     rc
           lbz     endfile            ; if read count is 0, end of file

           ldi     buffer.1           ; reset buffer to beginning
           phi     rf
           ldi     buffer.0
           plo     rf

           ghi     r8                 ; clear any overflow bits in r8
           ani     192
           phi     r8


           ; The following calcualtes CRC-16/KERMIT using a pre-calculated
           ; table of intermediate factors for speed. The algorithm is:
           ;
           ;   crc = 0x0000;
           ;   for (i = 0; i < strlen(bytes); ++i) {
           ;     j = (crc & 0xff) ^ bytes[i];
           ;     crc = (crc >> 8) ^ table[j];
           ;   } 
           ;
           ; r7 = crc value
           ; ra = table lsb pointer
           ; rb = table msb pointer
           ; rf = input bytes pointer

readloop:  glo     r7           ; j = (crc & 0xff) ^ bytes[i];
           sex     rf
           xor
           plo     ra
           plo     rb

           ghi     r7           ; crc = (crc >> 8) ^ table[j];
           sex     ra
           xor
           plo     r7
           ldn     rb
           phi     r7

           inc     r8           ; count total bytes

           inc     rf           ; rc pre-adjusted so only have to check msb
           dec     rc
           ghi     rc
           lbnz    readloop

           sex     r2           ; get next chunk from file
           lbr     readmore


           ; At end of file, close file, setup output buffer, and put
           ; raw result into buffer if it's been requested.

endfile:   sep     scall        ; close file when done
           dw      o_close

           ldi     buffer.1 ;   ; reuse data buffer for output composition
           phi     rf
           ldi     buffer.0
           plo     rf

           ghi     r8           ; if not outputting raw, skip to xmodem
           ani     128
           lbz     getxmod

           ghi     r7           ; move crc to rd since file is closed now
           phi     rd
           glo     r7
           plo     rd

           sep     scall        ; convert to ASCII hex represenation
           dw      f_hexout4

           ghi     r8           ; if not outputting xmodem skip to output
           ani     64
           lbz     skipxmod

           ldi     '/'          ; add a delimiter between crc's
           str     rf
           inc     rf


           ; If Xmodem-padded CRC is requested, continue calculating with
           ; constant pad bytes of 26 until the next 128-byte boundard is
           ; reached to determine what the CRC would be if the file was
           ; transferred via XMODEM.

getxmod:   ghi     r7           ; start with crc so far
           phi     r9
           glo     r7
           plo     r9

           sex     ra           ; because xor is indexed into ra table

           lbr     xmodmpad     ; jump ahead to end test

xpadloop:  glo     r9           ; j = (crc & 0xff) ^ 26;
           xri     26
           plo     ra
           plo     rb

           ghi     r9           ; crc = (crc >> 8) ^ table[j];
           xor
           plo     r9
           ldn     rb
           phi     r9

           inc     r8

xmodmpad:  glo     r8           ; keep going until xmodem boundary
           ani     127
           lbnz    xpadloop

           sex     r2           ; be extra careful in case this is moved


           ; Add xmodem padded result output into buffer

           ghi     r9           ; move crc to rd since file is closed now
           phi     rd
           glo     r9
           plo     rd

           sep     scall        ; convert to ASCII hex represenation
           dw      f_hexout4


           ; Done calculating and composing output, terminate and sent it.

skipxmod:  ldi     13           ; add cr
           str     rf
           inc     rf

           ldi     10           ; add lf
           str     rf
           inc     rf

           ldi     0            ; add terminating null
           str     rf
           inc     rf
         
           ldi     buffer.1     ; repoint to start of buffer
           phi     rf
           ldi     buffer.0
           plo     rf

           sep     scall        ; output the result
           dw      o_msg

           sep     sret         ; and exit back to operating system


           ; Error handling follows, mostly these just output a message and
           ; exit, but readfail also closes the input file first since it
           ; would be open at that point.

argsfail:  sep     scall
           dw      o_inmsg
           db      'Usage: sum filename',13,10,0

           sep     sret

openfail:  sep     scall
           dw      o_inmsg
           db      'Open file failed',13,10,0

           sep     sret

readfail:  sep     scall        ; if read on input file fails
           dw      o_close

           sep     scall
           dw      o_inmsg
           db      'Read file failed',13,10,0

           sep     sret


           ; Concatenate an inline string onto RF and leave RF pointing to
           ; the zero terminator so it's suitable for further appending.

instrcat:  lda     r6
           str     rf
           inc     rf
           lbnz    instrcat

           dec     rf
           sep     sret


           ; The following is a table of pre-calculated CRC factors that
           ; was produced by the following code, stored with the low-order
           ; and high-order bytes broken out into separate tables to save
           ; a couple of instructions in the inner calculation loop.
           ;
           ;   poly = 0x8408; /* reflected 0x1021 */
           ;   for (i = 0; i < 256; i++) {
           ;     k = i;
           ;     for (j = 0; j < 8; j++) {
           ;       k = (k >> 1) ^ ((k & 1) ? poly : 0);
           ;       }
           ;     table[i] = k;
           ;   }
           ;
           ; These need to be page aligned so we can just set lsb to index.

           org     $ + 0ffh & 0ff00h

#include crc.asm

           ; Include file descriptor in program image so it is initialized.

fd:        db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0


end:       ; These buffers are not included in the executable image but will
           ; will be in memory immediately following the loaded image.

dta:       ds      512
buffer:    ds      512


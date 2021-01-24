; This software is copyright 2021 by David S. Madole.
; You have permission to use, modify, copy, and distribute
; this software so long as this copyright notice is retained.
; This software may not be used in commercial applications
; without express written permission from the author.
;
; The author grants a license to Michael H. Riley to use this
; code for any purpose he sees fit, including commercial use,
; and without any need to include the above notice.


           ; Include kernal API entry points

           include bios.inc
           include kernel.inc


           ; Executable program header

           org     2000h - 6
           dw      start
           dw      end-start
           dw      start

start:     org     2000h
           br      skipspac


           ; Build information

           db      1+80h              ; month
           db      15                 ; day
           dw      2021               ; year
           dw      1                  ; build
text:      db      'Written by David S. Madole',0


           ; Main code starts here, check provided argument

skipspac:  lda     ra                 ; skip any spaces
           bz      argsfail
           smi     ' '
           bz      skipspac

           dec     ra
           glo     ra                 ; remember start of name
           plo     rf
           ghi     ra
           phi     rf

skipchar:  lda     ra                 ; end at null or space
           bz      openfile
           smi     ' '
           bnz     skipchar
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
           bdf     openfail

           ldi     0                  ; initialize CRC to zeri
           plo     r7
           phi     r7

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
           bz      endfile            ; if read count is 0, end of file

           ldi     buffer.1           ; reset buffer to beginning
           phi     rf
           ldi     buffer.0
           plo     rf


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

           inc     rf           ; rc pre-adjusted so only have to check msb
           dec     rc
           ghi     rc
           bnz     readloop

           sex     r2           ; get next chunk from file
           br      readmore


           ; Reached end of input file, close and output calculated CRC

endfile:   sep     scall        ; close file when done
           dw      o_close

           ldi     buffer.1 ;   ; reuse data buffer for output composition
           phi     rf
           ldi     buffer.0
           plo     rf

           ghi     r7           ; move crc to rd since file is closed now
           phi     rd
           glo     r7
           plo     rd

           sep     scall        ; convert to ASCII hex represenation
           dw      f_hexout4

           ldi     13           ; add cr
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

           sep    scall         ; output the result
           dw     o_msg

           sep    sret          ; and exit back to operating system


           ; Error handling follows, mostly these just output a message and
           ; exit, but readfail also closes the input file first since it
           ; would be open at that point.

argsfail:  ldi     argsmesg.1   ; if supplied argument is not valid
           phi     rf
           ldi     argsmesg.0
           plo     rf
           br      failmsg

openfail:  ldi     openmesg.1   ; if unable to open input file
           phi     rf
           ldi     openmesg.0
           plo     rf
           br      failmsg

readfail:  sep     scall        ; if read on input file fails
           dw      o_close

           ldi     readmesg.1
           phi     rf
           ldi     readmesg.0
           plo     rf

failmsg:   sep     scall       ; output the message and return
           dw      o_msg
           sep     sret

argsmesg:  db      'Usage: sum filename',13,10,0
openmesg:  db      'Open file failed',13,10,0
readmesg:  db      'Read file failed',13,10,0


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

crctablo:  db      000h, 089h, 012h, 09bh, 024h, 0adh, 036h, 0bfh
           db      048h, 0c1h, 05ah, 0d3h, 06ch, 0e5h, 07eh, 0f7h
           db      081h, 008h, 093h, 01ah, 0a5h, 02ch, 0b7h, 03eh
           db      0c9h, 040h, 0dbh, 052h, 0edh, 064h, 0ffh, 076h
           db      002h, 08bh, 010h, 099h, 026h, 0afh, 034h, 0bdh
           db      04ah, 0c3h, 058h, 0d1h, 06eh, 0e7h, 07ch, 0f5h
           db      083h, 00ah, 091h, 018h, 0a7h, 02eh, 0b5h, 03ch
           db      0cbh, 042h, 0d9h, 050h, 0efh, 066h, 0fdh, 074h
           db      004h, 08dh, 016h, 09fh, 020h, 0a9h, 032h, 0bbh
           db      04ch, 0c5h, 05eh, 0d7h, 068h, 0e1h, 07ah, 0f3h
           db      085h, 00ch, 097h, 01eh, 0a1h, 028h, 0b3h, 03ah
           db      0cdh, 044h, 0dfh, 056h, 0e9h, 060h, 0fbh, 072h
           db      006h, 08fh, 014h, 09dh, 022h, 0abh, 030h, 0b9h
           db      04eh, 0c7h, 05ch, 0d5h, 06ah, 0e3h, 078h, 0f1h
           db      087h, 00eh, 095h, 01ch, 0a3h, 02ah, 0b1h, 038h
           db      0cfh, 046h, 0ddh, 054h, 0ebh, 062h, 0f9h, 070h
           db      008h, 081h, 01ah, 093h, 02ch, 0a5h, 03eh, 0b7h
           db      040h, 0c9h, 052h, 0dbh, 064h, 0edh, 076h, 0ffh
           db      089h, 000h, 09bh, 012h, 0adh, 024h, 0bfh, 036h
           db      0c1h, 048h, 0d3h, 05ah, 0e5h, 06ch, 0f7h, 07eh
           db      00ah, 083h, 018h, 091h, 02eh, 0a7h, 03ch, 0b5h
           db      042h, 0cbh, 050h, 0d9h, 066h, 0efh, 074h, 0fdh
           db      08bh, 002h, 099h, 010h, 0afh, 026h, 0bdh, 034h
           db      0c3h, 04ah, 0d1h, 058h, 0e7h, 06eh, 0f5h, 07ch
           db      00ch, 085h, 01eh, 097h, 028h, 0a1h, 03ah, 0b3h
           db      044h, 0cdh, 056h, 0dfh, 060h, 0e9h, 072h, 0fbh
           db      08dh, 004h, 09fh, 016h, 0a9h, 020h, 0bbh, 032h
           db      0c5h, 04ch, 0d7h, 05eh, 0e1h, 068h, 0f3h, 07ah
           db      00eh, 087h, 01ch, 095h, 02ah, 0a3h, 038h, 0b1h
           db      046h, 0cfh, 054h, 0ddh, 062h, 0ebh, 070h, 0f9h
           db      08fh, 006h, 09dh, 014h, 0abh, 022h, 0b9h, 030h
           db      0c7h, 04eh, 0d5h, 05ch, 0e3h, 06ah, 0f1h, 078h

crctabhi:  db      000h, 011h, 023h, 032h, 046h, 057h, 065h, 074h
           db      08ch, 09dh, 0afh, 0beh, 0cah, 0dbh, 0e9h, 0f8h
           db      010h, 001h, 033h, 022h, 056h, 047h, 075h, 064h
           db      09ch, 08dh, 0bfh, 0aeh, 0dah, 0cbh, 0f9h, 0e8h
           db      021h, 030h, 002h, 013h, 067h, 076h, 044h, 055h
           db      0adh, 0bch, 08eh, 09fh, 0ebh, 0fah, 0c8h, 0d9h
           db      031h, 020h, 012h, 003h, 077h, 066h, 054h, 045h
           db      0bdh, 0ach, 09eh, 08fh, 0fbh, 0eah, 0d8h, 0c9h
           db      042h, 053h, 061h, 070h, 004h, 015h, 027h, 036h
           db      0ceh, 0dfh, 0edh, 0fch, 088h, 099h, 0abh, 0bah
           db      052h, 043h, 071h, 060h, 014h, 005h, 037h, 026h
           db      0deh, 0cfh, 0fdh, 0ech, 098h, 089h, 0bbh, 0aah
           db      063h, 072h, 040h, 051h, 025h, 034h, 006h, 017h
           db      0efh, 0feh, 0cch, 0ddh, 0a9h, 0b8h, 08ah, 09bh
           db      073h, 062h, 050h, 041h, 035h, 024h, 016h, 007h
           db      0ffh, 0eeh, 0dch, 0cdh, 0b9h, 0a8h, 09ah, 08bh
           db      084h, 095h, 0a7h, 0b6h, 0c2h, 0d3h, 0e1h, 0f0h
           db      008h, 019h, 02bh, 03ah, 04eh, 05fh, 06dh, 07ch
           db      094h, 085h, 0b7h, 0a6h, 0d2h, 0c3h, 0f1h, 0e0h
           db      018h, 009h, 03bh, 02ah, 05eh, 04fh, 07dh, 06ch
           db      0a5h, 0b4h, 086h, 097h, 0e3h, 0f2h, 0c0h, 0d1h
           db      029h, 038h, 00ah, 01bh, 06fh, 07eh, 04ch, 05dh
           db      0b5h, 0a4h, 096h, 087h, 0f3h, 0e2h, 0d0h, 0c1h
           db      039h, 028h, 01ah, 00bh, 07fh, 06eh, 05ch, 04dh
           db      0c6h, 0d7h, 0e5h, 0f4h, 080h, 091h, 0a3h, 0b2h
           db      04ah, 05bh, 069h, 078h, 00ch, 01dh, 02fh, 03eh
           db      0d6h, 0c7h, 0f5h, 0e4h, 090h, 081h, 0b3h, 0a2h
           db      05ah, 04bh, 079h, 068h, 01ch, 00dh, 03fh, 02eh
           db      0e7h, 0f6h, 0c4h, 0d5h, 0a1h, 0b0h, 082h, 093h
           db      06bh, 07ah, 048h, 059h, 02dh, 03ch, 00eh, 01fh
           db      0f7h, 0e6h, 0d4h, 0c5h, 0b1h, 0a0h, 092h, 083h
           db      07bh, 06ah, 058h, 049h, 03dh, 02ch, 01eh, 00fh


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


*******************************************************
*
* DWInit
*    Initialize DriveWire for CoCo Bit Banger

DWInit
               IFNE     ARDUINO

* setup PIA PORTA (read)
               clr       $FF51
               clr       $FF50
               lda       #$2C
               sta       $FF51

* setup PIA PORTB (write)
               clr       $FF53
               lda       #$FF
               sta       $FF52
               lda       #$2C
               sta       $FF53
               rts

               ELSE

               pshs      a,x
               IFDEF     PIA1Base
               ldx       #PIA1Base           $FF20
               clr       1,x                 clear CD
               lda       #%11111110
               sta       ,x
               lda       #%00110100
               sta       1,x
               lda       ,x
               ENDC
               puls       a,x,pc

               ENDC

*******************************************************
*
* DWRead
*    Receive a response from the DriveWire server.
*    Times out if serial port goes idle for more than 1.4 (0.7) seconds.
*    Serial data format:  1-8-N-1
*    4/12/2009 by Darren Atkinson
*
* Entry:
*    X  = starting address where data is to be stored
*    Y  = number of bytes expected
*
* Exit:
*    CC = carry set on framing error, Z set if all bytes received
*    X  = starting address of data received
*    Y  = checksum
*    U is preserved.  All accumulators are clobbered
*


          IFNE atari
* ATARI SIO Version
DWRead                    
          clrb                     clear carry
          pshs      cc,a,x,y,u
          tfr       x,u
          ldx       #$0000
          orcc      #$50
*          lda       D.IRQENSHDW
*          sta       IRQEN
*          ora       #%00100000
* enable the serial input interrupt
          
          ldb  SERIN               read what is in the buffer
          lda	#$13
          sta	SKCTL
          sta	SKRES

inloop@
          lda       D.IRQENSHDW
          ora       #%00100000
          sta       IRQEN
          ldd       #$0000
loop@
          subd      #$0001
          beq       outtahere@
          pshs      b
          ldb       IRQST
          bitb      #%00100000
          puls      b
          bne       loop@
          ldb       SERIN
          lda       D.IRQENSHDW
          sta       IRQEN
* check for framing error
          lda       SKSTAT
          bpl       outtahere@	framing error
          lsla
          bpl       outtahere@	data input overrun
          stb       ,u+
          abx
          leay      -1,y
          bne       inloop@
          stx       4,s
bye
          sta	     SKRES          clear framing or data input overrun bits
          puls      cc,a,x,y,u,pc
outtahere@
          sta	     SKRES          clear framing or data input overrun bits
          puls      cc,a
          stx       2,s
          orcc      #$01
          puls      x,y,u,pc

          ELSE
          IFNE BECKER

* NOTE: There is no timeout currently on here...
DWRead    pshs   cc,d,x,u
          leau   ,x 
          ldx    #$0000
          orcc   #IntMasks
loop@     ldb    $FF41
          bitb   #$02
          beq    loop@
          ldb    $FF42
          stb    ,u+
          abx
          leay   -1,y
          bne    loop@

          tfr    x,y
          puls   cc
          andcc  #^Carry
          orcc   #Zero
          puls   d,x,u,pc

          ELSE
          IFNE BAUD38400
*******************************************************
* 38400 bps using 6809 code and timimg
*******************************************************

DWRead    clra                          ; clear Carry (no framing error)
          deca                          ; clear Z flag, A = timeout msb ($ff)
          tfr       cc,b
          pshs      u,x,dp,b,a          ; preserve registers, push timeout msb
          orcc      #$50                ; mask interrupts
          tfr       a,dp                ; set direct page to $FFxx
          setdp     $ff
          leau      ,x                  ; U = storage ptr
          ldx       #0                  ; initialize checksum
          adda      #2                  ; A = $01 (serial in mask), set Carry

* Wait for a start bit or timeout
rx0010    bcc       rxExit              ; exit if timeout expired
          ldb       #$ff                ; init timeout lsb
rx0020    bita      <BBIN               ; check for start bit
          beq       rxByte              ; branch if start bit detected
          subb      #1                  ; decrement timeout lsb
          bita      <BBIN
          beq       rxByte
          bcc       rx0020              ; loop until timeout lsb rolls under
          bita      <BBIN
          beq       rxByte
          addb      ,s                  ; B = timeout msb - 1
          bita      <BBIN
          beq       rxByte
          stb       ,s                  ; store decremented timeout msb
          bita      <BBIN
          bne       rx0010              ; loop if still no start bit

* Read a byte
rxByte    leay      ,-y                 ; decrement request count
          ldd       #$ff80              ; A = timeout msb, B = shift counter
          sta       ,s                  ; reset timeout msb for next byte
rx0030    exg       a,a
          nop
          lda       <BBIN               ; read data bit
          lsra                          ; shift into carry
          rorb                          ; rotate into byte accumulator
          lda       #$01                ; prep stop bit mask
          bcc       rx0030              ; loop until all 8 bits read

          stb       ,u+                 ; store received byte to memory
          abx                           ; update checksum
          ldb       #$ff                ; set timeout lsb for next byte
          anda      <BBIN               ; read stop bit
          beq       rxExit              ; exit if framing error
          leay      ,y                  ; test request count
          bne       rx0020              ; loop if another byte wanted
          lda       #$03                ; setup to return SUCCESS

* Clean up, set status and return
rxExit    leas      1,s                 ; remove timeout msb from stack
          inca                          ; A = status to be returned in C and Z
          ora       ,s                  ; place status information into the..
          sta       ,s                  ; ..C and Z bits of the preserved CC
          leay      ,x                  ; return checksum in Y
          puls      cc,dp,x,u,pc        ; restore registers and return
          setdp     $00


          ELSE
          IFNE H6309-1
*******************************************************
* 57600 (115200) bps using 6809 code and timimg
*******************************************************

DWRead    clra                          ; clear Carry (no framing error)
          deca                          ; clear Z flag, A = timeout msb ($ff)
          tfr       cc,b
          pshs      u,x,dp,b,a          ; preserve registers, push timeout msb
          orcc      #$50                ; mask interrupts
          tfr       a,dp                ; set direct page to $FFxx
          setdp     $ff
          leau      ,x                  ; U = storage ptr
          ldx       #0                  ; initialize checksum
          lda       #$01                ; A = serial in mask
          bra       rx0030              ; go wait for start bit

* Read a byte
rxByte    leau      1,u                 ; bump storage ptr
          leay      ,-y                 ; decrement request count
          lda       <BBIN               ; read bit 0
          lsra                          ; move bit 0 into Carry
          ldd       #$ff20              ; A = timeout msb, B = shift counter
          sta       ,s                  ; reset timeout msb for next byte
          rorb                          ; rotate bit 0 into byte accumulator
rx0010    lda       <BBIN               ; read bit (d1, d3, d5)
          lsra
          rorb
          bita      1,s                 ; 5 cycle delay
          bcs       rx0020              ; exit loop after reading bit 5
          lda       <BBIN               ; read bit (d2, d4)
          lsra
          rorb
          leau      ,u
          bra       rx0010

rx0020    lda       <BBIN               ; read bit 6
          lsra
          rorb
          leay      ,y                  ; test request count
          beq       rx0050              ; branch if final byte of request
          lda       <BBIN               ; read bit 7
          lsra
          rorb                          ; byte is now complete
          stb       -1,u                ; store received byte to memory
          abx                           ; update checksum
          lda       <BBIN               ; read stop bit
          anda      #$01                ; mask out other bits
          beq       rxExit              ; exit if framing error

* Wait for a start bit or timeout
rx0030    bita      <BBIN               ; check for start bit
          beq       rxByte              ; branch if start bit detected
          bita      <BBIN               ; again
          beq       rxByte
          ldb       #$ff                ; init timeout lsb
rx0040    bita      <BBIN
          beq       rxByte
          subb      #1                  ; decrement timeout lsb
          bita      <BBIN
          beq       rxByte
          bcc       rx0040              ; loop until timeout lsb rolls under
          bita      <BBIN
          beq       rxByte
          addb      ,s                  ; B = timeout msb - 1
          bita      <BBIN
          beq       rxByte
          stb       ,s                  ; store decremented timeout msb
          bita      <BBIN
          beq       rxByte
          bcs       rx0030              ; loop if timeout hasn't expired
          bra       rxExit              ; exit due to timeout

rx0050    lda       <BBIN               ; read bit 7 of final byte
          lsra
          rorb                          ; byte is now complete
          stb       -1,u                ; store received byte to memory
          abx                           ; calculate final checksum
          lda       <BBIN               ; read stop bit
          anda      #$01                ; mask out other bits
          ora       #$02                ; return SUCCESS if no framing error

* Clean up, set status and return
rxExit    leas      1,s                 ; remove timeout msb from stack
          inca                          ; A = status to be returned in C and Z
          ora       ,s                  ; place status information into the..
          sta       ,s                  ; ..C and Z bits of the preserved CC
          leay      ,x                  ; return checksum in Y
          puls      cc,dp,x,u,pc        ; restore registers and return
          setdp     $00


          ELSE
*******************************************************
* 57600 (115200) bps using 6309 native mode
*******************************************************

DWRead    clrb                          ; clear Carry (no framing error)
          decb                          ; clear Z flag, B = $FF
          pshs      u,x,dp,cc           ; preserve registers
          orcc      #$50                ; mask interrupts
*         ldmd      #1                  ; requires 6309 native mode
          tfr       b,dp                ; set direct page to $FFxx
          setdp     $ff
          leay      -1,y                ; adjust request count
          leau      ,x                  ; U = storage ptr
          tfr       0,x                 ; initialize checksum
          lda       #$01                ; A = serial in mask
          bra       rx0030              ; go wait for start bit

* Read a byte
rxByte    sexw                          ; 4 cycle delay
          ldw       #$006a              ; shift counter and timing flags
          clra                          ; clear carry so next will branch
rx0010    bcc       rx0020              ; branch if even bit number (15 cycles)
          nop                           ; extra (16th) cycle
rx0020    lda       <BBIN               ; read bit
          lsra                          ; move bit into carry
          rorb                          ; rotate bit into byte accumulator
          lda       #0                  ; prep A for 8th data bit
          lsrw                          ; bump shift count, timing bit to carry
          bne       rx0010              ; loop until 7th data bit has been read
          incw                          ; W = 1 for subtraction from Y
          inca                          ; A = 1 for reading bit 7
          anda      <BBIN               ; read bit 7
          lsra                          ; move bit 7 into carry, A = 0
          rorb                          ; byte is now complete
          stb       ,u+                 ; store received byte to memory
          abx                           ; update checksum
          subr      w,y                 ; decrement request count
          inca                          ; A = 1 for reading stop bit
          anda      <BBIN               ; read stop bit
          bls       rxExit              ; exit if completed or framing error

* Wait for a start bit or timeout
rx0030    clrw                          ; initialize timeout counter
rx0040    bita      <BBIN               ; check for start bit
          beq       rxByte              ; branch if start bit detected
          addw      #1                  ; bump timeout counter
          bita      <BBIN
          beq       rxByte
          bcc       rx0040              ; loop until timeout rolls over
          lda       #$03                ; setup to return TIMEOUT status

* Clean up, set status and return
rxExit    beq       rx0050              ; branch if framing error
          eora      #$02                ; toggle SUCCESS flag
rx0050    inca                          ; A = status to be returned in C and Z
          ora       ,s                  ; place status information into the..
          sta       ,s                  ; ..C and Z bits of the preserved CC
          leay      ,x                  ; return checksum in Y
          puls      cc,dp,x,u,pc        ; restore registers and return
          setdp     $00

          ENDC
          ENDC
          ENDC
          ENDC
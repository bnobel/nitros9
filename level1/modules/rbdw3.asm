********************************************************************
* rbdw3 - DriveWire 3 driver
*
* $Id$
*
* This driver works in conjuction with the DriveWire Server on Linux,
* Mac or Windows, providing the CoCo with pseudo-disk access through
* the serial port.
*
* It adheres to the DriveWire Version 3 Protocol.
*
* The baud rate is set at 115200 and the communications requirements
* are set to 8-N-1.  For OS-9 Level One on a CoCo 2, the baud rate
* is 57600.
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      2008/02/08  Boisy G. Pitre
* Started from drivewire.asm in DriveWire 2 Product folder.
*
*   2      2008/04/22  Boisy G. Pitre
* Verified working operation on a CoCo 3 running NitrOS-9/6809 Level 1 @ 57.6Kbps
*
*   3      2009/03/09  Boisy G. Pitre
* Added checks for size after reading as noted by Darren A's email.

         nam   rbdw3
         ttl   DriveWire 3 driver

NUMRETRIES equ  8

         ifp1
         use   defsfile
         use   dwdefs.d
         endc

NumDrvs  set   4

tylg     set   Drivr+Objct   
atrv     set   ReEnt+rev
rev      set   $01
edition  set   3

         mod   eom,name,tylg,atrv,start,size

         rmb   DRVBEG+(DRVMEM*NumDrvs)
driveno  rmb   1
retries  rmb   1
size     equ   .

         fcb   DIR.+SHARE.+PEXEC.+PREAD.+PWRIT.+EXEC.+UPDAT.

name     fcs   /rbdw3/
         fcb   edition

start    bra   Init
         nop
         bra   Read
         nop
         lbra  Write
         lbra  GetStat
         lbra  SetStat

* Term
*
* Entry:
*    U  = address of device memory area
*
* Exit:
*    CC = carry set on error
*    B  = error code
*
Term
* Send OP_TERM to the server
         clrb				clear Carry
         pshs  a,cc			then push CC on stack
         lda   #OP_TERM
         leax  1,s
         sta   ,x
         ldy   #$0001
         IFGT  LEVEL-1
         ldu   <D.DWSUB
         ELSE
         ldu   >D.DWSUB
         ENDC
         jsr   6,u
         puls  a,cc,pc

* Init
*
* Entry:
*    Y  = address of device descriptor
*    U  = address of device memory area
*
* Exit:
*    CC = carry set on error
*    B  = error code
*
Init
         IFGT  Level-1
* Perform this so we can successfully do F$Link below
         ldx   <D.Proc
         pshs  a,x
         ldx   <D.SysPrc
         stx   <D.Proc 
         ELSE
         pshs  a
         ENDC

         ldb   #NumDrvs
         stb   V.NDRV,u
         leax  DRVBEG,u
         lda   #$FF
Init2    sta   DD.TOT,x			invalidate drive tables
         sta   DD.TOT+1,x
         sta   DD.TOT+2,x
         leax  DRVMEM,x
         decb
         bne   Init2

* Link to subroutine module
         clra
         leax  name+2,pcr
         os9   F$Link
         bcs   InitEx 
         tfr   y,u		 
         IFGT  LEVEL-1
         stu   <D.DWSUB
         ELSE
         stu   >D.DWSUB
         ENDC
* Initialize the low level device
         jsr   ,u
         lda   #OP_INIT
         leax  ,s
         ldy   #$0001
         jsr   6,u
         clrb

InitEx
         IFGT  Level-1
         puls  a,x
         stx   <D.Proc
         rts
         ELSE
         puls  a,pc
         ENDC

* Read
*
* Entry:
*    B  = MSB of LSN
*    X  = LSB of LSN
*    Y  = address of path descriptor
*    U  = address of device memory area
*
* Exit:
*    CC = carry set on error
*    B  = error code
*
Read 
         lda   #NUMRETRIES
         sta   retries,u
         cmpx  #$0000			LSN 0?
         bne   ReadSect			branch if not
         tstb	   			LSN 0?
         bne   ReadSect			branch if not
* At this point we're reading LSN0
         bsr   ReadSect			read the sector
         bcs   CpyLSNEx			if error, exit
         leax  DRVBEG,u			point to start of drive table
         ldb   <PD.DRV,y		get drive number
NextDrv  beq   CopyLSN0			branch if terminal count
         leax  <DRVMEM,x		else move to next drive table entry
         decb				decrement counter
         bra   NextDrv			and continue
CopyLSN0 ldb   #DD.SIZ			get size to copy
         ldy   PD.BUF,y			point to buffer
CpyLSNLp lda   ,y+			get byte from buffer
         sta   ,x+			and save in drive table
         decb
         bne   CpyLSNLp
CpyLSNEx rts


ReadSect pshs  cc
         pshs  u,y,x,b,a,cc			then push CC and others on stack
* Send out op code and 3 byte LSN
         lda   PD.DRV,y			get drive number
         cmpa  #NumDrvs
         blo   Read1
         ldb   #E$Unit
         bra   ReadEr2
Read1    sta   driveno,u
         lda   #OP_READEX		load A with READ opcode
         
Read2
         ldb   driveno,u
         leax  ,s
         std   ,x
         ldy    #5 
         IFGT  LEVEL-1
         ldu   <D.DWSUB
         ELSE
         ldu   >D.DWSUB
         ENDC
         orcc  #IntMasks
         jsr   6,u
		 
* Get 256 bytes of sector data
         ldx   5,s
         ldx   PD.BUF,x			get buffer pointer into X
         lda   #255
         jsr   3,u
         bcs   ReadEr1
         cmpd  #256
         bne   ReadEr1
         pshs  y
         leax  ,s
         ldy   #$0002
         jsr   6,u				write checksum to server

* Get error code byte
         leax  ,s
         lda   #255
         jsr   3,u
         bcs   ReadEr0			branch if we timed out
         cmpd  #0001
         bne   ReadEr0
         puls  d
         tfr   a,b				transfer byte to B (in case of error)
         tstb					is it zero?
         beq   ReadEx			if not, exit with error
         cmpb  #E$CRC
         bne   ReadEr2
         ldu   7,s				get U from stack
         dec   retries,u		decrement retries
         beq   ReadEr1
         
         lda   #OP_REREADEX		reread opcode
         bra   Read2			and try getting sector again
ReadEr0 puls  d
ReadEr1  ldb   #E$Read			read error
ReadEr2  lda   9,s
         ora   #Carry
         sta   9,s
ReadEx   leas  5,s
         puls  y,u
         puls  cc,pc

* Write
*
* Entry:
*    B  = MSB of LSN
*    X  = LSB of LSN
*    Y  = address of path descriptor
*    U  = address of device memory area
*
* Exit:
*    CC = carry set on error
*    B  = error code
*
Write    lda   #NUMRETRIES
         sta   retries,u
         pshs  cc
         pshs  u,y,x,b,a,cc
* Send out op code and 3 byte LSN
         lda   PD.DRV,y
         cmpa  #NumDrvs
         blo   Write1
         comb			set Carry
         ldb   #E$Unit
         bra   WritEx
Write1   sta   driveno,u
         lda   #OP_WRITE
Write15
         ldb   driveno,u
         leax  ,s
         std   ,x
         ldy   #$0005
         IFGT  LEVEL-1
         ldu   <D.DWSUB
         ELSE
         ldu   >D.DWSUB
         ENDC
         orcc  #IntMasks
         jsr   6,u

* Compute checksum on sector we just sent and send checksum to server
         ldy   5,s				get Y from stack
         ldx   PD.BUF,y			point to buffer
         ldy   #256
         jsr   6,u
         leax  -256,x
         bsr   DoCSum
         pshs  d
         leax  ,s
         ldy   #$0002
         jsr   6,u

* Await acknowledgement from server on receipt of sector
*         ldy   #$0001
         lda   #255
         leax  ,s
         jsr   3,u				read ack byte from server
         bcs   WritEx0
         cmpd  #$0001
         bne   WritEx0
         puls  d				  
         tsta
         beq   WritEx			yep
         tfr   a,b
         cmpb  #E$CRC			checksum error?
         bne   WritEx2
         ldu   7,s				get U from stack
         dec   retries,u		decrement retries
         beq   WritEx1			exit with error if no more
         lda   #OP_REWRIT		else resend
         bra   Write15
WritEx0  puls  d
WritEx1  ldb   #E$Write
WritEx2  lda   9,s
         ora   #Carry
         sta   9,s
WritEx   leas  5,s
         puls  y,u
         puls  cc,pc
 
         use   dwcheck.asm
		 
* SetStat
*
* Entry:
*    R$B = function code
*    Y   = address of path descriptor
*    U   = address of device memory area
*
* Exit:
*    CC = carry set on error
*    B  = error code
*
SetStat  lda   #OP_SETSTA
* Size optimization
		 fcb   $8C  skip next two bytes


* GetStat
*
* Entry:
*    R$B = function code
*    Y   = address of path descriptor
*    U   = address of device memory area
*
* Exit:
*    CC = carry set on error
*    B  = error code
*
GetStat  
         lda   #OP_GETSTA
         clrb				clear Carry
         pshs  cc			and push CC on stack
         leas  -3,s
         sta   ,s
         lda   PD.DRV,y			get drive number
         ldx   PD.RGS,y
         ldb   R$B,x
         std   1,s
         leax  ,s
         ldy   #$0003
         IFGT  LEVEL-1
         ldu   <D.DWSUB
         ELSE
         ldu   >D.DWSUB
         ENDC
         jsr   6,u
         leas  3,s
         puls  cc,pc
		 
         emod
eom      equ   *
         end

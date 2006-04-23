********************************************************************
* SysGo - Kickstart program module
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   5      1998/10/12  Boisy G. Pitre
* Taken from OS-9 L2 Tandy distribution and modified banner for V3.
*
*   5r2    2003/01/08  Boisy G. Pitre
* Fixed fork behavior so that if 'shell startup' fails, system doesn't
* jmp to Crash, but tries AutoEx instead.  Also changed /DD back to /H0
* for certain boot floppy cases.
*
*          2003/09/04  Boisy G. Pitre
* Back-ported to OS-9 Level One.
*
*   5r3    2003/12/14  Boisy G. Pitre
* Added SHIFT key check to prevent startup/autoex from starting if
* held down.  Gene Heskett, this Bud's for you.

         nam   SysGo
         ttl   Kickstart program module

         IFP1
         use   defsfile
         use   scfdefs
         ENDC

tylg     set   Prgrm+Objct
atrv     set   ReEnt+rev
rev      set   $03
edition  set   $05

         mod   eom,name,tylg,atrv,start,size

u0000    rmb   32
u0020    rmb   42
u004A    rmb   33
u006B    rmb   6
u0071    rmb   655
size     equ   .

name     fcs   /SysGo/
         fcb  edition

* Default process priority
DefPrior set   128         

Banner   equ   *
         fcc   "NitrOS-9/"
         IFNE  H6309
         fcc   /6309 /
         ELSE
         fcc   /6809 /
         ENDC
         fcc   /Level /
         fcb   '0+Level
         fcc   / V0/
         fcb   '0+NOS9VER
         fcc   /.0/
         fcb   '0+NOS9MAJ
         fcc   /.0/
         fcb   '0+NOS9MIN
         fcb   C$CR,C$LF
* For ROM version, cut down on verbage
         IFNE  tano
         fcc   "Tano Dragon (US)"
         ELSE
         IFNE  d64
         fcc   "Dragon (UK)"
         ELSE
         IFNE  dalpha
         fcc   "Dragon Alpha"
         ELSE
         fcc   "Color Computer"
         ENDC
         ENDC
         ENDC
         fcc   " Port"
         fcb   C$CR,C$LF
         IFEQ  ROM
         fcc   /(C) 2006 The NitrOS-9 Project/
         fcb   C$CR,C$LF
         IFNE  NOS9DBG
         fcc   "**   DEVELOPMENT BUILD   **"
         fcb   C$CR,C$LF
         fcc   "** NOT FOR DISTRIBUTION! **"
         fcb   C$CR,C$LF
         ENDC
         dts   
         fcb   C$CR,C$LF
         fcc   !http://www.nitros9.org!
         fcb   C$CR,C$LF
         ENDC
         fcb   C$LF
BannLen  equ   *-Banner

         IFEQ  ROM
DefDev   equ   *
         IFNE  DD
         fcc   "/DD"
         ELSE
         fcc   "/H0"
         ENDC
         fcb   C$CR
HDDev    equ   *
         IFNE  DD
         fcc   "/DD/"
         ELSE
         fcc   "/H0/"
         ENDC
ExecDir  fcc   "CMDS"
         fcb   C$CR
         ENDC

Shell    fcc   "Shell"
         fcb   C$CR
AutoEx   fcc   "AutoEx"
         fcb   C$CR

         IFEQ  ROM
Startup  fcc   "startup -p"
         fcb   C$CR
StartupL equ  *-Startup
         ENDC

ShellPrm equ   *
         IFGT  Level-1
         fcc   "i=/1"
         ENDC
CRtn     fcb   C$CR
ShellPL  equ   *-ShellPrm

* Default time packet
DefTime  dtb

         IFEQ  Level-1
* BASIC reset code      
BasicRst fcb   $55
         neg   <$0074
         nop
         clr   >PIA0Base+3
         nop       
         nop
         sta   >$FFDF           turn off ROM mode
         jmp   >Bt.Start+2      jump to boot
BasicRL  equ   *-BasicRst
         ENDC


* SysGo Entry Point
start    leax  >IcptRtn,pcr
         os9   F$Icpt
* Set priority of this process
         os9   F$ID
         ldb   #DefPrior
         os9   F$SPrior
* Show banner
         leax  >Banner,pcr
         ldy   #BannLen
         lda   #$01                    standard output
         os9   I$Write                 write out banner
* Set default time
         leax  >DefTime,pcr
         os9   F$STime                 set time to default
         IFEQ  ROM
* Change EXEC and DATA dirs
         leax  >ExecDir,pcr
         lda   #EXEC.
         os9   I$ChgDir                change exec. dir
         leax  >DefDev,pcr
         lda   #READ.+WRITE.
         os9   I$ChgDir                change data dir.
         bcs   L0125
         leax  >HDDev,pcr
         lda   #EXEC.
         os9   I$ChgDir                change exec. dir to HD
         ENDC

* Setup BASIC code
L0125    equ   *
         pshs  u,y
         IFEQ  Level-1
         leax  >BasicRst,pcr
         ldu   #D.CBStrt
         ldb   #BasicRL
CopyLoop lda   ,x+   
         sta   ,u+
         decb
         bne   CopyLoop
         ELSE
         os9   F$ID
         lbcs  L01A9
         leax  ,u
         os9   F$GPrDsc
         lbcs  L01A9
         leay  ,u
         ldx   #$0000
         ldb   #$01
         os9   F$MapBlk
         bcs   L01A9

         lda   #$55	set flag for Color BASIC
         sta   <D.CBStrt,u
* Copy our default I/O ptrs to the system process
         ldd   <D.SysPrc,u
         leau  d,u
         leau  <P$DIO,u
         leay  <P$DIO,y
         ldb   #DefIOSiz-1
L0151    lda   b,y
         sta   b,u
         decb
         bpl   L0151
         ENDC

         IFEQ  ROM
* Fork shell startup here
* Added 12/14/03: If SHIFT is held down, startup is not run
         lda   #$01			standard output
         ldb   #SS.KySns
         os9   I$GetStt
         bcs   DoStartup
         bita  #SHIFTBIT		SHIFT key down?
         bne   L0186			Yes, don't to startup or autoex
DoStartup leax  >Shell,pcr
         leau  >Startup,pcr
         ldd   #256
         ldy   #StartupL
         os9   F$Fork
         bcs   DoAuto
         os9   F$Wait
         ENDC
* Fork AutoEx here
DoAuto   leax  >AutoEx,pcr
         leau  >CRtn,pcr
         ldd   #$0100
         ldy   #$0001
         os9   F$Fork
         bcs   L0186
         os9   F$Wait
L0186    equ   *
         puls  u,y
FrkShell leax  >ShellPrm,pcr
         leay  ,u
         ldb   #ShellPL
L0190    lda   ,x+
         sta   ,y+
         decb
         bne   L0190
* Fork final shell here
         leax  >Shell,pcr
         lda   #$01		D = 256 (B already 0 from above)
         ldy   #ShellPL
         IFGT  Level-1
         os9   F$Chain
         ldb   #$06
         bra   Crash
L01A9    ldb   #$04
Crash    clr   >DPort+$08	turn off disk motor
         jmp   <D.Crash
         ELSE
         os9   F$Fork
         bcs   DeadEnd
         os9   F$Wait
         bcc   FrkShell
DeadEnd  bra   DeadEnd
         ENDC

IcptRtn  rti

         emod
eom      equ   *
         end

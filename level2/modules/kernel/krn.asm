********************************************************************
* OS9p1 - OS-9 Level Two Kernel Part 1
*
* $Id$
*
* Ed.    Comments                                       Who YY/MM/DD
* ------------------------------------------------------------------
* 19r6   Assembles to the os9p1 module that works on    BGP 02/08/21
*        my NitrOS-9 system
* 19r7   Added check for CRC feature bit in init module BGP 02/09/26

         nam   OS9p1
         ttl   OS-9 Level Two Kernel Part 1

         IFP1
         use   defsfile
         ENDC

* defines for customizations
Revision set   7          module revision
Edition  set   19         module Edition
Where    equ   $F000      absolute address of where OS9p1 starts in memory

         mod   eom,MName,Systm,ReEnt+Revision,OS9P1,0

MName    fcs   /OS9p1/
         fcb   Edition 

         IFNE  H6309
* FILL - all unused bytes are now here
         fcc   /0123456789ABCDEF/
         fcc   /0123456789ABCDEF/
         fcc   /0123456789ABCDEF/
         fcc   /01234567/
         ELSE
         fcc   /12345123/
         ENDC

* Might as well have this here as just past the end of OS9p1...
DisTable fdb   L0CD2+Where   D.Clock absolute address at the start
         fdb   XSWI3+Where   D.XSWI3
         fdb   XSWI2+Where   D.XSWI2
         fdb   D.Crash       D.XFIRQ crash on an FIRQ
         fdb   XIRQ+Where    D.XIRQ
         fdb   XSWI+Where    D.XSWI
         fdb   D.Crash       D.XNMI crash on an NMI
         fdb   $0055         D.ErrRst ??? Not used as far as I can tell
         fdb   Sys.Vec+Where Initial OS9p1 system call vector
DisSize  equ   *-DisTable
* DO NOT ADD ANYTHING BETWEEN THESE 2 TABLES: see code using 'SubSiz', below
LowSub   equ   $0160      start of low memory subroutines
SubStrt  equ   *
* D.Flip0 - switch to system task 0
R.Flip0  equ   *
         IFNE  H6309
         aim   #$FE,<D.TINIT  map type 0
         lde   <D.TINIT   'nother 2 bytes saved if GRFDRV does a 'tfr cc,e'
         ste   >DAT.Task   and we can use A here, instead of E
         ELSE
         pshs  a
         lda   <D.TINIT
         anda  #$FE
         sta   <D.TINIT
         sta   >DAT.Task
         puls  a
         ENDC
         clr   <D.SSTskN
         tfr   x,s
         tfr   a,cc
         rts   
SubSiz   equ   *-SubStrt
* Don't add any code here: See L0065, below.
* Interrupt service routine
Vectors  jmp    [<-(D.SWI3-D.XSWI3),x]   (-$10) (Jmp to 2ndary vector)

* Let's start by initializing system page
OS9P1    equ    *
         IFNE   H6309
         ldq    #$01001f00  Start address to clear & # bytes to clear
         leay   <OS9P1+2,pc Point to a 0
         tfm    y,d+
         std    <D.CCStk    Set pointer to top of global memory to $2000
         lda    #$01        set task user table to $0100
         ELSE
         ldx    #$100
         ldy    #$2000-$100
         clra
         clrb
L001C    std    ,x++
         leay   -2,y
         bne    L001C
         stx    <D.CCStk    Set pointer to top of global memory to $2000
         inca			D = $0100
         ENDC
* Setup system direct page variables
         std    <D.Tasks
         addb   #$20        set Task image table to $0120
         std    <D.TskIPt
         clrb               set memory block map to $0200
         inca
         std    <D.BlkMap
         addb   #$40        set second block map to $0240
         std    <D.BlkMap+2
         clrb               set system service dispatch table to $0300
         inca
         std    <D.SysDis
         inca               set user dispatch table to $0400
         std    <D.UsrDis
         inca               set process descriptor block to $0500
         std    <D.PrcDBT
         inca               set system process descriptor to $0600
         std    <D.SysPrc
         std    <D.Proc     set user process descriptor to $0600
         adda   #$02        set stack pointer to $0800
         tfr    d,s
         inca               set system stack to $0900
         std    <D.SysStk
         std    <D.SysMem   set system memory map ptr $0900
         inca               set module directory start to $0a00
         std    <D.ModDir
         std    <D.ModEnd   set module directory end to $0a00
         adda   #$06        set secondary module directory start to $1000
         std    <D.ModDir+2
         std    <D.ModDAT   set module directory DAT pointer to $1000
         std    <D.CCMem    set pointer to beginning of global memory to $1000
* In following line, CRC=ON if it is STA <D.CRC, CRC=OFF if it is a STB <D.CRC
         stb    <D.CRC      set CRC checking flag to off

* Initialize interrupt vector tables
         leay  <DisTable,pcr point to table of absolute vector addresses
         ldx   #D.Clock   where to put it in memory
         IFNE  H6309
         ldf   #DisSize   size of the table - E=0 from TFM, above
         tfm   y+,x+      move it over
         ELSE
         ldb   #DisSize
LoopCopy lda   ,y+
         sta   ,x+
         decb
         bne   LoopCopy
         ENDC

* initialize D.Flip0 routine in low memory
* Y=ptr to R.Flip0 already
*         leay  >R.Flip0,pc
         ldu   #LowSub    somewhere in block 0 that's never modified
         stu   <D.Flip0   switch to system task 0
         IFNE  H6309
         ldf   #SubSiz    size of it
         tfm   y+,u+      copy it over
         ELSE
         ldb   #SubSiz
Loop2    lda   ,y+
         sta   ,u+
         decb
         bne   Loop2
         ENDC

*         leau   <Vectors,pc   point to vector
         tfr   y,u        move the pointer to a faster register
L0065    stu    ,x++        Set all IRQ vectors to go to Vectors for now
         cmpx   #D.NMI
         bls    L0065

* Initialize user interupt vectors
         ldx   <D.XSWI2     Get SWI2 (os9 command) service routine pointer
         stx   <D.UsrSvc    Save it as user service routine pointer
         ldx   <D.XIRQ      Get IRQ service routine pointer
         stx   <D.UsrIRQ    Save it as user IRQ routine pointer

         leax  >SysCall,pc  Setup System service routine entry vector
         stx   <D.SysSvc
         stx   <D.XSWI2

         leax  >S.SysIRQ,pc Setup system IRQ service vector
         stx   <D.SysIRQ
         stx   <D.XIRQ

         leax  >S.SvcIRQ,pc Setup in system IRQ service vector
         stx   <D.SvcIRQ
         leax  >S.Poll,pc   Setup interrupt polling vector
         stx   <D.Poll    ORCC #$01;RTS
         leax  >S.AltIRQ,pc    Setup alternate IRQ vector: pts to an RTS
         stx   <D.AltIRQ

         lda   #'1        --- in OS9p1
         jsr   <D.BtBug   ---

         leax  >S.Flip1,pc  Setup change to task 1 vector
         stx   <D.Flip1

* Setup System calls
         leay  >SysCalls,pc
         lbsr  SysSvc

* Initialize system process descriptor
         ldu   <D.PrcDBT    get process table pointer
         ldx   <D.SysPrc    get system process pointer

* These overlap because it is quicker than trying to strip hi byte from X
         stx   ,u           save it as first process in table
         stx   1,u          save it as the second as well
         IFNE  H6309
         oim   #$01,P$ID,x  Set process ID to 1 (inited to 0)
         oim   #SysState,P$State,x  Set to system state (inited to 0)
         ELSE
         ldd   #$01*256+SysState
         sta   P$ID,x
         stb   P$State,x
         ENDC
         clra               System task is task #0
         sta   <D.SysTsk
         sta   P$Task,x
         coma               Setup its priority & age ($FF)
         sta   P$Prior,x
         sta   P$Age,x
         leax  <P$DATImg,x  point to DAT image
         stx   <D.SysDAT    save it as a pointer in DP
* actually, since block 0 is tfm'd to be zero, we can skip the next 2 lines
         IFNE  H6309
         clrd
         ELSE
         clra
         clrb
         ENDC
         std   ,x++         initialize 1st block to 0 (for this DP)

* Dat.BlCt-ROMCount-RAMCount
         lda   #$06       initialize the rest of the blocks to be free
         ldu   #DAT.Free
L00EF    stu   ,x++
         deca
         bne   L00EF

         ldu   #$003F      Block $3F is in use, at the top of system DAT image
         stu   ,x

         ldx   <D.Tasks     Point to task user table
         inc   ,x           mark first 2 in use (system & GrfDrv)
         inc   1,x

* Setup system memory map
         ldx   <D.SysMem    Get system memory map pointer
         ldb   <D.CCStk     Get MSB of top of CC memory
L0104    inc   ,x+          Mark it as used
         decb               Done?
         bne   L0104        No, go back till done

* Calculate memory size
         ldx   <D.BlkMap    get ptr to 8k block map
         inc   <$3F,x       mark block $3F as used (kernel)
         IFNE  H6309
         ldq   #$00080100   e=Marker, D=Block # to check
L0111    asld               get next block #
         stb   >$FFA5       Map block into block 6 of my task
         ste   >-$6000,x    save marker to that block
         cmpe  ,x           did it ghost to block 0?
         bne   L0111        No, keep going till ghost is found
         stb    <D.MemSz    Save # 8k mem blocks that exist
         addr   x,d         add number of blocks to block map start
         std    <D.BlkMap+2 save block map end pointer
         ELSE
         ldd    #$0008
L0111    aslb
         rola
         stb    >$FFA5
         pshs   a
         lda    #$01
         sta    >-$6000,x
         cmpa   ,x
         puls   a
         bne    L0111
         stb    <D.MemSz
         pshs   x
         addd   ,s++
         std    <D.BlkMap+2
         ENDC
* [D] at this point will contain 1 of the following:
* $0010 - 128k
* $0020 - 256k
* $0040 - 512k
* $0080 - 1024k
* $0100 - 2048k
         bitb  #%00110000   block above 128K-256K?
         beq   L0170        yes, no need to mark block map
         tstb               2 meg?
         beq   L0170        yes, skip this
* Mark blocks from 128k-256K to block $3F as NOT RAM
         abx                add maximum block number to block map start
         leax  -1,x         Skip good blocks that are RAM
         lda   #NotRAM      Not RAM flag
         subb  #$3F         Calculate # blocks to mark as not RAM
L0127    sta   ,x+          Mark them all
         decb
         bne   L0127

L0170    ldx   #Bt.Start  start address of the boot track in memory
         lda   #$12       size of the boot track: B=$00 from L0127 loop, above
         lbsr  I.VBlock   go verify it

         bsr   L01D2       go mark system map

* See if init module is in memory already
L01B0    leax  <init,pc    point to 'Init' module name
         bsr   link        try & link it
         bcc   L01BF       no error, go on
L01B8    os9   F$Boot      error linking init, try & load boot file
         bcc   L01B0       got it, try init again
         bra   L01CE       error, re-booting do D.Crash
* Save pointer to init module and execute os9p2
L01BF    stu   <D.Init     Save init module pointer
         lda   Feature1,u  Get feature byte #1 from init module
         bita  #CRCOn      CRC feature on?
         beq   ShowI       if not, continue
         inc   <D.CRC      else inc. CRC flag
ShowI    lda   #'i         found init module
         jsr   <D.BtBug

L01C1    leax  <os9p2,pc   Point to it's name
         bsr   link        Try to link it
         bcc   L01D0       It worked, execute it
         os9   F$Boot      It doesn't exist try re-booting
         bcc   L01C1       No error's, let's try to link it again
L01CE    jmp   <D.Crash    obviously can't do it, crash machine
L01D0    jmp   ,y          execute os9p2

* Mark kernel in system memory map as used memory (256 byte blocks)
L01D2    ldx   <D.SysMem   Get system mem ptr
         ldd   #NotRAM*256+$ED  $ED00 is the start of the boot
         abx                point to Bt.Start - start of boot track
         comb             we have $FF-$ED pages to mark as used
         sta   b,x         Mark I/O as not RAM
L01DF    lda   #RAMinUse   get in use flag
L01E1    sta   ,x+         save it
         decb               done?
         bne   L01E1       no, keep going
         ldx   <D.BlkMap   get pointer to start of block map
         sta   <$3f,x      mark kernel block as RAMinUse, instead of ModInBlk
S.AltIRQ rts                return

* Link module pointed to by X
link     lda   #Systm      Attempt to link system module
         os9   F$Link   
         rts

init     fcs   'Init'
os9p2    fcs   'OS9p2'

* Service vector call pointers
SysCalls fcb   F$Link
         fdb   FLink-*-2
         fcb   F$PrsNam
         fdb   FPrsNam-*-2
         fcb   F$CmpNam
         fdb   FCmpNam-*-2
         fcb   F$CmpNam+SysState
         fdb   FSCmpNam-*-2
         fcb   F$CRC
         fdb   FCRC-*-2
         fcb   F$SRqMem+SysState
         fdb   FSRqMem-*-2
         fcb   F$SRtMem+SysState
         fdb   FSRtMem-*-2
         fcb   F$AProc+SysState
         fdb   FAProc-*-2
         fcb   F$NProc+SysState
         fdb   FNProc-*-2
         fcb   F$VModul+SysState
         fdb   FVModul-*-2
         fcb   F$SSvc+SysState
         fdb   FSSvc-*-2
         fcb   F$SLink+SysState
         fdb   FSLink-*-2
         fcb   F$Boot+SysState
         fdb   FBoot-*-2
         fcb   F$BtMem+SysState
         fdb   FSRqMem-*-2
         IFNE  H6309
         fcb   F$CpyMem
         fdb   FCpyMem-*-2
         ENDC
         fcb   F$Move+SysState
         fdb   FMove-*-2
         fcb   F$AllRam
         fdb   FAllRam-*-2
         fcb   F$AllImg+SysState
         fdb   FAllImg-*-2
         fcb   F$SetImg+SysState
         fdb   FFreeLB-*-2
         fcb   F$FreeLB+SysState
         fdb   FSFreeLB-*-2
         fcb   F$FreeHB+SysState
         fdb   FFreeHB-*-2
         fcb   F$AllTsk+SysState
         fdb   FAllTsk-*-2
         fcb   F$DelTsk+SysState
         fdb   FDelTsk-*-2
         fcb   F$SetTsk+SysState
         fdb   FSetTsk-*-2
         fcb   F$ResTsk+SysState
         fdb   FResTsk-*-2
         fcb   F$RelTsk+SysState
         fdb   FRelTsk-*-2
         fcb   F$DATLog+SysState
         fdb   FDATLog-*-2
         fcb   F$LDAXY+SysState
         fdb   FLDAXY-*-2
         fcb   F$LDDDXY+SysState
         fdb   FLDDDXY-*-2
         fcb   F$LDABX+SysState
         fdb   FLDABX-*-2
         fcb   F$STABX+SysState
         fdb   FSTABX-*-2
         fcb   F$ELink+SysState
         fdb   FELink-*-2
         fcb   F$FModul+SysState
         fdb   FFModul-*-2
         fcb   F$AlHRam+SysState
         fdb   FAlHRam-*-2
         fcb   F$VBlock+SysState
         fdb   FVBlock-*-2
         IFNE  H6309
         fcb   F$DelRAM
         fdb   FDelRAM-*-2
         ENDC
         fcb   $80

* SWI3 vector entry
XSWI3    lda   #P$SWI3    point to SWI3 vector
         fcb   $8C        skip 2 bytes

* SWI vector entry
XSWI     lda   #P$SWI     point to SWI vector
         ldx   <D.Proc     get process pointer
         ldu   a,x         user defined SWI[x]?
         beq   L028E       no, go get option byte
GoUser   lbra  L0E5E       Yes, go call users's routine

* SWI2 vector entry
XSWI2    ldx    <D.Proc     get current process descriptor
         ldu    P$SWI2,x    any SWI vector?
         bne    GoUser      yes, go execute it

* Process software interupts from a user state
* Entry: X=Process descriptor pointer of process that made system call
*        U=Register stack pointer
L028E    ldu    <D.SysSvc   set system call processor to system side
         stu    <D.XSWI2
         ldu    <D.SysIRQ   do the same thing for IRQ's
         stu    <D.XIRQ
         IFNE   H6309
         oim    #SysState,P$State,x   mark process as in system state
         ELSE
*****         pshs   d
         lda    P$State,x
         ora    #SysState
         sta    P$State,x
         ENDC
* copy register stack to process descriptor
         sts    P$SP,x      save stack pointer
         leas   (P$Stack-R$Size),x point S to register stack destination

         leau   R$Size-1,s  point to last byte of destination register stack
         leay  -1,y       point to caller's register stack in $FEE1
         IFNE  H6309
         ldw   #R$Size    size of the register stack
         tfm   y-,u-
         ELSE
         ldb   #R$Size
Loop3    lda   ,y-
         sta   ,u-
         decb
         bne   Loop3
*****         puls  d
         ENDC
         andcc #^IntMasks
         leau  ,s         needed because the TFM is u-, not -u (post, not pre)
* B=function code already from calling process: DON'T USE IT!
         ldx    R$PC,u      get where PC was from process
         leax   1,x         move PC past option
         stx    R$PC,u      save updated PC to process
* execute function call
         ldy    <D.UsrDis   get user dispatch table pointer
         lbsr   L033B       go execute option
         IFNE   H6309
         aim    #^IntMasks,R$CC,u   Clear interrupt flags in caller's CC
         ELSE
         ldb    R$CC,u
         andb   #^IntMasks
         stb    R$CC,u
         ENDC
         ldx    <D.Proc     get current process ptr
         IFNE   H6309
         aim    #^(SysState+TimOut),P$State,x  Clear system & timeout flags
         ELSE
         lda    P$State,x
         anda   #^(SysState+TimOut)
         sta    P$State,x
         ENDC

* Check for image change now, which lets stuff like F$MapBlk and F$ClrBlk
* do the short-circuit thing, too.  Adds about 20 cycles to each system call.
         lbsr  TstImg     it doesn't hurt to call this twice
         lda   P$State,x  get current state of the process
         ora   <P$Signal,x is there a pending signal?
         sta   <D.Quick   save quick return flag
         beq   AllClr     if nothing's have changed, do full checks

DoFull   bsr   L02DA      move the stack frame back to user state
         lbra  L0D80      go back to the process

* add ldu P$SP,x, etc...
AllClr   inc   <D.QCnt
         IFNE  H6309
         aim   #$1F,<D.QCnt
         beq   DoFull     every 32 system calls, do the full check
         ldw   #R$Size    --- size of the register stack
         ldy   #Where+SWIStack  --- to stack at top of memory
         orcc  #IntMasks
         tfm   u+,y+      --- move the stack to the top of memory
         ELSE
         lda   <D.QCnt
         anda  #$1F
         sta   <D.QCnt
         beq   DoFull
         ldb   #R$Size
         ldy   #Where+SWIStack
         orcc  #IntMasks
Loop4    lda   ,u+
         sta   ,y+
         decb
         bne   Loop4
         ENDC
         lbra  BackTo1    otherwise simply return to the user

* Copy register stack from user to system
* Entry: U=Ptr to Register stack in process dsc
L02CB    pshs   cc,x,y,u    preserve registers
         ldb    P$Task,x    get task #
         ldx    P$SP,x      get stack pointer
         lbsr   L0BF3       calculate block offset (only affects A&X)
         leax   -$6000,x    adjust pointer to where memory map will be
         bra    L02E9       go copy it

* Copy register stack from system to user
* Entry: U=Ptr to Register stack in process dsc
L02DA    pshs   cc,x,y,u    preserve registers
         ldb    P$Task,x    get task # of destination
         ldx    P$SP,x      get stack pointer
         lbsr   L0BF3       calculate block offset (only affects A&X)
         leax   -$6000,x    adjust pointer to where memory map will be
         exg    x,y         swap pointers & copy
* Copy a register stack
* Entry: X=Source
*        Y=Destination
*        A=Offset into DAT image of stack
*        B=Task #
L02E9    leau   a,u         point to block # of where stack is
         lda    1,u         get first block
         ldb    3,u         get a second just in case of overlap
         orcc   #IntMasks   shutdown interupts while we do this
         std    >$FFA5      map blocks in
         IFNE   H6309
         ldw    #R$Size     get size of register stack
         tfm    x+,y+       copy it
         ELSE
         ldb    #R$Size
Loop5    lda    ,x+
         sta    ,y+
         decb
         bne    Loop5
         ENDC
         ldx    <D.SysDAT   remap the blocks we took out
         lda    $0B,x
         ldb    $0D,x
         std    >$FFA5
         puls   cc,x,y,u,pc restore & return

* Process software interupts from system state
* Entry: U=Register stack pointer
SysCall  leau   ,s          get pointer to register stack
         lda    <D.SSTskN   Get system task # (0=SYSTEM, 1=GRFDRV)
         clr    <D.SSTskN   Force to System Process
         pshs   a           Save the system task number
         lda    ,u          Restore callers CC register (R$CC=$00)
         tfr    a,cc        make it current
         ldx    R$PC,u      Get my caller's PC register
         leax   1,x         move PC to next position
         stx    R$PC,u      Save my caller's updated PC register
         ldy    <D.SysDis   get system dispatch table pointer
         bsr    L033B       execute system call
         puls   a           restore system state task number
         lbra   L0E2B       return to process

* Entry: X = system call vector to jump to
Sys.Vec  jmp    ,x          execute service call

* Execute system call
* Entry: B=Function call #
*        Y=Function dispatch table pointer (D.SysDis or D.UsrDis)
L033B    lslb               is it a I/O call? (Also multiplys by 2 for offset)
         bcc    L0345       no, go get normal vector
* Execute I/O system calls
         ldx    IOEntry,y   get IOMan vector
* Execute the system call
L034F    pshs   u           preserve register stack pointer
         jsr   [D.SysVec]   perform a vectored system call
         puls   u           restore pointer
L0355    tfr    cc,a        move CC to A for stack update
         bcc    L035B       go update it if no error from call
         stb    R$B,u       save error code to caller's B
L035B    ldb    ,u          get callers CC, R$CC=$00
         IFNE   H6309
         andd   #$2FD0      [A]=H,N,Z,V,C [B]=E,F,I
         orr    b,a         merge them together
         ELSE
         anda   #$2F        [A]=H,N,Z,V,C
         andb   #$D0        [B]=E,F,I
         pshs   b
         ora    ,s+
         ENDC
         sta    ,u          return it to caller, R$CC=$00
         rts

* Execute regular system calls
L0345    clra               clear MSB of offset
         ldx    d,y         get vector to call
         bne    L034F       it's initialized, go execute it
         comb               set carry for error
         ldb    #E$UnkSvc   get error code
         bra    L0355       return with it

         use   freboot.asm

         use   fssvc.asm

         use   flink.asm

         use   fvmodul.asm

         use   ffmodul.asm

         use   fprsnam.asm

         use   fcmpnam.asm

         use   fsrqmem.asm

         use   fallram.asm


         IFNE  H6309
         use   fdelram.asm
         ENDC

         use   fallimg.asm

         use   ffreehb.asm

         use   fdatlog.asm

         use   fld.asm

         IFNE  H6309
         use   fcpymem.asm
         ENDC

         use   fmove.asm

         use   fldabx.asm

         use   falltsk.asm

         use   faproc.asm

* System IRQ service routine
XIRQ     ldx   <D.Proc     get current process pointer
         sts   P$SP,x      save the stack pointer
         lds   <D.SysStk   get system stack pointer
         ldd   <D.SysSvc   set system service routine to current
         std   <D.XSWI2
         ldd   <D.SysIRQ   set system IRQ routine to current
         std   <D.XIRQ
         jsr   [>D.SvcIRQ] execute irq service
         bcc   L0D5B

         ldx   <D.Proc     get current process pointer
         ldb   P$Task,x
         ldx   P$SP,x      get it's stack pointer

         pshs  u,d,cc     save some registers
         leau  ,s         point to a 'caller register stack'
         lbsr  L0C40      do a LDB 0,X in task B
         puls  u,d,cc     and now A ( R$A,U ) = the CC we want

         ora   #IntMasks   disable it's IRQ's
         lbsr  L0C28       save it back
L0D5B    orcc  #IntMasks   shut down IRQ's
         ldx   <D.Proc     get current process pointer
         tst   <D.QIRQ    was it a clock IRQ?
         lbne  L0DF7      if not, do a quick return

         lda   P$State,x   Get it's state
         bita  #TimOut     Is it timed out?
         bne   L0D7C       yes, wake it up
* Update active process queue
         ldu   #(D.AProcQ-P$Queue) point to active process queue
         ldb   #Suspend    get suspend flag
L0D6A    ldu   P$Queue,u   get a active process pointer
         beq   L0D78
         bitb  P$State,u   is it suspended?
         bne   L0D6A       yes, go to next one in chain
         ldb   P$Prior,x   get current process priority
         cmpb  P$Prior,u   do we bump this one?
         blo   L0D7C

L0D78    ldu   P$SP,x
         bra   L0DB9

L0D7C    anda  #^TimOut
         sta   P$State,x

L0D80    equ   *
L0D83    bsr   L0D11       activate next process

         use   fnproc.asm

* The following routines must appear no earlier than $E00 when assembled, as
* they have to always be in the vector RAM page ($FE00-$FEFF)

* Default routine for D.SysIRQ
S.SysIRQ lda   <D.SSTskN      Get current task's GIME task # (0 or 1)
         beq   FastIRQ        Use super-fast version for system state
         clr   <D.SSTskN      Clear out memory copy (task 0)
         jsr   [>D.SvcIRQ]    (Normally routine in Clock calling D.Poll)
         inc   <D.SSTskN      Save task # for system state
         lda   #1             Task 1
         ora   <D.TINIT       Merge task bit's into Shadow version
         sta   <D.TINIT       Update shadow
         sta   >DAT.Task      Save to GIME as well & return
         bra   DoneIRQ        Check for error and exit

FastIRQ  jsr   [>D.SvcIRQ]    (Normally routine in Clock calling D.Poll)
DoneIRQ  bcc   L0E28          No error on IRQ, exit
         IFNE  H6309
         oim   #IntMasks,0,s  Setup RTI to shut interrupts off again
         ELSE
         lda   ,s
         ora   #IntMasks
         sta   ,s
         ENDC
L0E28    rti

* return from a system call
L0E29    clra                Force System task # to 0 (non-GRDRV)
L0E2B    ldx   <D.SysPrc     Get system process dsc. ptr
         lbsr  TstImg        check image, and F$SetTsk (PRESERVES A)
         orcc  #IntMasks     Shut interrupts off
         sta   <D.SSTskN     Save task # for system state
         beq   Fst2          If task 0, skip subroutine
         ora   <D.TINIT      Merge task bit's into Shadow version
         sta   <D.TINIT      Update shadow
         sta   >DAT.Task     Save to GIME as well & return
Fst2     leas  ,u            Stack ptr=U & return
         rti

* Switch to new process, X=Process descriptor pointer, U=Stack pointer
L0E4C    equ    *
         IFNE   H6309
         oim    #$01,<D.TINIT switch GIME shadow to user state
         lda    <D.TINIT
         ELSE
         lda    <D.TINIT
         ora    #$01
         sta    <D.TINIT
         ENDC
         sta    >DAT.Task  save it to GIME
         leas   ,y          point to new stack
         tstb             is the stack at SWISTACK?
         bne   MyRTI      no, we're doing a system-state rti

         IFNE  H6309
         ldf   #R$Size    E=0 from call to L0E8D before
         ldu   #Where+SWIStack point to the stack
         tfm   u+,y+      move the stack from top of memory to user memory
         ELSE
         ldb   #R$Size
         ldu   #Where+SWIStack point to the stack
RtiLoop  lda   ,u+
         sta   ,y+
         decb
         bne   RtiLoop
         ENDC
MyRTI    rti                return from IRQ

* Execute routine in task 1 pointed to by U
* comes from user requested SWI vectors
L0E5E    equ    *
         IFNE   H6309
         oim    #$01,<D.TINIT switch GIME shadow to user state
         ldb    <D.TINIT
         ELSE
         ldb    <D.TINIT
         orb    #$01
         stb    <D.TINIT
         ENDC
         stb    >DAT.Task
         jmp    ,u

* Flip to task 1 (used by GRF/WINDInt to switch to GRFDRV) (pointed to 
*  by <D.Flip1). All regs are already preserved on stack for the RTI
S.Flip1  ldb    #2          get Task image entry numberx2 for Grfdrv (task 1)
         bsr    L0E8D       copy over the DAT image
         IFNE   H6309
         oim    #$01,<D.TINIT
         lda    <D.TINIT    get copy of GIME Task side
         ELSE
         lda    <D.TINIT
         ora    #$01
         sta    <D.TINIT
         ENDC
         sta    >DAT.Task   save it to GIME register
         inc    <D.SSTskN   increment system state task number
         rti                return

* Setup MMU in task 1, B=Task # to swap to, shifted left 1 bit
L0E8D    cmpb  <D.Task1N  are we going back to the same task
         beq   L0EA3      without the DAT image changing?
         stb   <D.Task1N  nope, save current task in map type 1
         ldx   #$FFA8      get MMU start register for process's
         ldu   <D.TskIPt   get task image pointer table
         ldu   b,u         get address of DAT image
L0E93    leau  1,u         point to actual MMU block
         IFNE  H6309
         lde   #4          get # banks/2 for task
         ELSE
         lda   #4
         pshs  a
         ENDC
L0E9B    lda   ,u++        get a bank
         ldb   ,u++        and next one
         std   ,x++        Save it to MMU
         IFNE  H6309
         dece              done?
         ELSE
         dec   ,s
         ENDC
         bne   L0E9B       no, keep going
         IFEQ  H6309
         leas  1,s
         ENDC
L0EA3    rts               return

* Execute SWI3 vector
* Execute FIRQ vector
FIRQVCT  ldx    #D.FIRQ     get DP offset of vector
         bra    L0EB8       go execute it

* Execute IRQ vector
IRQVCT   orcc   #IntMasks   disasble IRQ's
         ldx    #D.IRQ      get DP offset of vector
* Execute interrupt vector, B=DP Vector offset
L0EB8    clra               (faster than CLR >$xxxx)
         sta    >DAT.Task   Force to Task 0 (system state)
         IFNE   H6309
         tfr    0,dp        setup DP
         ELSE
         tfr    a,dp
         ENDC
MapGrf   equ    *
         IFNE   H6309
         aim    #$fe,<D.TINIT switch GIME shadow to system state
         lda    <D.TINIT    set GIME again just in case timer is used
         ELSE
         lda    <D.TINIT
         anda   #$FE
         sta    <D.TINIT
         ENDC
MapT0    sta    >DAT.Task
         jmp    [,x]        execute it

SWI3VCT  orcc   #IntMasks   disable IRQ's
         ldx    #D.SWI3     get DP offset of vector
         bra    SWICall     go execute it

* Execute SWI2 vector
SWI2VCT  orcc   #IntMasks   disasble IRQ's
         ldx    #D.SWI2     get DP offset of vector

* saves 1 cycle on system-system calls
* saves about 200 cycles (calls to I.LDABX and L029E) on grfdrv-system,
*  or user-system calls.
SWICall  ldb   [R$PC,s]   --- get callcode of the system call
         clr   >DAT.Task  go to map type 1
         IFNE  H6309
         tfr   0,dp       set DP to zero
         ELSE
         clra
         tfr   a,dp
         ENDC

* These lines add a total of 81 addition cycles to each SWI(2,3) call,
* and 36 bytes+12 for R$Size in the constant page at $FExx
*  It takes no more time for a SWI(2,3) from system state than previously,
* ... and adds 14 cycles to each SWI(2,3) call from grfdrv... not a problem.
* For processes that re-vector SWI, SWI3, it adds 81 cycles.  BUT SWI(3)
* CANNOT be vectored to L0EBF cause the user SWI service routine has been
* changed
         lda   <D.TINIT   get map type flag
         bita  #$01       check it without changing it

* Change to LBEQ R.SysSvc to avoid JMP [,X]
* and add R.SysSvc STA >DAT.Task ???
         beq   MapT0      in map 0: restore hardware and do system service
         tst   <D.SSTskN  get system state 0,1
         bne   MapGrf     if in grfdrv, go to map 0 and do system service

* the preceding few lines are necessary, as all SWI's still pass thru
* here before being vectored to the system service routine... which
* doesn't copy the stack from user state.
         sta   >DAT.Task  go to map type X again to get user's stack
* a byte less, a cycle more than ldy #$FEED-R$Size, or ldy #$F000+SWIStack
         leay  <SWIStack,pc where to put the register stack: to $FEDF
         tfr   s,u        get a copy of where the stack is
         IFNE  H6309
         ldw   #R$Size    get the size of the stack
         tfm   u+,y+      move the stack to the top of memory
         ELSE
         pshs  b
         ldb   #R$Size
Looper   lda   ,u+
         sta   ,y+
         decb
         bne   Looper 
         puls  b
         ENDC
         bra   L0EB8      and go from map type 1 to map type 0

* Execute SWI vector
SWIVCT   ldx    #D.SWI      get DP offset of vector
         bra    SWICall     go execute it

* Execute NMI vector
NMIVCT   ldx    #D.NMI      get DP offset of vector
         bra    L0EB8       go execute it

         emod
eom      equ   *

*SWIStack fcc   /REGISTER STACK/ R$Size data bytes
SWIStack fcb   $88,$03,$00
         IFNE  H6309
         fcb   $45,$72
         ENDC
         fcb   $00,$cd,$00,$12,$00,$00,$00,$e5,$7f

         fcb   $55        D.ErrRst

* Now bra instead of lbra since 2 cycles/interrupt faster
         bra  SWI3VCT      SWI3 vector
         nop
         bra  SWI2VCT      SWI2 vector
         nop
         bra  FIRQVCT      FIRQ vector
         nop
         bra  IRQVCT       IRQ vector
         nop
         bra  SWIVCT       SWI vector
         nop
         bra  NMIVCT       NMI vector
         nop

         end


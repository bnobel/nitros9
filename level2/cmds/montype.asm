********************************************************************
* MonType - Change monitor type
*
* $Id$
*
* Ed.    Comments                                       Who YY/MM/DD
* ------------------------------------------------------------------
* 1      Original Tandy/Microware version
* 2      Modified to require dash before option         BGP 03/01/20
* 3      Fixed a bug where a non dash option would      BGP 03/03/10
*        crash the system.  Also shows the monitor
*        type when no parameters are passed.
* 4      Made dash optional to accept parameters as     RVH 03/05/27
*        args or options, streamlined code flow.

         nam   MonType
         ttl   Change monitor type

         ifp1
         use   defsfile
         endc

tylg     set   Prgrm+Objct   
atrv     set   ReEnt+rev
rev      set   $00
edition  set   4

         mod   eom,name,tylg,atrv,start,size

         org   0
         rmb   300
size     equ   .

name     fcs   /MonType/
         fcb   edition

         IFNE  DOHELP
HelpMsg  fcb   C$CR
         fcb   C$LF
         fcc   "MonType - Set up the monitor type"
         fcb   C$CR
         fcb   C$LF
         fcc   "Syntax:  MonType [opt]"
         fcb   C$CR
         fcb   C$LF
         fcc   "Options: -r = rgb monitor"
         fcb   C$CR
         fcb   C$LF
         fcc   "         -c = composite monitor (TV)"
         fcb   C$CR
         fcb   C$LF
         fcc   "         -m = monochrome monitor"
         fcb   C$CR
         fcb   C$LF
HelpMsgL equ   *-HelpMsg
         ENDC

TypeMsg  fcc   /Current setting: /
TypeMsgL equ   *-TypeMsg
TypeTbl  fcb   CMPType-TypeTbl
         fcb   RGBType-TypeTbl
         fcb   MonoType-TypeTbl

RGBType  fcc   /RGB/
         fcb   C$CR
CMPType  fcc   /Composite/
         fcb   C$CR
MonoType fcc   /Monochrome/
         fcb   C$CR

CurOn    fdb   $1B21

start    equ   *
SkipSpcs lda   ,x+
         cmpa  #C$SPAC
         beq   SkipSpcs
         cmpa  #'-		dash option flag
         beq   SkipSpcs

         anda  #$5F		make uppercase
         clrb			type=0
         cmpa  #'C		Composite?
         beq   SetMType
         incb			type=1
L00C7    cmpa  #'R		RGB?
         beq   SetMType
         incb			type=2
L00D0    cmpa  #'M		Monochrome?
         beq   SetMType

         IFNE  DOHELP
         cmpa  #C$CR		if no arg, show type
         bne   ShowHelp		unknown arg, do help
         ENDC

ShowMTyp lda   #1		standard out
         ldb   #SS.Montr	monitor type
         os9   I$GetStt 	get it!
         bcs   Exit
         pshs  x 
         leax  <TypeMsg,pcr
         ldy   #TypeMsgL
         os9   I$Write
         puls  d
         leax  <TypeTbl,pcr
         ldb   b,x
         abx 
         lda   #1
         ldy   #80
         os9   I$WritLn
         bra   ExitOk

SetMType ldx   #$0000
         abx			set monitor type
         lda   #1		standard output
         ldb   #SS.Montr	monitor setstat
         os9   I$SetStt 	do it!
         bcs   Exit		branch if error
         leax  <CurOn,pcr	point to cursor on
         lda   #1		to stdout
         ldy   #2		two bytes
         os9   I$Write  	write it!
         bcs   Exit		branch if error
ExitOk   clrb  
Exit     os9   F$Exit   

         IFNE  DOHELP
ShowHelp lda   #1
         leax  >HelpMsg,pcr
         ldy   #HelpMsgL
         os9   I$Write  
         bra   ExitOk
         ENDC

         emod
eom      equ   *
         end

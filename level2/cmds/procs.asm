********************************************************************
* Procs - Show process information
*
* $Id$
*
* Ed.    Comments                                       Who YY/MM/DD
* ------------------------------------------------------------------
* 14     Original Tandy/Microware version

         nam   Procs
         ttl   program module       

* Disassembled 98/09/11 17:07:20 by Disasm v1.6 (C) 1988 by RML

         ifp1
         use   defsfile
         endc

tylg     set   Prgrm+Objct   
atrv     set   ReEnt+rev
rev      set   $01
edition  set   14

         mod   eom,name,tylg,atrv,start,size

u0000    rmb   1
u0001    rmb   1
u0002    rmb   1
u0003    rmb   1
u0004    rmb   1
u0005    rmb   1
u0006    rmb   2
u0008    rmb   1
u0009    rmb   1
u000A    rmb   32
u002A    rmb   58
u0064    rmb   22
u007A    rmb   110
u00E8    rmb   1164
size     equ   .

name     fcs   /Procs/
         fcb   edition
L0013    fcs   "         User                     Mem Stack"
L003E    fcs   "Id  PId Number  Pty Age Sts Signl Siz  Ptr   Primary Module"
L0079    fcs   "--- --- ------- --- --- --- ----- --- ----- ----------------"
L00B5    fcs   "Id  PId  User#  Pty  Age  Sts"
L00D2    fcs   " Sigl  Mem    StPtr   Primary"
L00EF    fcs   "============================="
L010C    fcs   "DEAD"

start    clr   <u0000
         clr   <u0002
         lda   #$01
         sta   <u0001
         lda   ,x+
         eora  #'E
         anda  #$DF
         bne   L0122
         inc   <u0000
L0122    leax  <u002A,u
         stx   <u0006
         leax  <u007A,u
         os9   F$GBlkMp 
         tfr   a,b
         nega  
         sta   <u0008
         lda   #$FE
L0134    inca  
         lsrb  
         bne   L0134
         sta   <u0009
         os9   F$ID     
         sty   <u0003
         lbsr  L024F
         lda   #$01
         ldb   #SS.ScSiz
         os9   I$GetStt 
         bcc   L0154
         cmpb  #E$UnkSvc
         lbne  L0241
         bra   L017B
L0154    cmpx  #$003C
         bge   L017B
         inc   <u0002
         leay  >L00B5,pcr
         lbsr  L0244
         lbsr  L024F
         leay  >L00D2,pcr
         lbsr  L0244
         lbsr  L024F
         leay  >L00EF,pcr
         lbsr  L0244
         lbsr  L024F
         bra   L0199
L017B    leay  >L0013,pcr
         lbsr  L0244
         lbsr  L024F
         leay  >L003E,pcr
         lbsr  L0244
         lbsr  L024F
         leay  >L0079,pcr
         lbsr  L0244
         lbsr  L024F
L0199    inc   <u0001
         lbeq  L0240
         lda   <u0001
         leax  <u007A,u
         os9   F$GPrDsc 
         bcs   L0199
         ldd   <u0003
         cmpd  $08,x
         beq   L01B4
         tst   <u0000
         beq   L0199
L01B4    ldb   ,x
         lbsr  L026F
         lbsr  L0292
         ldb   $01,x
         lbsr  L026F
         lbsr  L0292
         ldd   $08,x
         lbsr  L02C3
         lbsr  L0292
         lbsr  L0292
         lbsr  L0292
         ldb   $0A,x
         lbsr  L026F
         lbsr  L0292
         tst   <u0002
         beq   L01E1
         lbsr  L0292
L01E1    ldb   $0B,x
         lbsr  L026F
         lbsr  L0292
         tst   <u0002
         beq   L01F0
         lbsr  L0292
L01F0    lda   #$24
         lbsr  L0296
         lda   $0C,x
         lbsr  L02A0
         clra  
         tst   <u0002
         beq   L0202
         lbsr  L024F
L0202    ldb   <$19,x
         lbsr  L02C3
         lbsr  L0292
         lbsr  L0292
         ldb   $07,x
         bsr   L026F
         bsr   L0292
         tst   <u0002
         beq   L021E
         bsr   L0292
         bsr   L0292
         bsr   L0292
L021E    lda   #$24
         bsr   L0296
         lda   $04,x
         bsr   L02A0
         lda   $05,x
         bsr   L02A0
         bsr   L0292
         tst   <u0002
         beq   L0234
         bsr   L0292
         bsr   L0292
L0234    lbsr  L02FA
         bsr   L0244
         bsr   L0292
         bsr   L024F
         lbra  L0199
L0240    clrb  
L0241    os9   F$Exit   
L0244    lda   ,y
         anda  #$7F
         bsr   L0296
         lda   ,y+
         bpl   L0244
         rts   
L024F    pshs  y,x,a
         lda   #C$CR
         bsr   L0296
         leax  <u002A,u
         stx   <u0006
         tst   <u0002
         beq   L0264
         ldy   #$0020
         bra   L0268
L0264    ldy   #80
L0268    lda   #$01
         os9   I$WritLn 
         puls  pc,y,x,a
L026F    clr   <u0005
         lda   #$FF
L0273    inca  
         subb  #$64
         bcc   L0273
         bsr   L0289
         lda   #$0A
L027C    deca  
         addb  #$0A
         bcc   L027C
         bsr   L0289
         tfr   b,a
         adda  #$30
         bra   L0296
L0289    tsta  
         beq   L028E
         sta   <u0005
L028E    tst   <u0005
         bne   L0294
L0292    lda   #$F0
L0294    adda  #$30
L0296    pshs  x
         ldx   <u0006
         sta   ,x+
         stx   <u0006
         puls  pc,x
L02A0    pshs  a
         anda  #$F0
         lsra  
         lsra  
         lsra  
         lsra  
         bsr   L02AE
         puls  a
         anda  #$0F
L02AE    adda  #$30
         cmpa  #$39
         bls   L0296
         adda  #$07
         bra   L0296
L02B8    fdb   $2710,$03e8,$0064,$000a
         fcb   $00,$01,$ff

L02C3    pshs  y,x,b,a
         leax  <L02B8,pcr
         ldy   #$2F20
L02CC    leay  >$0100,y
         subd  ,x
         bcc   L02CC
         addd  ,x++
         pshs  b,a
         tfr   y,d
         tst   ,x
         bmi   L02F4
         ldy   #$2F30
         cmpd  #$3020
         bne   L02EE
         ldy   #$2F20
         lda   #$20
L02EE    bsr   L0296
         puls  b,a
         bra   L02CC
L02F4    bsr   L0296
         leas  $02,s
         puls  pc,y,x,b,a
L02FA    pshs  u,x
         leay  >L010C,pcr
         lda   $0C,x
         bita  #$01
         bne   L0330
         leay  <$40,x
         tfr   y,d
         ldx   <$11,x
         ldy   #$0009
         leau  u000A,u
         os9   F$CpyMem 
         pshs  b,a
         ldd   u0004,u
         leax  d,x
         puls  b,a
         ldy   #$0020
         os9   F$CpyMem 
         leay  ,u
         lda   <$1F,y
         ora   #$80
         sta   <$1F,y
L0330    puls  pc,u,x

         emod
eom      equ   *
         end


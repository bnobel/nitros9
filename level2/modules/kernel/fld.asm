**************************************************
* System Call: F$LDAXY
*
* Function: Load A [X,[Y]]
*
* Input:  X = Block offset
*         Y = DAT image pointer
*
* Output: A = data byte at X offset of Y
*
* Error:  CC = C bit set; B = error code
*
FLDAXY   ldx   R$X,u          Get offset within block (S/B $0000-$1FFF)
         ldy   R$Y,u          Get ptr to DAT block entry
         bsr   L0AC8          Go get byte
         sta   R$A,u          Save in caller's A reg.
         rts

* Entry: X=offset ($0000-$1fff) to get from block pointed to by Y (DAT entry
* format)
L0AC8    lda   1,y            Get MMU block # to get data from
         clrb                 Clear carry/setup for STB
         pshs  cc             Preserve interrupt status/settings
         orcc  #IntMasks      shut IRQ's off
       IFNE  mc09
         ldb   <D.TINIT       Current MMU mask - selects block 0
         stb   >MMUADR        Select block 0
         sta   >MMUDAT        Map block into $0000-$1FFF
         lda   ,x             Get byte
         clrb
         stb   >MMUDAT        Map block 0 into $0000-$1FFF
       ELSE
         sta   >DAT.Regs      Map block into $0000-$1FFF
         IFNE  H6309
         brn    L0AC8         short delay
         ENDC
         lda   ,x             Get byte
         stb   >DAT.Regs      Map block 0 into $0000-$1FFF
         IFNE  H6309
         brn    L0AC8         short delay
         ENDC
       ENDC
         puls  pc,cc          Get interrupt status/(or turn on) & return

* Get 1st byte of LDDDXY - also used by many other routines
* Increments X on exit; adjusts X for within 8K block & Y (DAT img ptr)
LDAXY    lda   1,y            Get MMU block #
         pshs  b,cc
         clrb                 Clear carry/setup for STB
         orcc  #IntMasks      Shut off interrupts
       IFNE  mc09
         ldb   <D.TINIT       Current MMU mask - selects block 0
         stb   >MMUADR        Select block 0
         sta   >MMUDAT        Map in MMU block into slot 0
         lda   ,x+            Get byte
         clrb
         stb   >MMUDAT        Map block 0 back in
       ELSE
         sta   >DAT.Regs      Map in MMU block into slot 0
         lda   ,x+            Get byte
         stb   >DAT.Regs
       ENDC
*         clr   >DAT.Regs     Map in MMU block #0 into slot 0
*         andcc #^IntMasks
         puls  b,cc
         bra   AdjBlk0

L0AEA    leax  >-DAT.BlSz,x   Bump offset ptr to start of block again
         leay  2,y            Bump source MMU block up to next one in DAT Image
AdjBlk0  cmpx  #DAT.BlSz      Going to wrap out of our block?
         bhs   L0AEA          Yes, go adjust
         rts                  No, return


**************************************************
* System Call: F$LDDXY
*
* Function: Load D [D+X,[Y]]
*
* Input:  D = Offset to offset
*         X = Offset
*         Y = DAT image pointer
*
* Output: D = bytes address by [D+X,Y]
*
* Error:  CC = C bit set; B = error code
*
FLDDDXY  ldd   R$D,u          Get offset to offset within DAT Image
         leau  R$X,u          Point U to Offset
         pulu  x,y            Y=Offset within DAT Image, X=DAT Image ptr
         bsr   L0B02          Go get 2 bytes
         std   -(R$X+3),u     Save into caller's X
         clrb                 No error & return
         rts

* Get 2 bytes for LDDDXY (also called by other routines)
* Should simply map in 2 blocks, and do a LDD (don't have to worry about wrap)
       IFNE  mc09
L0B02    pshs  u,y,x,dp       Preserve regs (x, y adjusted by AdjBlk0)
       ELSE
L0B02    pshs  u,y,x          Preserve regs (x, y adjusted by AdjBlk0)
       ENDC

       IFNE  H6309
         addr  d,x            Point X to X+D
       ELSE
         leax  d,x
       ENDC
         bsr   AdjBlk0        Wrap address around for 1 block
         ldu   <D.SysDAT      Get sys DAT Image ptr
         clra                 system block 0 =0 always
         ldb   3,u            Get MMU block #1
         tfr   d,u            make U=blocks to re-map in once done
         lda   1,y            Get MMU block #0
         ldb   3,y            Get MMU block #1
         pshs  cc             Preserve int. status
         orcc  #IntMasks      shut off int.
       IFNE  mc09
         lda   <D.TINIT       Current MMU mask - selects block 0
         inca                 Select block 1

         ldb   1,y            Get MMU block #0
         tfr   b,dp           Save it for later
         ldb   3,u            Get restore value for MMU block #1
         tfr   d,u            Save it for later

         ldb   3,y            Get MMU block #1
         std   >MMUADR        Set address and block 1

         deca                 Select block 0
         tfr   dp,b
         std   >MMUADR        Set address and block 0

         ldy   ,x             Get 2 bytes

         tfr   u,d
         std   >MMUADR        Restore original MMU block #1
         deca                 Select block 0
         clrb                 system block 0 =0 always
         std   >MMUADR        Restore original MMU block #0

         tfr   y,d            Put the data in the right place
         puls  pc,u,y,x,dp,cc Restore regs & return
       ELSE
         std   >DAT.Regs      Map in both blocks
         ldd   ,x             Get 2 bytes
         stu   >DAT.Regs      Map original blocks in
         puls  pc,u,y,x,cc    Restore regs & return
       ENDC

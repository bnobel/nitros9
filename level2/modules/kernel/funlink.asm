**************************************************
* System Call: F$UnLink
*
* Function: Unlink a module
*
* Input:  U = Address of module header
*
* Output: None
*
* Error:  CC = C bit set; B = error code
*
FUnLink  pshs   d,u         preserve register stack pointer and make a buffer
         ldd    R$U,u       get pointer to module header
         tfr    d,x         copy it to X
         lsra               divide MSB by 32 to get DAT block offset
         lsra
         lsra
         lsra
         lsra
         sta    ,s          save DAT block offset
         lbeq   L01D0       zero, can't use so exit
         ldu    <D.Proc     get pointer to current process
         leay   P$DATImg,u  point Y to it's DAT image
         lsla               account for 2 bytes/entry
         ldd    a,y         get block #
         ldu    <D.BlkMap   get pointer to system block map
         IFNE   H6309
         tim    #ModBlock,d,u   Is memory block a module type?
         ELSE
         ldb    d,u
         bitb   #ModBlock
         ENDC
         beq    L01D0       no, exit without error
         leau   (P$Links-P$DATImg),y  point to block link counts
         bra    L0161       go unlink block

L015D    dec    ,s          we done?
         beq    L01D0       yes, go on
L0161    ldb    ,s          get current offset
         lslb               account for 2 bytes entry
         ldd    b,u         get block link count
         beq    L015D       already zero, get next one
         lda    ,s          get block offset
         lsla               find offset into 64k map by multiplying by 32
         lsla
         lsla
         lsla
         lsla
         clrb
         nega
         IFNE   H6309
         addr   d,x
         ELSE
         leax   d,x
         ENDC
         ldb    ,s          get block offset
         lslb               account for 2 bytes/entry
         ldd    b,y         get block #
         ldu    <D.ModDir   get module directory pointer
         bra    L0185       go look for it

* Main module directory search routine
L017C    leau   MD$ESize,u  move to next module entry
         cmpu   <D.ModEnd   done entire directory?
         bhs    L01D0       Yes, exit
L0185    cmpx   MD$MPtr,u   is module pointer the same?
         bne    L017C       no, keep looking
         cmpd   [MD$MPDAT,u] DAT match?
         bne    L017C       no, keep looking
* Module is found decrement link count
* NOTE: COULD WE USE D?
*   L0198 - Safe, destroys D immediately
*   Fall through- safe, destroys D immediately
*   L01B5 - Seems to be safe
         ldd    MD$Link,u   get module link count
         beq    L0198       it's zero, go unlink it
         IFNE   H6309
         decd               decrement link count
         ELSE
         subd   #$0001
         ENDC
         std    MD$Link,u   save it back
         bne    L01B5       go on
* Module link count is zero check if he's unlinking a I/O module
L0198    ldx    2,s         get pointer to register stack
         ldx    R$U,x       get pointer to module
         ldd    #M$Type     get offset to module type
         os9    F$LDDDXY    get module type
         cmpa   #FlMgr      is it a I/O module?
         blo    L01B3       no, don't process for I/O
         os9    F$IODel     device still being used by somebody else?
         bcc    L01B3       no, go on
         ldd    MD$Link,u   put the link count back to where it was
         IFNE   H6309
         incd
         ELSE
         addd   #$0001
         ENDC
         std    MD$Link,u
         bra    L01D1       return error
* Clear module from memory
L01B3    bsr    DelMod      delete module from memory & module dir
L01B5    ldb    ,s          get block
         lslb               account for 2 bytes/entry
         leay   b,y         point to block
         ldd    (P$Links-P$DATImg),y get block link count
         IFNE   H6309
         decd               decrement it
         ELSE
         subd   #$0001
         ENDC
         std    (P$Links-P$DATImg),y save new link count
         bne    L01D0       not zero, return to user
* Clear module blocks in process DAT image
         ldd    MD$MBSiz,u  get block size
         bsr    L0226       calculate # blocks to delete
         ldx    #DAT.Free   get DAT free marker
L01CB    stx    ,y++        save it in DAT image
         deca               done?
         bne    L01CB       no, keep going
L01D0    clrb               clear errors
L01D1    leas   2,s         purge local data
         puls   u,pc        restore & return

* Delete module from module directory & from memory
* Entry: U=Module directory entry pointer to delete
* Exit : None
DelMod   ldx    <D.BlkMap   get pointer to memory block map
         ldd    [MD$MPDAT,u] get pointer to module DAT image
         lda    d,x         is block type ROM?
         bmi    L0225       yes can't delete it, return
         ldx    <D.ModDir   get pointer to module directory
L01DF    ldd    [MD$MPDAT,x] get offset to DAT
         cmpd   [MD$MPDAT,u] match what we're looking for?
         bne    L01EA       no, keep looking
         ldd    MD$Link,x   get module link count
         bne    L0225       not zero, return
L01EA    leax   MD$ESize,x  move to next module
         cmpx   <D.ModEnd   at the end?
         bcs    L01DF       no, keep going
         ldx    <D.BlkMap   get pointer to block map
         ldd    MD$MBSiz,u  get memory block size
         bsr    L0226       calculate # blocks to clear
         IFNE   H6309
         pshs   u           Preserve U (faster than original Y below)
         clrb               Setup for faster block in use clears
         ldu    MD$MPDAT,u  get pointer to module DAT image
L01FB    ldw    ,u++        Get first block
         stb    -2,u        clear it in DAT image
         stb    -1,u
         addr   x,w         point to block in block map
         aim    #^(ModBlock!RAMinUse),,w
         deca
         bne    L01FB
         puls   u           Restore module ptr
         ELSE
         pshs  y            save y
         ldy   MD$MPDAT,u   module image ptr
L01FB    pshs  a,x          save #blocks, ptr
         ldd   ,y           get block number
         clr   ,y+          clear the image
         clr   ,y+
         leax  d,x          point to blkmap entry
         ldb   ,x
         andb  #^(RAMinUse+ModBlock) free block
         stb   ,x
         puls  a,x
         deca               last block done?
         bne   L01FB        ..no, loop
         puls  y
         ENDC
         ldx    <D.ModDir   get module directory pointer
         ldd    MD$MPDAT,u  get module DAT pointer
L0216    cmpd   MD$MPDAT,x  match?
         bne    L021F       no, keep looking
         clr    MD$MPDAT,x  clear module DAT image pointer
         clr    MD$MPDAT+1,x
L021F    leax   MD$ESize,x  point to next module entry
         cmpx   <D.ModEnd   at the end?
         blo    L0216       no, keep looking
L0225    rts                return

L0226    addd   #$1FFF      round up to nearest block
         lsra               calculate block # within 64k workspace
         lsra
         lsra
         lsra
         lsra
         rts

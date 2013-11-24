	opt	w132	wide listing
********************************************************************
* Boot - SCSI Boot Module
*
* $Id$
*
* This module allows booting from a hard drive that uses HDB-DOS
* and is controlled by a TC^3, Ken-Ton or Disto SCSI controller.
*
* It was later modified to handle hard drives with sector sizes
* larger than 256 bytes, and works on both 256 byte and larger drives,
* so it should totally replace the old SCSI boot module.
*
* Instructions followed by +++ in the comment field were added for this fix.
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      ????/??/??  Roger Krupski
* Original Roger Krupski distribution version
*
*   1r1    1996/??/??  Boisy G. Pitre
* Added code to allow booting from any sector size hard drive
*
*   1r2    2002/05/01  Boisy G. Pitre
* Merged Ken-Ton and TC^3 module source
*
*   1r3    2002/07/22  Boisy G. Pitre
* Outputs '.' for each sector read when booting under NitrOS-9
*
*   2      2004/07/30  Boisy G. Pitre
* SCSI ID 0-7 now modifiable at end of module as well as base address
*
*   3      2005/10/09  Boisy G. Pitre
* Fixed stupid mistake where SCSIDATA was set to base address.  Now
* baseaddr is the base address set at the end of the module and SCSIDATA
* is 0 for the data offset.
* Also SCSI-3 compatible SCSI IDs (with hi-bit set) are now sent to bus which
* causes the booter to work with IBM-DPES31080 and other newer hard drives.
* Fragmented bootfiles are now supported.
*
*   4      2008/02/17  Boisy G. Pitre
* Message phase code was broken, now fixed and the booter now works.
*
*   5      2012/11/05-06  Gene Heskett
* SDMPI from defs/scsi.d is being ignored, so boot failed is the message.
* Ded the object to fix that AND the NULL bus address and this code broken.
* WhichDrv is now a zero based decimal value passed in by the makefile via ITDNS
* Thanks Boisy...
               NAM       Boot                
               TTL       SCSI Boot Module    

               IFP1      
               USE       defsfile
               USE       rbsuper.d
               USE       scsi.d
               ENDC      

tylg           SET       Systm+Objct
atrv           SET       ReEnt+rev
rev            SET       1
edition        SET       4

               MOD       eom,name,tylg,atrv,start,size

SCSIEX         EQU       1

* Data equates; subroutines must keep data in stack
               IFNE      SCSIEX
v$cmd          RMB       1
v$extra        RMB       1
v$addr0        RMB       1
v$addr1        RMB       1
v$addr2        RMB       1
v$addr3        RMB       1
v$resv         RMB       1
v$blks0        RMB       1
v$blks1        RMB       1
v$ctrl         RMB       1
               ELSE
v$cmd          RMB       1
v$addr0        RMB       1
v$addr1        RMB       2
v$blks         RMB       1
v$opts         RMB       1
			   ENDC
seglist        RMB       2                   pointer to segment list
blockloc       RMB       2                   pointer to memory requested
blockimg       RMB       2                   duplicate of the above
bootloc        RMB       3                   sector pointer; not byte pointer
bootsize       RMB       2                   size in bytes
LSN0Ptr        RMB       2                   LSN0 pointer (used by boot_common.asm)
size           EQU       .

name           FCS       /Boot/
               FCB       edition

* Common booter-required defines
LSN24BIT       EQU       1
FLOPPY         EQU       0


               USE       boot_common.asm

************************************************************
************************************************************
*              Hardware-Specific Booter Area               *
************************************************************
************************************************************                         

* HWInit - Initialize the device
*   Entry: Y = hardware address
*   Exit:  Carry Clear = OK, Set = Error
*          B = error (Carry Set)
HWInit                   
               clr       >$FF40              stop the disk motors
*               IFNE      D4N1+HDII ??????
		IFNE	MPI
        	leax      CntlSlot,pcr point at byte with MPI slot in it
        	lda       ,x	get it
        	sta       MPI.Slct and set the MPI to us.
        	ENDC      But this was NOT being done.
        	ldd       #S$SEEK*256
        	ldx       #0
        	bsr       setup
        	IFEQ      SCSIEX
		clr       v$blks,u
		ENDC
        	bra       command
			
* Sets up the SCSI packet to send
* Destroys B
setup          sta       v$cmd,u
               IFNE      SCSIEX
			   clr       v$extra,u
               clr       v$addr0,u
               stb       v$addr1,u
               stx       v$addr2,u
               clr       v$resv,u
               clr       v$blks0,u
               ldb       #1
               stb       v$blks1,u
               clr       v$ctrl,u
               ELSE
               stb       v$addr0,u
               stx       v$addr1,u
               ldb       #1
               stb       v$blks,u
               clr       v$opts,u
			   ENDC
               rts

* Sooooo, at end of module, the FF64XX, the XX is not a marching bit
* pattern any more.  Cool but a huge gotcha needing makefile changes
* all over.  And theres too many of them.

scsival        FCB       $80+1,$80+2,$80+4,$80+8,$80+16,$80+32,$80+64,$80

* SCSI Wake-Up Routine
* Destroys: X
wakeup         ldx       #0                  load X with 0 (counter)
* Step 1: Wait for BUSY+SEL to be clear
wake           lda       SCSISTAT,y          obtain SCSI status byte
               bita      #BUSY               BUSY clear?
               beq       wake1               branch if so
               leax      -1,x                else count down
               bne       wake                and try again if not timed out
               bra       wake4               else branch to timeout
* Aha!  New code! so ITDRV goes down one count
* Nice we get a notice.  ChangeLog's would be nice
* But are a pain in the ass to maintain.

* Step 2: Put our SCSI ID on the bus
wake1          bsr       wake3               small delay
               lda       WhichDrv,pcr        get SCSI ID
               leax      <scsival,pcr        point to SCSI value table
               lda       a,x                 get appropriate bitmask
               sta       SCSIDATA,y          put on SCSI bus
               bsr       wake3               small delay
               sta       SCSISEL,y           and select
               ldx       #0                  load X with 0 (counter)
wake2          lda       SCSISTAT,y          obtain SCSI status byte
               bita      #BUSY               BUSY set?
               bne       wake3               if so, exit without error
               leax      -1,x                else count down
               bne       wake2               and try again if not timed out
wake4          comb                          set carry
               ldb       #E$NotRdy           and load error
wake3          rts                           then return


* HWRead - Read a 256 byte sector from the device
*   Entry: Y = hardware address
*          B = bits 23-16 of LSN
*          X = bits 15-0  of LSN
*          blockloc,u = ptr to 256 byte sector
*   Exit:  X = ptr to data (i.e. ptr in blockloc,u)
HWRead         lda       #S$READEX
               bsr       setup
* SCSI Send Command Routine
command        bsr       wakeup              tell SCSI we want the bus
               bcs       wake3              return immediately if error
               leax      v$cmd,u
               bsr       SCSISend
               bcs       command
               bsr       Wait4REQ
               bita      #CMD
               bne       getsta
               ldx       blockloc,u
               bsr       read
getsta         bsr       Wait4REQ
               lda       SCSIDATA,y
               anda      #%00001111
               pshs      a
               bsr       Wait4REQ
               clra      
               sta       SCSIDATA,y
               puls      a
               bita      #X$BUSY
               bne       command
               bita      #X$ERROR
               beq       HWTerm
reterr         comb      
               ldb       #E$Unit
               rts       

* HWTerm - Terminate the device
*   Entry: Y = hardware address
*   Exit:  Carry Clear = OK, Set = Error
*          B = error (Carry Set)
HWTerm         clrb      
               rts       

SCSISend       bsr       Wait4REQ
               bita      #CMD
               beq       HWTerm
               bita      #INOUT
               bne       ckmsg
               lda       ,x+
               sta       SCSIDATA,y
               bra       SCSISend
ckmsg          bita      #MSG                MESSAGE IN (target->initiator)
			   beq       HWTerm
               lda       SCSIDATA,y          extended message?
               deca      
*
* MESSAGE IN phase code
*
               bne       SCSISend
               ldb       SCSIDATA,y          get extended message length
l@             tst       SCSIDATA,y          read extended message
               decb      
               bne       l@
               bra       reterr              return with carry set
			   
Wait4REQ
loop@          lda       SCSISTAT,y
               bita      #REQ
               beq       loop@
               rts

* Patch to allow booting from sector sizes > 256 bytes - BGP 08/16/97
* We ignore any bytes beyond byte 256, but continue to read them from
* the SCSIDATA until the CMD bit is set.
read                     
* next 2 lines added
               clrb                          +++ use B as counter
read2                    
               bsr       Wait4REQ
               bita      #CMD
               bne       HWTerm
               lda       SCSIDATA,y
               sta       ,x+
* next line commented out and next 8 lines added
* bra read
               incb                          +++
               bne       read2               +++
               leax      -256,x
read3                    
               bsr       Wait4REQ            +++
               bita      #CMD                +++
               bne       HWTerm              +++
               lda       SCSIDATA,y          +++
               bra       read3               +++


               IFGT      Level-1
* Fillers to get to $1D0
Pad            FILL      $39,$1D0-3-1-2-1-*
               ENDC      
* rev1, add selections for MPI slot and bus address of drive
* 2012\11\05 Gene Heskett
* The default SCSI ID is here, but first do MPI slot
               IFEQ      MPI-1
CntlSlot       FCB       SDMPI
               ELSE
CntrSlot       FCB       $FF
               ENDC
Address        FDB       SDAddr
* So now, this can be a base zero decimal value!
WhichDrv       FCB       ITDNS
               EMOD
eom            EQU       *
               END

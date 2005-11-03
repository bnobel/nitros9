********************************************************************
* Cobbler - Write OS9Boot to a disk
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   7      ????/??/??
* From Tandy OS-9 Level Two VR 02.00.01.
*
*          2002/07/20  Boisy G. Pitre
* Modified source to allow for OS-9 Level One and Level Two assembly.
*
*	   2005/11/03  P.Harvey-Smith.
* Added the ability to assemble for either CoCo or Dragon.
*

         nam   Cobbler
         ttl   Write OS9Boot to a disk

* Disassembled 02/07/06 13:08:41 by Disasm v1.6 (C) 1988 by RML

         IFP1
         use   defsfile
         ENDC

DOHELP   set   0

tylg     set   Prgrm+Objct   
atrv     set   ReEnt+rev
rev      set   $00
edition  set   7

         mod   eom,name,tylg,atrv,start,size

		org   0
lsn0buff 	rmb   26	Buffer to hold data from LSN0 of traget device
newbpath 	rmb   1
devpath  	rmb   3
EndDevName    	rmb   2		pointer to last character of device name when moving to fullbnam
fullbnam 	rmb   20	this buffer hodls the entire name (i.e. /D0/OS9Boot)
u0034    	rmb   16
BootBuf    	rmb   7		Area to read part of current boot area into, to check for boot stuff
u004B    	rmb   2
LSNBitmapByte	rmb   1		Saved byte from bitmap, of current LSN
u004E    	rmb   16
pathopts 	rmb   20
u0072    	rmb   2
u0074    	rmb   10
bffdbuf  	rmb   16
u008E    	rmb   1
u008F    	rmb   7
u0096    	rmb   232
bitmbuf  	rmb   1024
         
		IFGT  Level-1
u057E    	rmb   76
u05CA    	rmb   8316
		ENDC
size     	equ   .

name     fcs   /Cobbler/
         fcb   edition

L0015    fcb   $00 
         fcb   $00 

         IFNE  DOHELP
HelpMsg  fcb   C$LF
         fcc   "Use: COBBLER </devname>"
         fcb   C$LF
         fcc   "     to create a new system disk"
         fcb   C$CR
         ENDC
WritErr  fcb   C$LF
         fcc   "Error writing kernel track"
         fcb   C$CR
         fcb   C$LF
         fcc   "Error - cannot gen to hard disk"
         fcb   C$CR
	 
	IFNE	DRAGON
FileWarn fcb   C$LF
         fcc   "Warning - not a Dragon "
         fcb   C$LF
         fcc   "disk."

	ELSE
FileWarn fcb   C$LF
         fcc   "Warning - file(s) present"
         fcb   C$LF
         fcc   "on track 34 - this track"

	ENDC

         fcb   C$LF
         fcc   "not rewritten."
         fcb   C$CR
BootFrag fcb   C$LF
         fcc   "Error - OS9boot file fragmented"
         fcb   C$CR
         IFGT  Level-1
RelMsg   fcb   C$LF
         fcc   "Error - can't link to Rel module"
         fcb   C$CR
         ENDC
BootName fcc   "OS9Boot "
         fcb   $FF 
RelNam   fcc   "Rel"
         fcb   $FF 

DragonRootSec	equ	$12	Dragon root sector is always LSN 18

start    clrb  				Check first char is a /
         lda   #PDELIM
         cmpa  ,x
         lbne  ShowHelp
	 
         os9   F$PrsNam 		Parse the name
         lbcs  ShowHelp			Error : show help
	 
         lda   #PDELIM			Check that path has only one / e.g. '/d1'
         cmpa  ,y
         lbeq  ShowHelp			yes : show help
	 
         leay  <fullbnam,u		Transfer name to our buffer
L013C    sta   ,y+
         lda   ,x+
         decb  
         bpl   L013C
	 
         sty   <EndDevName		Save pointer to end of dev name
         ldd   #PENTIR*256+C$SPAC	Store '@ ' at end of devname, for entire dev e.g. '/d1@ '
         std   ,y++
         leax  <fullbnam,u		Point to devname
         lda   #UPDAT.			Open for update
         os9   I$Open   		
         sta   <devpath			Save pathnumber
         lbcs  ShowHelp			Error opening dev, show help + exit
	 
         ldx   <EndDevName		Get pointer to end of dev name
         leay  >BootName,pcr		Get pointer to boot file name
         lda   #PDELIM			Append path delimiter e.g. '/d1/'
L0162    sta   ,x+			Append boot name to dev name e.g. '/d1/OS9Boot'
         lda   ,y+
         bpl   L0162
	 
         pshs  u
         clra  
         clrb  
         tfr   d,x
         tfr   d,u
         lda   <devpath
         os9   I$Seek   		seek to 0
         lbcs  Bye
         puls  u
         leax  lsn0buff,u		Point to buffer
         ldy   #DD.DAT			$1A
         lda   <devpath
         os9   I$Read   		read LSN0
         lbcs  Bye			Error : exit
	 
         ldd   <DD.BSZ			get size of bootfile currently
         beq   L019F			branch if none
	 
         leax  <fullbnam,u
         os9   I$Delete 		delete existing bootfile
         
	 clra  
         clrb  
         sta   <DD.BT			Init some of the LSN0 vars
         std   <DD.BT+1
         std   <DD.BSZ
         lbsr  WriteLSN0		Write back to disk
	 
L019F    lda   #WRITE.
         ldb   #READ.+WRITE.
         leax  <fullbnam,u
         os9   I$Create 		create new bootfile
         sta   <newbpath		Save pathnumber
         lbcs  Bye			branch if error

         IFGT  Level-1
* OS-9 Level Two: Copy first 90 bytes of system direct page into our space
* so we can figure out boot location and size, then copy to our space
         leax  >L0015,pcr
         tfr   x,d
         ldx   #$0000
         ldy   #$0090
         pshs  u
         leau  >u057E,u
         os9   F$CpyMem 
         lbcs  Bye
         puls  u
         leax  >L0015,pcr
         tfr   x,d
         ldx   >u05CA,u
         ldy   #$0010
         pshs  u
         leau  <u004E,u
         os9   F$CpyMem 
         puls  u
         lbcs  Bye
         leax  >u057E,u
         ldd   <D.BtPtr,x
         pshs  b,a
         ldd   <D.BtSz,x
         std   <DD.BSZ
         pshs  b,a
L01F7    ldy   #$2000
         cmpy  ,s
         bls   L0203
         ldy   ,s
L0203    pshs  y
         leax  <u004E,u
         tfr   x,d
         ldx   $04,s
         pshs  u
         leau  >u057E,u
         os9   F$CpyMem 
         lbcs  Bye
         puls  u
         ldy   ,s
         leax  >u057E,u
         lda   <newbpath
         os9   I$Write  
         lbcs  Bye
         puls  b,a
         ldy   $02,s
         leay  d,y
         sty   $02,s
         nega  
         negb  
         sbca  #$00
         ldy   ,s
         leay  d,y
         sty   ,s
         bne   L01F7
         leas  $04,s

         ELSE

* OS-9 Level One: Write out bootfile
         ldd   >D.BTHI          	get bootfile size
         subd  >D.BTLO
         tfr   d,y              	in D, tfr to Y
         std   <DD.BSZ          	save it
         ldx   >D.BTLO          	get pointer to boot in mem
         lda   <newbpath
         os9   I$Write          	write out boot to file
         lbcs  Bye

         ENDC

         leax  <pathopts,u		Point to option buffer
         clrb				Read option section of Path descriptor
*         ldb   #SS.Opt
         lda   <newbpath		Get pathnumber of new bootfile
         os9   I$GetStt 		Get options
         lbcs  Bye			Error: exit
	 
         lda   <newbpath		Close bootfile
         os9   I$Close  
         
	 lbcs  ShowHelp
         pshs  u
         ldx   <pathopts+(PD.FD-PD.OPT),u
         lda   <pathopts+(PD.FD+2-PD.OPT),u
* Now X and A hold file descriptor sector LSN of newly created OS9Boot
         clrb  
         tfr   d,u
         lda   <devpath
         os9   I$Seek   		seek to os9boot file descriptor
         puls  u
         lbcs  Bye			Error: exit
	 
         leax  <bffdbuf,u		Point to buffer for filedes sector
         ldy   #256
         os9   I$Read   		read in filedes sector
         lbcs  Bye			Error: exit
         ldd   >bffdbuf+(FD.SEG+FDSL.S+FDSL.B),u	Test if fragmented
         lbne  IsFragd			branch if fragmented
	 
* Get and save bootfile's LSN 
         ldb   >bffdbuf+(FD.SEG),u
         stb   <DD.BT
         ldd   >bffdbuf+(FD.SEG+1),u
         std   <DD.BT+1
         lbsr  WriteLSN0		Write bootfile loc to LSN0 on disk
	 
         ldd   #$0001
         lbsr  Seek2LSN
         leax  >bitmbuf,u		Point to bitmap buffer
         ldy   <DD.MAP			Get block number of map
         lda   <devpath			Get dev pathnumber
         os9   I$Read   		read bitmap sector(s)
         lbcs  Bye			Error: exit
	 
*
* On the dragon, we do not need to test to see if the boot track has files on
* as the boot area is on track 0 imediatly after the blockmap, and before 
* the root directory, and therefore can never have files on it.
* However, we do need to verify that this is a Dragon formatted disk,
* we do this by checking that the root directory starts at LSN 18 (or greater).
*
	 ifne	DRAGON
	 ldd	<DD.DIR+1		Get LSN of root dir
	 cmpd	#DragonRootSec		Is this a dragon disk ?
	 beq	RewriteBitmap		Yes : write boot
	 lbra	TrkAlloc		No : error and exit.
	 else
	 
         ldd   #(Bt.Track*256)+Bt.Sec	Get offset of boot track
         ldy   #$0004			Check 4 csectors
         lbsr  CheckAlloc
         bcc   L0304			Not allocated, check rest
	 
         ldd   #(Bt.Track*256)+Bt.Sec	Get offset of boot track
         lbsr  Seek2LSN
         leax  <BootBuf,u		Point to buffer
         ldy   #$0007			No of bytes to read
         lda   <devpath			Get device path
         os9   I$Read   		Do read
         lbcs  Bye			Error : exit
	 
         leax  <BootBuf,u		Point to buffer
         ldd   ,x			Load first 2 bytes into D
         cmpa  #'O			Check for presense of 'OS'
         lbne  TrkAlloc			No: Try and allocate track (CoCo)
         cmpb  #'S
         lbne  TrkAlloc			No: Try and allocate track (CoCo)
	 
         lda   $04,x			Check 5th byte is a NOP
         cmpa  #$12
         beq   L02F7			Yes: boot track already contains boot code
	 
         ldd   #(Bt.Track*256)+Bt.Sec+$0F
         ldy   #$0003
         lbsr  CheckAlloc
         lbcs  TrkAlloc
	 
L02F7    clra  				Allocate boot track (CoCo)
         ldb   <DD.TKS
         tfr   d,y
         ldd   #(Bt.Track*256)+Bt.Sec
         lbsr  Allocate
         bra   RewriteBitmap
	 
L0304    ldd   #(Bt.Track*256)+Bt.Sec+$04	Check to see if sectors 5..18 of boot track free
         ldy   #$000E			Number of sectors
         lbsr  CheckAlloc		Check them
         lbcs  TrkAlloc			Carry set, sectors allocated, error & exit
         bra   L02F7

	ENDC

RewriteBitmap    
	ldd   #$0001
         lbsr  Seek2LSN			Seek to bitmap sector on disk
         leax  >bitmbuf,u
         ldy   <DD.MAP
         lda   <devpath
         os9   I$Write  		write updated bitmap
         lbcs  Bye

         IFGT  Level-1
* OS-9 Level Two: Link to Rel, which brings in boot code
         pshs  u
         lda   #Systm+Objct
         leax  >RelNam,pcr
         os9   F$Link   
         lbcs  NoRel
         tfr   u,d			tfr module header to D
         puls  u			get statics ptr
         subd  #$0006
         std   <u004B,u			save pointer
         lda   #$E0
         anda  <u004B,u
         ora   #$1E
         ldb   #$FF
         subd  <u004B,u
         addd  #$0001
         tfr   d,y
         ldd   #(Bt.Track*256)+Bt.Sec
         lbsr  Seek2LSN
         lda   <devpath
         ldx   <u004B,u

         ELSE

* OS-9 Level One: Write out data at $EF00
         ldd   #(Bt.Track*256)+Bt.Sec	Seek to boot track
         lbsr  Seek2LSN 
         lda   <devpath			
         ldx   #Bt.Start		Get boot start and size
         ldy   #Bt.Size

         ENDC

         os9   I$Write  		Write boot track
         lbcs  WriteBad			Error 
         os9   I$Close  		Close devpath
         lbcs  Bye			Error : exit
         clrb  				Flag no error
         lbra  Bye			

* Get absolute LSN
* Returns in D
AbsLSN   pshs  b
         ldb   <DD.FMT		get format byte
         andb  #$01		check how many sides?
         beq   L037F		branch if 1
         ldb   #$02		else assume 2
         bra   L0381
L037F    ldb   #$01
L0381    mul   
         lda   <DD.TKS
         mul   
         addb  ,s
         adca  #$00
         leas  $01,s
         rts   

* Returns bit in bitmap corresponding to LSN in A
* X=bitmap buffer, on exit X points to bitmap byte of our LSN
GetBitmapBit    
	pshs  y,b
* Divide D by 8
         lsra  
         rorb  
         lsra  
         rorb  
         lsra  
         rorb  
         leax  d,x		Point X at byte witin bitmap of our LSN ?
         puls  b
         leay  <BitTable,pcr	Point to bit table
         andb  #$07		Make sure offset within table
         lda   b,y		Get bit from table
         puls  pc,y		Restore and return

BitTable    fcb   $80,$40,$20,$10,$08,$04,$02,$01	Bitmap bit table

*
* CheckAlloc, check to see if a block of sectors is allocated.
* 
* Entry : A=track, B= sector, Y=number of sectors
* Exit : Carry Set, sectors are already allocated. Carry clear, sectors are free.
*
CheckAlloc
	pshs  y,x,b,a
         bsr   AbsLSN		go get absolute LSN in D
         leax  >bitmbuf,u	point X to our bitmap buffer
         bsr   GetBitmapBit		
         
	 sta   ,-s		save off
         bmi   L03CB
	 
         lda   ,x		Get bitmap byte of our LSN
         sta   <LSNBitmapByte	Save for later use
L03BB    anda  ,s		Is our LSN allocated ?
         bne   L03F7		Yes : flag error
         
	 leay  -$01,y		Decrement sector count		
         beq   L03F3		All done : yes, exit
         
	 lda   <LSNBitmapByte	Get saved bitmap byte
         lsr   ,s		Check next sector
         bcc   L03BB		If carry, we need to fetch next byte from bitmap
         
	 leax  $01,x		Increment bitmap pointer
L03CB    lda   #$FF		
         sta   ,s
         bra   L03DB
	 
L03D1    lda   ,x
         anda  ,s
         bne   L03F7
         
	 leax  $01,x
         leay  -$08,y
L03DB    cmpy  #$0008		Done a whole byte's worth of blocks ?
         bhi   L03D1		Yes
         beq   L03ED
	 
         lda   ,s		Fetch current bit 
L03E5    lsra  			Process next sector
         leay  -$01,y		decrement sector count
         bne   L03E5		Any more : yes continue
         
	 coma  
         sta   ,s
L03ED    lda   ,x
         anda  ,s
         bne   L03F7
	 
L03F3    andcc #^Carry		
         bra   L03F9
	 
L03F7    orcc  #Carry		Flag error ?
L03F9    leas  $01,s		Drop saved byte	
         puls  pc,y,x,b,a	Restore and return
	 
	 
*
* Allocate, allocate blocks in bitmap
* Entry : A=track, B=sector, Y=block count.
*
	 
Allocate    
	 pshs  y,x,b,a
         lbsr  AbsLSN		get absolute LSN
         leax  >bitmbuf,u	Point to bitmap buffer
         bsr   GetBitmapBit	Get bit corisponding to LSN
	 
         sta   ,-s		Save it
         bmi   L041C
	 
         lda   ,x
L040E    ora   ,s
         leay  -$01,y
         beq   L043A
	 
         lsr   ,s
         bcc   L040E
	 
         sta   ,x
         leax  $01,x
L041C    lda   #$FF
         bra   L0426
	 
L0420    sta   ,x
         leax  $01,x
         leay  -$08,y
L0426    cmpy  #$0008
         bhi   L0420
         beq   L043A
	 
L042E    lsra  
         leay  -$01,y
         bne   L042E
	 
         coma  
         sta   ,s
         lda   ,x
         ora   ,s
L043A    sta   ,x
         leas  $01,s
         puls  pc,y,x,b,a

*
* Seek To LSN, A=track, B=sector
* 

Seek2LSN pshs  u,y,x,b,a
         lbsr  AbsLSN
         pshs  a
         tfr   b,a
         clrb  
         tfr   d,u
         puls  b
         clra  
         tfr   d,x
         lda   <devpath
         os9   I$Seek   
         bcs   WriteBad
         puls  pc,u,y,x,b,a

WriteLSN0
         pshs  u		added for OS-9 Level One +BGP+
         clra  
         clrb  
         tfr   d,x
         tfr   d,u
         lda   <devpath
         os9   I$Seek   	Seek to LSN0
         
	 puls  u		added for OS-9 Level One +BGP+
         leax  lsn0buff,u	Point to our LSN buffer
         ldy   #DD.DAT
         lda   <devpath
         os9   I$Write  	Write to disk
         bcs   Bye		branch if error
         rts

ShowHelp equ   *
         IFNE  DOHELP
         leax  >HelpMsg,pcr
         ELSE
         clrb
         bra   Bye
         ENDC
	 
DisplayErrorAndExit    
	pshs  b
         lda   #$02
         ldy   #256
         os9   I$WritLn 
         comb  
         puls  b
Bye      os9   F$Exit   

IsFragd  leax  >BootFrag,pcr
         clrb  
         bra   DisplayErrorAndExit

WriteBad leax  >WritErr,pcr
         clrb  
         bra   DisplayErrorAndExit

TrkAlloc leax  >FileWarn,pcr
         clrb  
         bra   DisplayErrorAndExit

         IFGT  Level-1
NoRel    leax  >RelMsg,pcr
         bra   DisplayErrorAndExit
         ENDC

         emod
eom      equ   *
         end

********************************************************************
* RFM - Remote File Manager
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   1      2010/02/20  Aaron Wolfe
* initial version - just sends ops to server

               nam       RFM
               ttl       Remote File Manager

               ifp1      
               use       defsfile
               use       rfmdefs
               use       dwdefs.d
               endc      

tylg           set       FlMgr+Objct
atrv           set       ReEnt+rev
rev            set       0
edition        equ       1

               mod       eom,RFMName,tylg,atrv,RFMEnt,size

size           equ       .


RFMName        fcs       /RFM/
               fcb       edition


******************************
*
* file manager entry point
*
RFMEnt         lbra      create              Create path
               lbra      open                Open path
               lbra      makdir              Makdir
               lbra      chgdir              Chgdir
               lbra      delete              Delete 
               lbra      seek                Seek
               lbra      read                Read character 
               lbra      write               Write character
               lbra      readln              ReadLn
               lbra      writln              WriteLn
               lbra      getstt              Get Status
               lbra      setstt              Set Status
               lbra      close               Close path


******************************
*
* Create - creates a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
create         ldb       #DW.create
               bra       create1


******************************
*
* Open - opens a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
open           ldb       #DW.open
create1        
               ldx       PD.DEV,y            ; get ptr to our device memory
               ldx       V$STAT,x            ; get ptr to our static storage
               pshs      x,y,u               ; save all on stack
               stb       V.DWCMD,x
               
* TODO lets not create multiple buffers when multiple open/create on same path
* get system mem
               ldd       #256
               os9       F$SRqMem            ; ask for D bytes (# bytes server said is coming)
               lbcs      open2
               stu       V.BUF,x

* use PrsNam to validate pathlist and count length
               ldu       4,s                 ; get pointer to caller's registers
               ldy       R$X,u
               sty       V.PATHNAME,x
               tfr       y,x
prsloop        os9       F$PrsNam
               bcs       open2
               tfr       y,x
               anda      #$7F
               cmpa      #PENTIR
               bne       chkdelim
               ldb       #E$BPNam
               bra       openerr
chkdelim       cmpa      #PDELIM
               beq       prsloop
* at this point X points to the character AFTER the last character in the name
* update callers R$X
               ldu       4,s                 ; get caller's registers
               stx       R$X,u
               
* compute the length of the pathname and save it
               tfr       x,d
               ldx       ,s                  ; get the device memory pointer
               subd      V.PATHNAME,x
               std       V.PATHNAMELEN,x      ; save the length

* put command byte & path # on stack
               lda       V.DWCMD,x
               ldy       2,s
               ldb       PD.PD,y
               pshs      cc
               pshs      d                   ; p# PD.PD Regs

* put rfm op and DW op on stack 
               lda       #OP_VFM
               pshs      a                   ; DWOP RFMOP p# PD.PD Regs

               leax      ,s                  ; point X to stack 
               ldy       #3                  ; 3 bytes to send

               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      

               orcc      #IntMasks
               jsr       6,u
               leas      3,s                 ;clean stack   PD.PD Regs

               ifgt      Level-1
* now send path string
* move from caller to our mem

               ldx       <D.Proc             get calling proc desc
               lda       P$Task,x            ; A = callers task # (source)

               ldb       <D.SysTsk           ; B = system task # (dest)
               endc
               
               ldx       1,s                 ; get device mem ptr
               ldu       V.BUF,x             ; get destination pointer in U
               ldy       V.PATHNAMELEN,x     ; get count in Y
               ldx       V.PATHNAME,x        ; get source in X

               ifgt      Level-1
*  F$Move the bytes (seems to work)
               os9       F$Move
               bcs       moverr
               endc
               
* Add carriage return
               tfr       u,x
               tfr       y,d
               leau      d,u
               lda       #C$CR
               sta       ,u
               leay      1,y

* send to server
               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      
               jsr       6,u

* read response from server -> B
               clr       ,-s
               leax      ,s
               ldy       #1
               jsr       3,u

* pull server's response into B
               puls      b                   ; PD.PD Regs
moverr         puls      cc
               tstb      
               beq       open2

openerr        coma                          ; set error
open2          puls      x,y,u,pc


******************************
*
* MakDir - creates a directory on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
makdir         lda       #DW.makdir
               lbra      sendit

******************************
*
* ChgDir - changes the data/execution directory on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
chgdir         lda       #DW.chgdir
               lbra      sendit

******************************
*
* Delete - delete a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
delete         lda       #DW.delete
               lbra      sendit
               
               
******************************
*
* Seek - seeks into a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
* seek = send dwop, rfmop, path, caller's X + U               
seek        pshs    y,u
			
			ldx		R$U,u
			pshs	x
			ldx		R$X,u
			pshs	x
			lda     PD.PD,y
			pshs	a
			ldd		#OP_VFM*256+DW.seek
            pshs	d
            
            leax    ,s                  ; point X to stack 
            ldy     #7                  ; 7 bytes to send

* set U to dwsub
            ifgt    Level-1
            ldu     <D.DWSubAddr
            else      
            ldu     >D.DWSubAddr
            endc      

* send dw op, rfm op, path #
            jsr     6,u
            leas    7,s                 ;clean stack - PD.PD Regs
               
            clrb
            puls    y,u,pc


******************************
*
* Read - reads data from a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
read           ldb    #DW.read
               bra    read1               ; join readln routine



******************************
*
* Write - writes data to a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
write          ldb    #DW.write
               lbra   write1



******************************
*
* ReadLn - reads a line of data from a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
readln         ldb       #DW.readln
read1          ldx       PD.DEV,y            ; to our static storage
               ldx       V$STAT,x
               pshs      x,y,u

* put path # on stack
               lda       PD.PD,y
               pshs      cc
               pshs      a                   ; p# PD.PD Regs

* put rfm op and DW op on stack

               lda       #OP_VFM
               pshs      d                   ; DWOP RFMOP p# PD.PD Regs

               leax      ,s                  ; point X to stack 
               ldy       #3                  ; 3 bytes to send

* set U to dwsub
               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      

* send dw op, rfm op, path #
               orcc      #IntMasks
               jsr       6,u
               leas      3,s                 ;clean stack - PD.PD Regs

* put caller's Y on stack (maximum allowed bytes)
               ldx       5,s
               ldx       R$Y,x
               pshs      x

* send 2 bytes from stack
               leax      ,s
               ldy       #2
               jsr       6,u

               leas      1,s                 ; leave 1 byte for server response in next section

* read # bytes coming (0 = eof) from server
               leax      ,s
               ldy       #1
               jsr       3,u

* store size
               clra      
               puls      b                   ;PD.PD Regs


* check for 0
               tstb
               beq       readln1             ; 0 bytes = EOF

* read the data from server if > 0
go_on          pshs      d                   ;xfersz PD.PD Regs

* load data from server into mem block
               ldx       3,s                 ; V$STAT
               ldx       V.BUF,x
               ldy       ,s                  ;xfersz
               jsr       3,u

* F$Move
* a = my task #
* b = caller's task #
* X = source ptr
* Y = byte count
* U = dest ptr

* move from our mem to caller

               puls      y                   ;Y = byte count (already set?)    -  PD.PD Regs
               puls      cc

               ifgt      Level-1
               ldx       4,s
               ldu       R$X,x               ; U = caller's X = dest ptr
               sty       R$Y,x
               
               lda       <D.SysTsk           ; A = system task # 

               ldx       <D.Proc             get calling proc desc
               ldb       P$Task,x            ; B = callers task #

               puls      x                   ; V$STAT     - PD Regs
               ldx       V.BUF,x

*  F$Move the bytes (seems to work)
               os9       F$Move
               endc
* assume everything worked (not good)
               clrb      
               bra       readln2

readln1
               puls      cc
               comb
               ldb       #E$EOF
               leas      2,s                 ; clean stack down 
readln2        puls      y,u,pc




******************************
*
* WritLn - writes a line of data to a file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
writln         ldb       #DW.writln

write1         ldx       PD.DEV,y            ; to our static storage
               ldx       V$STAT,x
               pshs      x,y,u				; Vstat pd regs

* put path # on stack
               lda       PD.PD,y		
               pshs      cc					; cc vstat pd regs
               pshs      a                   ; p# cc vstat PD Regs

* put rfm op and DW op on stack

               lda       #OP_VFM
               pshs      d                   ; DWOP RFMOP p# cc vstat PD.PD Regs

               leax      ,s                  ; point X to stack 
               ldy       #3                  ; 3 bytes to send

* set U to dwsub
               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      

* send dw op, rfm op, path #
               orcc      #IntMasks
               jsr       6,u
               leas      3,s                 ;clean stack - cc vstat PD.PD Regs

* put caller's Y on stack (maximum allowed bytes)
               ldx       5,s
               ldx       R$Y,x
               pshs      x				;bytes cc vstat PD.PD Regs

* send 2 bytes from stack
               leax      ,s
               ldy       #2
               jsr       6,u

* move caller's data into our buf               	

* F$Move
* a = my task #
* b = caller's task #
* X = source ptr
* Y = byte count
* U = dest ptr

               puls      y                   ;Y = byte count (already set?)  cc vstat PD.PD Regs
               
               ifgt      Level-1
                
               ldb       <D.SysTsk           ; dst B = us 

               pshs		u					; dwsub  cc vstat PD.PD Regs
               ldx		3,s	
               ldu		V.BUF,x				; dst U = our v.buf
               
               ldx       <D.Proc             get calling proc desc
               lda       P$Task,x            ; src A = callers task #

               ldx       7,s		; orig U
               ldx       R$X,x               ; src = caller's X
              
              
*  F$Move the bytes 
               os9       F$Move
               endc

               * send v.buf to server
               
               puls		u		;      cc vstat PD.PD Regs          
               ldx		1,s
               ldx		V.BUF,x
               
               jsr		6,u
               
               puls 	 cc		; vstat PD.PD Regs
               bra       writln2
* error exit?
               
writln2        puls      y,u,pc               
               
               
               
               
               
               
               
               
******************************
*
* GetStat - obtain status of file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
getstt                   
               lda       PD.PD,y
               lbsr      sendgstt

               ldb       R$B,u               get function code
               beq       GstOPT
               cmpb      #SS.EOF
               beq       GstEOF
               cmpb      #SS.Ready
               beq       GstReady
               cmpb      #SS.Size
               beq       GstSize
               cmpb      #SS.Pos
               beq       GstPos
               cmpb      #SS.FD
               beq       GstFD
               cmpb      #SS.FDInf
               beq       GstFDInf
               comb      
               ldb       #E$UnkSvc
               rts       

* SS.OPT
* RFM does nothing here, so we do nothing
GstOPT                   
               rts       

* SS.EOF
* Entry A = path
*       B = SS.EOF
GstEOF                   
               rts       

* SS.Ready - Check for data available on path
* Entry A = path
*       B = SS.Ready
GstReady                 
               clr       R$B,u               always mark no data ready
               rts       

* SS.Size - Return size of file opened on path
* Entry A = path
*       B = SS.SIZ
* Exit  X = msw of files size
*       U = lsw of files size
GstSize                  
               rts       

* SS.Pos - Return the current position in the file
* Entry A = path
*       B = SS.Pos
* Exit  X = msw of pos
*       U = lsw of pos
GstPOS                   
               rts       

* SS.FD - Return file descriptor sector
* Entry: A = path
*        B = SS.FD
*        X = ptr to 256 byte buffer
*        Y = # of bytes of FD required

* path # and SS.FD already sent to server, so
* send Y, recv Y bytes, get them into caller at X
* Y and U here are still as at entry
GstFD       
		pshs	y,u
		
		* send caller's Y (do we really need this to be 16bit?  X points to 256byte buff?
		ldx		R$X,u
		pshs	x
		leax	,s
		ldy		#2
		
		* set U to dwsub
        ifgt      Level-1
        ldu       <D.DWSubAddr
        else      
        ldu       >D.DWSubAddr
        endc      

        jsr       6,u
        
        * recv bytes into v.buf
        puls	y
        ldx     ,s                 ; orig Y
        ldx       PD.DEV,x
        ldx       V$STAT,x
        ldx       V.BUF,x		
		pshs	x
        
        jsr		3,u
        
        * move v.buf into caller
        
        ldx       4,s
        ldu       R$X,x               ; U = caller's X = dest ptr
        sty       R$Y,x				  ; do we need to set this for caller?
               
        lda       <D.SysTsk           ; A = system task # 

        ldx       <D.Proc             get calling proc desc
        ldb       P$Task,x            ; B = callers task #

        puls      x                   ; V.BUF from earlier
        
        
*  F$Move the bytes (seems to work)
               os9       F$Move

* assume everything worked (not good)
               clrb   
        
		puls	y,u,pc
                  

* SS.FDInf - 
* Entry: A = path
*        B = SS.FDInf
*        X = ptr to 256 byte buffer
*        Y = msb - Length of read
*              lsb - MSB of LSN
*        U = LSW of LSN
GstFDInf                 
               rts       



******************************
*
* SetStat - change status of file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
setstt 
               lda       #DW.setstt
               lbsr      sendit

               ldb       R$B,u
               beq       SstOpt
               cmpb      #SS.Size
               beq       SstSize
               cmpb      #SS.FD
               beq       SstFD
               cmpb      #SS.Lock
               beq       SstLock
               cmpb      #SS.RsBit
               beq       SstRsBit
               cmpb      #SS.Attr
               beq       SstAttr
               cmpb      #SS.FSig
               beq       SstFSig
               comb      
               ldb       #E$UnkSvc
               rts       

SstOpt                   
SstSize                  
SstFD                    
SstLock                  
SstRsBit                 
SstAttr                  
SstFSig                  
               rts       


******************************
*
* Close - close path to file on the remote device
*
* Entry: Y = Path descriptor pointer
*        U = Callers register stack pointer
*
* Exit:  CC.Carry = 0 (no error), 1 (error)
*        B = error code (if CC.Carry == 1)
*
close          
               pshs      y,u

* put path # on stack
               lda       PD.PD,y
               pshs      a

* put rfm op and DW op on stack
               ldb       #DW.close
               lda       #OP_VFM
               pshs      d

               leax      ,s                  ; point X to stack 
               ldy       #3                  ; 3 bytes to send
               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      

               jsr       6,u
               leas      2,s                 ;clean stack (leave 1 byte)

* read server response
               leax      ,s
               ldy       #1
               jsr       3,u

* free system mem
               ldd       #256
               ldx       1,s                 ; orig Y
               ldx       PD.DEV,x
               ldx       V$STAT,x
               ldu       V.BUF,x
               os9       F$SRtMem

               puls      b                   ; server sends result code
               tstb
               beq       close1
               coma                          ; set error flag if != 0
close1         puls      u,y,pc


* send dwop, rfmop, path, set/getstat op   (path is in A)
sendgstt        pshs      x,y,u

				ldb		R$B,u	
				pshs	d	
				
			   lda       #OP_VFM             ; load command
			   ldb		 #DW.getstt
               pshs      d                   ; command store on stack
               leax      ,s                  ; point X to stack 
               ldy       #4                  ; 2 byte to send
               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      

               jsr       6,u
               leas      4,s                 ;clean stack

               clrb      
               puls      x,y,u,pc





* just send OP_VMF + vfmop
sendit         pshs      a,x,y,u

               lda       #OP_VFM             ; load command
               pshs      a                   ; command store on stack
               leax      ,s                  ; point X to stack 
               ldy       #2                  ; 2 byte to send
               ifgt      Level-1
               ldu       <D.DWSubAddr
               else      
               ldu       >D.DWSubAddr
               endc      

               jsr       6,u
               leas      2,s                 ;clean stack

               clrb      
               puls      x,y,u,pc

               emod      
eom            equ       *
               end       


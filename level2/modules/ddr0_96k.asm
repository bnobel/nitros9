********************************************************************
* DD - RAM device descriptor
*
* $Id$
*
* Ed.    Comments                                       Who YY/MM/DD
* ------------------------------------------------------------------

         nam   DD
         ttl   RAM device descriptor

* Disassembled 98/08/23 17:09:41 by Disasm v1.6 (C) 1988 by RML

         ifp1  
         use   defsfile
         use   rbfdefs
         endc  

dnum     equ   0

tylg     set   Devic+Objct
atrv     set   ReEnt+rev
rev      set   $01

         mod   eom,name,tylg,atrv,mgrnam,drvnam

         fcb   DIR.!ISIZ.!PEXEC.!PWRIT.!PREAD.!EXEC.!UPDAT. mode byte
         fcb   $00        extended controller address
         fdb   $0000      physical controller address
         fcb   initsize-*-1 initilization table size
         fcb   DT.RBF     device type:0=scf,1=rbf,2=pipe,3=scf
         fcb   dnum       drive number
         fcb   0          step rate
         fcb   0          drive device type
         fcb   0          media density:0=single,1=double
         fdb   0          number of cylinders (tracks)
         fcb   1          number of sides
         fcb   0          verify disk writes:0=on
         fdb   384        # of sectors per track
         fdb   0          # of sectors per track (track 0)
         fcb   0          sector interleave factor
         fcb   4          minimum size of sector allocation
initsize equ   *

name     fcs   /DD/
mgrnam   fcs   /RBF/
drvnam   fcs   /RAM/

         emod  
eom      equ   *
         end   


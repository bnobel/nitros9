********************************************************************
* DWDesc - DriveWire Device Descriptor Template
*
* $Id$
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------
*   0      2003/03/28  Boisy G. Pitre
* Created.

         nam   DWDesc
         ttl   DriveWire Device Descriptor Template

         ifp1  
         use   defsfile
         endc  

tylg     set   Devic+Objct
atrv     set   ReEnt+rev
rev      set   $01

DNum     set   0
Type     set   TYP.HARD
Density  set   0
Step     set   0
Cyls     set   1024
Sides    set   1
Verify   set   1
SectTrk  set   18
SectTrk0 set   18
Interlv  set   0
SAS      set   8

         mod   eom,name,tylg,atrv,mgrnam,drvnam

         fcb   DIR.!ISIZ.!SHARE.!PEXEC.!PWRIT.!PREAD.!EXEC.!UPDAT. mode byte
         fcb   HW.Page    extended controller address
         fdb   $0000      physical controller address
         fcb   initsize-*-1 initilization table size
         fcb   DT.RBF     device type:0=scf,1=rbf,2=pipe,3=scf
         fcb   dnum       drive number
         fcb   Step       step rate
         fcb   Type       drive device type
         fcb   Density    media density:0=single,1=double
         fdb   Cyls       number of cylinders (tracks)
         fcb   Sides      number of sides
         fcb   Verify     verify disk writes:0=on
         fdb   SectTrk    # of sectors per track
         fdb   SectTrk0   # of sectors per track (track 0)
         fcb   Interlv    sector interleave factor
         fcb   SAS        minimum size of sector allocation
initsize equ   *

         IFNE  DD
name     fcs   /DD/
         ELSE
name     fcc   /X/
         fcb   176+dnum
         ENDC
mgrnam   fcs   /RBF/
drvnam   fcs   /rbdw3/

         emod  
eom      equ   *
         end   


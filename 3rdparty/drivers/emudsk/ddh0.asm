********************************************************************
* Emudsk - Virtual disk driver for CoCo emulators
*
* $Id$
*
* Ed.    Comments                                       Who YY/MM/DD
* ------------------------------------------------------------------
*  01    Modified to compile under OS9Source            tjl 02/08/28

 IFP1
 USE os9defs
 ENDC

type SET Devic+Objct
 MOD rend,rnam,type,ReEnt+1,fmnam,drvnam
 FCB $FF  all access modes
 FCB $07,$FF,$E0 device address

 FCB optl number of options

optns EQU *
 FCB DT.RBF RBF device
 FCB $00 drive number
 FCB $00 step rate
 FCB $80 type=nonstd,coco
 FCB $01 double density
 FDB $005a tracks
 FCB $40 one side
 FCB $01 no verify
 FDB $0040 sectors/track
 FDB $0040 "", track 0
 FCB $03 interleave
 FCB $20 min allocation
optl EQU *-optns

rnam FCS /DD/
fmnam FCS /RBF/
drvnam FCS /EmuDsk/

 EMOD
rend EQU *
 end


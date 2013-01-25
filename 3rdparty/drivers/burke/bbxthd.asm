*******************************************
***                                     ***
***     COPYRIGHT 1987 BURKE & BURKE    ***
***     ALL RIGHTS RESERVED             ***
***                                     ***
*******************************************

        nam     BBXTHD

*
*   CoCo XT Hard Disk Driver  07/25/87
*
*   For Western Digital WD1002-WX2 (or WX1) Controller.
*
*   This version is optimized for 1 4x32 hard disk
*   on the CoCo 3, under level 1 Version 1 OS9.  It 
*   speeds up to 2 MHz during disk I/O, then slows down 
*   again.  It does not verify disk writes, and does not 
*   use read caching.
*
*  Chris Burke  Schaumburg, IL  07/25/87
*

 page
*
*  Conditional assembly control
*

Drives  equ     1           ;Number of drives supported

irqflg  equ     1           ;non-zero to mask interrupts during HD access
trsflg  equ     1           ;non-zero if optimized for 4x32 disk
cchflg  equ     0           ;non-zero if read cache supported
vrfflg  equ     0           ;non-zero if write verification supported
tboflg  equ     1           ;non-zero if jump to 2 MHz for block moves
fstflg  equ     1           ;non-zero if fast transfers supported
sysram  equ     1           ;non-zero to use system RAM for verify buffer
sizflg  equ     0           ;non-zero to allow drives of different sizes

fmtflg  equ     0           ;non-zero if hard formatting supported
errflg  equ     0           ;non-zero for good error messages
icdflg  equ     0           ;non-zero to ignore C/D status bit
timflg  equ     0           ;non-zero to support access timer

XLEVEL  equ     1           ;Bogus level 2 flag

testing equ     0           ;non-zero to call driver "XD", not "HD"

*
*   Include the main line
*

        use     xtos9.src


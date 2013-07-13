# The NitrOS-9 Project
# Project-Wide Rules

# Environment variables are now used to specify any directories other
# than the defaults below:
#
#   NITROS9DIR   - base directory of the NitrOS-9 project on your system
#
# If the defaults below are fine, then there is no need to set any
# environment variables.


# NitrOS-9 version, major and minor release numbers are here
NOS9VER	= 3
NOS9MAJ	= 2
NOS9MIN	= 9

# Set this to 1 to turn on "DEVELOPMENT" message in sysgo
NOS9DBG = 1

#################### DO NOT CHANGE ANYTHING BELOW THIS LINE ####################

CC		= c3

NITROS9VER	= v0$(NOS9VER)0$(NOS9MAJ)0$(NOS9MIN)

ifndef	NITROS9DIR
NITROS9DIR	= $(HOME)/nitros9
endif
ifndef	CLOUD9DIR
CLOUD9DIR	= $(HOME)/cloud9
endif

C9		= $(CLOUD9DIR)
DEFSDIR		= $(NITROS9DIR)/defs
DSKDIR		= $(NITROS9DIR)/dsks


# If we're using the OS-9 emulator and the *real* OS-9 assembler,
# uncomment the following two lines.
#AS		= os9 /mnt2/src/ocem/os9/asm
#ASOUT		= o=

# Use the cross assembler
#AS		= os9asm -i=$(DEFSDIR)
AS		= lwasm --6309 --format=os9 --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal --includedir=. --includedir=$(DEFSDIR)
ASROM		= lwasm --6309 --format=raw --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal --includedir=. --includedir=$(DEFSDIR)
ASBIN		= lwasm --6309 --format=decb --pragma=pcaspcr,nosymbolcase,condundefzero,undefextern,dollarnotlocal --includedir=. --includedir=$(DEFSDIR)
ASOUT		= -o
AFLAGS		= -DNOS9VER=$(NOS9VER) -DNOS9MAJ=$(NOS9MAJ) -DNOS9MIN=$(NOS9MIN) -DNOS9DBG=$(NOS9DBG)
ifdef PORT
AFLAGS		+= -D$(PORT)=1
endif

# RMA/RLINK
ASM		= lwasm --6309 --format=obj --pragma=pcaspcr,condundefzero,undefextern,dollarnotlocal,export --includedir=.
LINKER		= lwlink --format=os9
LWAR		= lwar -c

# Commands
MAKDIR		= os9 makdir
RM		= rm -f
MERGE		= cat
MOVE		= mv
ECHO		= echo
CD		= cd
OS9COPY		= os9 copy -o=0
CPL		= $(OS9COPY) -l
TAR		= tar
CHMOD		= chmod
IDENT		= os9 ident
IDENT_SHORT	= $(IDENT) -s
#UNIX2OS9	= u2o
#OS92UNIX	= o2u
OS9FORMAT	= os9 format -e
OS9FORMAT_SS35	= os9 format -e -t35 -ss -dd
OS9FORMAT_SS40	= os9 format -e -t40 -ss -dd
OS9FORMAT_SS80	= os9 format -e -t80 -ss -dd
OS9FORMAT_DS40	= os9 format -e -t40 -ds -dd
OS9FORMAT_DS80	= os9 format -e -t80 -ds -dd
OS9FORMAT_DW	= os9 format -t1024 -ss -dd
OS9GEN		= os9 gen
OS9RENAME	= os9 rename
OS9ATTR		= os9 attr -q
OS9ATTR_TEXT	= $(OS9ATTR) -npe -npw -pr -ne -w -r
OS9ATTR_EXEC	= $(OS9ATTR) -pe -npw -pr -e -w -r
PADROM		= os9 padrom
MOUNT		= sudo mount
UMOUNT		= sudo umount
LOREMOVE	= sudo losetup -d
LOSETUP		= sudo losetup
LINK		= ln
SOFTLINK	= $(LINK) -s
ARCHIVE		= zip -D -9 -j
MKDSKINDEX	= $(NITROS9DIR)/3rdparty/utils/aaw/mkdskindex

# Directories
3RDPARTY	= $(NITROS9DIR)/3rdparty
LEVEL1		= $(NITROS9DIR)/level1
LEVEL2		= $(NITROS9DIR)/level2
LEVEL3		= $(NITROS9DIR)/level3
NOSLIB		= $(NITROS9DIR)/lib
CC68L1          = $(LEVEL1)/coco1
CC368L2         = $(LEVEL2)/coco3
CC363L2         = $(LEVEL2)/coco3_6309
CC363L3         = $(LEVEL3)/coco3_6309

# HDD Drive ID's
ID0 = -DITDRV=0
ID1 = -DITDRV=1
ID2 = -DITDRV=2
ID3 = -DITDRV=3
ID4 = -DITDRV=4
ID5 = -DITDRV=5
ID6 = -DITDRV=6
ID7 = -DITDRV=7
SLAVE = -DITDNS=1
MASTER = -DITDNS=0


# C-Cubed Rules
%.o: %.c
	$(CC) $(CFLAGS) $< -r

%.a: %.o
	lwar -c $@ $?

%: %.o
	$(LINKER) $(LFLAGS) $^ -o$@

%: %.a
	$(LINKER) $(LFLAGS) $^ -o$@

%.o: %.as
	$(ASM) $< -o$@

# File managers
%.mn: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# Device drivers
%.dr: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# Device descriptors
%.dd: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# Subroutine modules
%.sb: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# Window device descriptors
%.dw: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# Terminal device descriptors
%.dt: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# I/O subroutines
%.io: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@

# All other modules
%: %.asm
	$(AS) $(AFLAGS) $< $(ASOUT)$@


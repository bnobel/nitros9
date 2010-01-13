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
AS		= mamou -i=$(DEFSDIR)
#AS		= os9asm -i=$(DEFSDIR)
ASOUT		= -o
AFLAGS		= -q -aNOS9VER=$(NOS9VER) -aNOS9MAJ=$(NOS9MAJ) -aNOS9MIN=$(NOS9MIN) -aNOS9DBG=$(NOS9DBG)
ifdef PORT
AFLAGS		+= -a$(PORT)=1
endif

# RMA/RLINK
ASM		= rma
LINKER	= rlink

# Commands
MAKDIR		= os9 makdir
RM		= rm -f
MERGE		= cat
MOVE		= mv
ECHO		= /bin/echo
CD		= cd
CP		= os9 copy -o=0
CPL		= $(CP) -l
TAR		= tar
CHMOD		= chmod
IDENT		= os9 ident
IDENT_SHORT	= $(IDENT) -s
#UNIX2OS9	= u2o
#OS92UNIX	= o2u
OS9FORMAT	= os9 format
OS9FORMAT_SS35	= os9 format -t35 -ss -dd
OS9FORMAT_SS40	= os9 format -t40 -ss -dd
OS9FORMAT_SS80	= os9 format -t80 -ss -dd
OS9FORMAT_DS40	= os9 format -t40 -ds -dd
OS9FORMAT_DS80	= os9 format -t80 -ds -dd
OS9FORMAT_DW3	= os9 format -t1024 -ss -dd
OS9GEN		= os9 gen
OS9RENAME	= os9 rename
OS9ATTR		= os9 attr -q
OS9ATTR_TEXT	= $(OS9ATTR) -npe -npw -pr -ne -w -r
OS9ATTR_EXEC	= $(OS9ATTR) -pe -npw -pr -e -w -r
PADROM		= os9 padrom
MOUNT		= sudo mount
UMOUNT		= sudo umount
LOREMOVE	= sudo /sbin/losetup -d
LOSETUP		= sudo /sbin/losetup
LINK		= ln
SOFTLINK	= $(LINK) -s
ARCHIVE		= zip -D -j

# Directories
3RDPARTY	= $(NITROS9DIR)/3rdparty
LEVEL1		= $(NITROS9DIR)/level1
LEVEL2		= $(NITROS9DIR)/level2

# C-Cubed Rules
%.r: %.c
	$(CC) $(CFLAGS) $< -r

#%.l: %.r
#	$(MERGE) $^ > $@

%: %.r
	$(LINKER) $(LFLAGS) $^ -o=$@

%.r: %.a
	$(ASM) $< -o=$@

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


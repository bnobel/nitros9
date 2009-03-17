include rules.mak

dirs	= $(LEVEL1) $(LEVEL2) $(3RDPARTY)
 
# Make all components
all:
	@$(ECHO) "**************************************************"
	@$(ECHO) "*                                                *"
	@$(ECHO) "*              THE NITROS-9 PROJECT              *"
	@$(ECHO) "*                                                *"
	@$(ECHO) "**************************************************"
	$(foreach dir, $(dirs), ($(CD) $(dir); make);)

# Clean all components
clean:  dskclean
	-$(RM) nitros9project.zip dsks/*.dsk
	$(foreach dir, $(dirs), ($(CD) $(dir); make clean);)

# Do CVS update
cvs:
	cvs update -d

# Make DSK images
dsk:	all
	$(foreach dir, $(dirs), ($(CD) $(dir); make dsk);)

# COpy DSK images
dskcopy:	all
	$(foreach dir, $(dirs), ($(CD) $(dir); make dskcopy);)

# Clean DSK images
dskclean:
	$(foreach dir, $(dirs), ($(CD) $(dir); make dskclean);)

# DriveWire 3 DSK images
dw3dsk = $(LEVEL1)/coco/nos96809l1coco1_dw3.dsk $(LEVEL1)/coco/nos96809l1coco2_dw3.dsk \
	$(LEVEL2)/coco3/nos96809l2_dw3.dsk $(LEVEL2)/coco3_6309/nos96309l2_dw3.dsk

dw3:
	$(ARCHIVE) nitros9_drivewire3.zip $(dw3dsk)

nightly: cvs clean dskcopy
	$(ARCHIVE) nitros9project dsks/*
	scp nitros9project.zip boisy,nitros9@web.sourceforge.net:/home/groups/n/ni/nitros9/htdocs


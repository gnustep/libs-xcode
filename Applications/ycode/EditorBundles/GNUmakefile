ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
SUBPROJECTS = Text Image Sound Model
include $(GNUSTEP_MAKEFILES)/aggregate.make

after-all::
	mkdir -p Editors
	cp -R Text/Text.bundle Image/Image.bundle Sound/Sound.bundle Model/Model.bundle Editors/

after-clean::
	$(RM) -r Editors

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
SUBPROJECTS = GDB
include $(GNUSTEP_MAKEFILES)/aggregate.make

after-all::
	mkdir -p Debuggers
	cp -R GDB/GDB.bundle Debuggers/

after-clean::
	$(RM) -r Debuggers

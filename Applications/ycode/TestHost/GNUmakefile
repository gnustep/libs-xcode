ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = YCodeTestHost
YCodeTestHost_PRINCIPAL_CLASS = YCodeTestHost
YCodeTestHost_OBJC_FILES = YCodeTestHost.m
# Embedded in Ycode's resources, not installed as a global bundle.
include $(GNUSTEP_MAKEFILES)/bundle.make

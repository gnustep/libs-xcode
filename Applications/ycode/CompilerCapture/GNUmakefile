ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
TOOL_NAME = ycode-compiler-capture
ycode-compiler-capture_OBJC_FILES = main.m
include $(GNUSTEP_MAKEFILES)/tool.make

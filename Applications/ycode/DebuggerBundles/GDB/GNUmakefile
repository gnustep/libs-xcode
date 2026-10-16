ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = GDB
GDB_PRINCIPAL_CLASS = YCodeGDBDebugger
GDB_OBJC_FILES = YCodeGDBDebugger.m YCodeGDBVariables.m
GDB_INCLUDE_DIRS = -I../..
GDB_RESOURCE_FILES = Debugger.plist
# Embedded in the application's Debuggers resources.
include $(GNUSTEP_MAKEFILES)/bundle.make

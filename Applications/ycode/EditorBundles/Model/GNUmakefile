ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = Model
Model_PRINCIPAL_CLASS = YCodeModelEditorDocument
Model_OBJC_FILES = YCodeModelEditorDocument.m
Model_INCLUDE_DIRS = -I../.. -I../../../..
include $(GNUSTEP_MAKEFILES)/bundle.make

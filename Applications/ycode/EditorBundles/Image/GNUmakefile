ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = Image
Image_PRINCIPAL_CLASS = YCodeImageEditorDocument
Image_OBJC_FILES = YCodeImageEditorDocument.m
Image_INCLUDE_DIRS = -I../.. -I../../../..
include $(GNUSTEP_MAKEFILES)/bundle.make

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = Text
Text_PRINCIPAL_CLASS = YCodeTextEditorDocument
Text_OBJC_FILES = YCodeTextEditorDocument.m
Text_INCLUDE_DIRS = -I../.. -I../../../..
include $(GNUSTEP_MAKEFILES)/bundle.make

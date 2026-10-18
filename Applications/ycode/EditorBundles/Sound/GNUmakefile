ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = Sound
Sound_PRINCIPAL_CLASS = YCodeSoundEditorDocument
Sound_OBJC_FILES = YCodeSoundEditorDocument.m
Sound_INCLUDE_DIRS = -I../.. -I../../../..
include $(GNUSTEP_MAKEFILES)/bundle.make

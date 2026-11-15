ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
BUNDLE_NAME = Gorm
Gorm_PRINCIPAL_CLASS = YCodeGormEditorDocument
Gorm_RESOURCE_FILES = Resources/GormEHCoil.tiff Resources/GormEVCoil.tiff Resources/GormEHLine.tiff Resources/GormEVLine.tiff Resources/GormMHCoil.tiff Resources/GormMVCoil.tiff Resources/GormMHLine.tiff Resources/GormMVLine.tiff Resources/NOTICE.Gorm Resources/COPYING.Gorm
Gorm_OBJC_FILES = YCodeGormEditorDocument.m
Gorm_INCLUDE_DIRS = -I../.. -I../../../..
Gorm_BUNDLE_LIBS = -lGormCore -lInterfaceBuilder -lGormObjCHeaderParser
include $(GNUSTEP_MAKEFILES)/bundle.make

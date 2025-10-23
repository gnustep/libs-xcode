# Makefile for ProjectCenter generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = projectcenter
BUNDLE_EXTENSION = .generator
projectcenter_PRINCIPAL_CLASS = GSXCProjectCenterGenerator

projectcenter_HAS_RESOURCE_BUNDLE = yes

projectcenter_OBJC_FILES = GSXCProjectCenterGenerator.m

projectcenter_RESOURCE_FILES =

ProjectCenter_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

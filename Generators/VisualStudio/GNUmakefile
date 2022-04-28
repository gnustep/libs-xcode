# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = VisualStudio
BUNDLE_EXTENSION = .generator
VisualStudio_PRINCIPAL_CLASS = GSXCVisualStudioGenerator

VisualStudio_OBJC_FILES = GSXCVisualStudioGenerator.m \
	GSXCVSSolution.m \
	GSXCVSProject.m \
	GSXCVSGlobalSection.m \
	GSXCVSGlobalSectionContainer.m

VisualStudio_RESOURCE_FILES =

VisualStudio_STANDARD_INSTALL = no

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

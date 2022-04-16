# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = Makefile
BUNDLE_EXTENSION = .generator
Makefile_PRINCIPAL_CLASS = GSXCMakefileGenerator

Makefile_OBJC_FILES = GSXCMakefileGenerator.m 

Makefile_RESOURCE_FILES =

Makefile_STANDARD_INSTALL = no

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

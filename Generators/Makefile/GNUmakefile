# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = Makefile
BUNDLE_EXTENSION = .generator
Makefile_PRINCIPAL_CLASS = GSXCMakefileGenerator

Makefile_HAS_RESOURCE_BUNDLE = yes

Makefile_OBJC_FILES = GSXCMakefileGenerator.m 

Makefile_RESOURCE_FILES =

Makefile_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

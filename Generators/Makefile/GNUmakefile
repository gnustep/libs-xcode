# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = makefile
BUNDLE_EXTENSION = .generator
makefile_PRINCIPAL_CLASS = GSXCMakefileGenerator

makefile_HAS_RESOURCE_BUNDLE = yes

makefile_OBJC_FILES = GSXCMakefileGenerator.m 

makefile_RESOURCE_FILES =

makefile_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

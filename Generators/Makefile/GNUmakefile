# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = Makefile
BUNDLE_EXTENSION = .generator
mf_PRINCIPAL_CLASS = GSXCMakefileGenerator

mf_OBJC_FILES = GSXCMakefileGenerator.m 

mf_RESOURCE_FILES =

mf_STANDARD_INSTALL = no

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

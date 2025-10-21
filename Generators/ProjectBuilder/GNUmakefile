# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = projectbuilder
BUNDLE_EXTENSION = .generator
ProjectBuilder_PRINCIPAL_CLASS = 

ProjectBuilder_HAS_RESOURCE_BUNDLE = yes

ProjectBuilder_OBJC_FILES = 

ProjectBuilder_RESOURCE_FILES =

ProjectBuilder_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

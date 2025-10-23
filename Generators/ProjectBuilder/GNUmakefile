# Makefile for ProjectBuilder generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = projectbuilder
BUNDLE_EXTENSION = .generator
projectbuilder_PRINCIPAL_CLASS = GSXCProjectBuilderGenerator

projectbuilder_HAS_RESOURCE_BUNDLE = yes

projectbuilder_OBJC_FILES = GSXCProjectBuilderGenerator.m

projectbuilder_RESOURCE_FILES =

ProjectBuilder_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

# Makefile for GNUmakefile generation

include $(GNUSTEP_MAKEFILES)/common.make

ADDITIONAL_INCLUDE_DIRS += -I../..
BUNDLE_NAME = cmake
BUNDLE_EXTENSION = .generator
cmake_PRINCIPAL_CLASS = GSXCCMakeGenerator

cmake_HAS_RESOURCE_BUNDLE = yes

cmake_OBJC_FILES = GSXCCMakeGenerator.m 

cmake_RESOURCE_FILES =

cmake_STANDARD_INSTALL = yes

-include GNUmakefile.preamble
-include GNUmakefile.local
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble

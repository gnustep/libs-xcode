#
# Tests
#
ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
ifeq ($(GNUSTEP_MAKEFILES),)
 $(error You need to set GNUSTEP_MAKEFILES before compiling!)
endif

include $(GNUSTEP_MAKEFILES)/common.make

TEST_TOOL_NAME = xcode_tests

xcode_tests_OBJC_FILES = \
	main.m \
	../Tools/buildtool/ArgPair.m \
	../Tools/buildtool/ToolDelegate.m

xcode_tests_TOOL_LIBS += -lXCode
xcode_tests_LIB_DIRS += -L../XCode/XCode.framework/Versions/0
xcode_tests_INCLUDE_DIRS += -I.. -I../Tools/buildtool

check:: all
	./$(GNUSTEP_OBJ_DIR)/xcode_tests -project Sample.xcodeproj -workspace Sample.xcworkspace -target SampleTarget -scheme SampleScheme -configuration Debug -alltargets build

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/test-tool.make
-include GNUmakefile.postamble

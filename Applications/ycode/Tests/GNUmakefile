ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif

include $(GNUSTEP_MAKEFILES)/common.make

# Waveform decoding uses the same portable library as GNUstep NSSound.
YCODE_SNDFILE_LIBS := $(shell pkg-config --libs sndfile 2>/dev/null)
ifneq ($(strip $(YCODE_SNDFILE_LIBS)),)
ycode_tests_OBJCFLAGS += -DYCODE_HAVE_SNDFILE $(shell pkg-config --cflags sndfile 2>/dev/null)
ycode_tests_TOOL_LIBS += $(YCODE_SNDFILE_LIBS)
endif



TEST_TOOL_NAME = ycode_tests
ycode_tests_HAS_RESOURCE_BUNDLE = yes
ycode_tests_RESOURCE_FILES = ../Resources/Templates ../Resources/Languages ../DebuggerBundles/Debuggers ../EditorBundles/Editors ../Resources/ProjectCenterIcons ../TestHost/YCodeTestHost.bundle ../Resources/YcodeHelp.txt ../Resources/Ycode.gorm
ycode_tests_OBJC_FILES = main.m $(filter-out ../Ycode_main.m,$(wildcard ../*.m))
ycode_tests_INCLUDE_DIRS += -I.. -I../../..
ycode_tests_LIB_DIRS += -L../../../XCode/XCode.framework/Versions/0
ycode_tests_TOOL_LIBS += -lXCode -lgnustep-gui

check:: all
	LD_LIBRARY_PATH="$(CURDIR)/../../../XCode/XCode.framework/Versions/0:$$LD_LIBRARY_PATH" \
	./$(GNUSTEP_OBJ_DIR)/ycode_tests

include $(GNUSTEP_MAKEFILES)/test-tool.make

before-all::
	$(MAKE) -C ../TestHost all
	$(MAKE) -C ../DebuggerBundles all
	$(MAKE) -C ../EditorBundles all

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif

include $(GNUSTEP_MAKEFILES)/common.make

TEST_TOOL_NAME = ycode_tests
ycode_tests_HAS_RESOURCE_BUNDLE = yes
ycode_tests_RESOURCE_FILES = ../Resources/Templates ../Resources/ProjectCenterIcons ../TestHost/YCodeTestHost.bundle
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

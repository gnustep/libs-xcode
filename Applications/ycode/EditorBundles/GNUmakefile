ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
endif
include $(GNUSTEP_MAKEFILES)/common.make
SUBPROJECTS = Text Image Sound Model
# Probe the installed document-service API and libraries, not the Gorm app.
# Distributors may explicitly disable the optional editor with YCODE_GORM=no.
YCODE_GORM ?= auto
ifneq ($(YCODE_GORM),no)
GORM_AVAILABLE := $(shell CC="$(CC)" sh ./check-gorm.sh)
ifeq ($(GORM_AVAILABLE),yes)
SUBPROJECTS += Gorm
endif
endif
include $(GNUSTEP_MAKEFILES)/aggregate.make

after-all::
	mkdir -p Editors
	cp -R Text/Text.bundle Image/Image.bundle Sound/Sound.bundle Model/Model.bundle Editors/
ifeq ($(GORM_AVAILABLE),yes)
	cp -R Gorm/Gorm.bundle Editors/
else
	$(RM) -r Editors/Gorm.bundle
endif

after-clean::
	$(RM) -r Editors

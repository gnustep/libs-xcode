#
#  Documentation makefile for the GNUstep GUI Library
#  Copyright (C) 1995 Free Software Foundation, Inc.
#
#  Written by: Adam Fedor <fedor@gnu.org>
#
#  This file is part of the GNUstep GUI Library.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; see the file COPYING.LIB.
#  If not, see <http://www.gnu.org/licenses/> or write to the 
#  Free Software Foundation, 51 Franklin Street, Fifth Floor, 
#  Boston, MA 02110-1301, USA.

PACKAGE_NAME = libs-xcode
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version

# The documents to be generated
DOCUMENT_NAME = ReleaseNotes

# SUBPROJECTS = General GuiUser manual

# The text documents to be generated

# Manual pages to install
MAN1_PAGES = \
	buildtool.1

-include GNUmakefile.preamble

include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/documentation.make

-include GNUmakefile.postamble


Ycode terminal engine

YCodeTerminalParser.m, YCodeTerminalParser.h, and YCodeTerminalTypes.h
are adapted from GNUstep Terminal.app's TerminalParser_VT100.m/.h and
Terminal.h (the native parser replacement of 2026-10-23).
The imported copyright and GPL v3-or-later notices are preserved.
See ../Resources/ThirdPartyLicenses/Terminal-parser-GPL-3.txt.

The Info panel retains the historical attribution: terminal emulation code
is based on libvterm. The earlier MIT license remains in ThirdPartyLicenses
for attribution. No libvterm sources or external emulator library are built.

Ycode-specific integration includes row damage notifications, cursor style
and blinking, focus and mouse reporting, preference-aware bell handling,
and direct native-cell access for rendering and selection. The view retains
its AppKit rendering, keyboard/mouse input, scrollback, and POSIX PTY session.
It advertises xterm-256color and UTF-8. The terminal engine is independent
of the editor's ANSI transcript formatting.

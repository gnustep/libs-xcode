Ycode terminal engine

libvterm 0.3.3, by Paul Evans and contributors, is vendored in libvterm/.
Source: https://www.leonerd.org.uk/code/libvterm/libvterm-0.3.3.tar.gz
Archive SHA-256: 09156f43dd2128bd347cbeebe50d9a571d32c64e0cf18d211197946aff7226e0
Upstream project: https://www.leonerd.org.uk/code/libvterm/

Local sources are formatted with the repository's GNU coding style. Formatting
preserves upstream source tokens; use Tools/format-source.py from the repository
root after importing upstream updates.
License: MIT; see libvterm/LICENSE. All upstream source files are unchanged.
The release includes generated encoding and Unicode tables, so building Ycode
does not require downloading dependencies or running table generators.

YCodeTerminalView supplies AppKit rendering, keyboard/mouse input, scrollback,
and a POSIX PTY session. It advertises xterm-256color and UTF-8. The terminal
engine is independent of the editor's ANSI transcript formatting.

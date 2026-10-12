# apps-ycode

Xcode like application which combines the capabilities of gorm and projectecenter.  It's primary purpose
is to provide an interface analogous to Xcode so that we can have a more modern development IDE where 
all of the development happens in one place.  This will also help to unify our approach to dealing with
certain types of interfaces which Gorm can't easily deal with.

Build the local libs-xcode framework and Ycode from the repository root:

```sh
make -C XCode
make -C Applications/ycode
```

The repository's top-level `make install` does not install Ycode. Install it
separately, choosing the domain containing the application you launch. For an
existing System-domain installation, run this from the repository root after
building:

```sh
sudo make -C Applications/ycode install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM \
  GNUSTEP_MAKEFILES="$(gnustep-config --variable=GNUSTEP_MAKEFILES)"
```

The makefiles path is expanded before `sudo`, so installation also works when
root's PATH does not include `gnustep-config`. If using `su` instead, source
the installed GNUstep environment in the root shell first (for example,
`. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh`), then run
`make -C Applications/ycode install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM` from
the repository root. The default installation domain is Local; installing
there does not replace an existing System copy. Quit and reopen Ycode after
installation to load the updated executable.

Use **File > Open Project...** to select an `.xcodeproj` package. Ycode loads
its `project.pbxproj` through libs-xcode and displays its groups, files, and
targets in the project navigator. Missing or invalid project contents produce
an error instead of opening an empty project. ProjectCenter `.pcproj` packages
remain supported. Each project remembers its last selected source file and
reopens it next time. Closing the last source tab clears that saved selection;
missing files are skipped when reopening the project.

Ycode starts without creating an untitled project. On GNUstep, the main menu
uses Info for About, Preferences, and Help, with Services, Hide, and Quit at
the top level. Build and run commands are in Project; window commands are in
Windows. The editor rulers show character columns across the top and source
line numbers down the side, following the font size and scroll position.
The editable area fills the window as it grows while long lines remain
horizontally scrollable. Editing follows ProjectCenter: Return indents new
lines, Tab reindents the current line or shifts selected lines, Shift-Tab
unindents selected lines, and closing delimiters align with their opening
line. Shift-arrow keys extend or contract the selection from its anchor.
Indentation defaults to two spaces and reads `IndentWidth`, `TabWidth`, and
`UseTab` from the nearest parent `.clang-format` file.

Run the application regression checks with a working GUI display (or under
`xvfb-run -a` on a headless GNUstep system):

```sh
make -C Applications/ycode/Tests check
```

Choose **Project > Debug** to build the selected target and open a GDB session.
GDB must be installed and available on `PATH`; set the `DebuggerPath` user
preference to use a specific GDB executable (for example,
`defaults write Ycode DebuggerPath /usr/bin/gdb`). This uses GDB's MI2 interface,
not LLDB. Build with debug symbols for source stepping.

**Project > Debugger** provides Go, Pause, Continue, Restart, Next, Step Into,
Step Out, and Up/Down stack-frame navigation. Debug initially waits for Go,
so you can set breakpoints before the program starts. Select a source line and
choose **Toggle Breakpoint at Selection** to add or remove a breakpoint;
Ycode remembers source breakpoints per project in its user preferences.
Breakpoint changes are reported in the console. Stopping or stepping selects
the reported source line in the editor.

The field below the console accepts GDB commands such as `print variable`,
`backtrace`, and `break main`. Press Return to send a command. **Project > Stop**
ends the debugger session; an inferior's normal exit leaves GDB available for
another Go. A failed build never launches the debugger.

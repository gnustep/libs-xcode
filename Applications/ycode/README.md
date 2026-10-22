# Ycode

Ycode is a GNUstep IDE for editing, building, running, testing, and debugging
projects. It uses libs-xcode to read Xcode projects, imports and exports
ProjectCenter projects, and works directly with Makefile folders. Interface
files open in their associated application, such as Gorm.

Choose **Info > Help** on GNUstep or **Help > Ycode Help** on macOS for the
bundled offline user guide. Help opens in a resizable, read-only window and is
available even with no project open. The guide covers everyday editing, builds,
Makefile settings, debugging, shortcuts, and troubleshooting.

This guide covers [installation](#build-and-installation),
[projects and navigation](#projects-and-navigation), [editing](#editing-and-search),
[tests](#running-tests), [terminal](#terminal), [debugging](#debugging),
[Makefile settings](#makefile-folders), and [architectures](#architecture-selection).
See the [repository README](../../README.md#12-ycode) for a screenshot and overview.

## Build and installation

Build the local libs-xcode framework and Ycode from the repository root:

```sh
make -C XCode
make -C Applications/ycode
```

On macOS with full Xcode selected, build against Apple's Foundation and AppKit
without installing GNUstep:

```sh
sh Tests/run-macos.sh
```

This builds the library, tools, and `build/macos/Debug/Ycode.app`, and runs the
library regression tests. Set `CONFIGURATION=Release` for a Release build.
After building the framework, rebuild only the app with:

```sh
xcodebuild -project Applications/ycode/Ycode.xcodeproj -target Ycode \
  -configuration Debug SYMROOT="$PWD/build/macos" CODE_SIGNING_ALLOWED=NO build
```

The app embeds XCode.framework and its editor/debugger bundles and can be moved
out of the build directory. Native model previews report that GNUstep archive
decoders are unavailable; waveform decoding requires the optional GNUstep
libsndfile integration. GNUstep builds continue to use the makefiles below.

The repository's top-level build and install include Ycode. You can also install it
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

## Projects and navigation

Use **File > New Project...** to choose a location, enter a project name, select
the project type, and choose Xcode, ProjectCenter, or GNUmakefile format in one panel. The
name field starts with `MyProject`; Create makes a new folder with that name in
the chosen location and generates the project inside it. There is no separate
name dialog.
Templates include Application, Tool, Bundle, Framework, Dynamic Library, and
Static Library. Applications start with `main.m`, `AppController.h/.m`, and a
`MainMenu.xib` containing a window and About/Quit menu. The controller is wired
as the application delegate and opens the window on launch. Source files,
resources, framework linkage, and Info.plist settings are included in the
project; ProjectCenter projects also include a GNUmakefile. GNUmakefile projects
contain the starter files and a GNUmakefile directly in the folder, without a
`.xcodeproj` or `.pcproj` package, and open as directory projects. Existing nonempty
project folders are never overwritten.

Use **File > Open Project...** to select an `.xcodeproj` package. Ycode loads
its `project.pbxproj` through libs-xcode and displays its groups, files, and
targets in the project navigator. Missing or invalid project contents produce
an error instead of opening an empty project.

Opening a file associated with Ycode from GWorkspace opens its project and then
selects that file in the editor. Ycode first checks open projects and directory
windows, choosing the most specific containing directory and bringing that window
forward. Matching uses absolute paths with directory boundaries and resolved
symlinks, so files with the same name in different directories remain separate.
Files outside all open projects open a separate project window; the active
project never receives unrelated files. Ycode searches the containing directory
and its parents for the nearest `.xcodeproj`, `.pcproj`, or Makefile folder. At the same
level, Xcode projects take precedence over ProjectCenter projects, then Makefile
folders; multiple projects of the same type are ordered by name. If none is
found, the file's containing directory opens as a directory project, even without
a Makefile. Repeated opens of the same project reuse its window. A plain folder
can be browsed and edited without a build system; building still requires one.

Double-click a file in the navigator to open it with the system's default
application for that file type. This includes Gorm/XIB interface documents and
source, image, sound, and other supporting files. Single-click continues to open
ordinary files in Ycode; interface documents wait for a double-click. Double-click
a group or directory to expand or collapse it.

The same **Open Project...** dialog imports ProjectCenter `.pcproj` packages
containing `PC.project` and older single-file `.pcproj` projects. Imported
groups expand immediately to show their files. Resource references resolve
under `Resources/` or the project's language directory. Application, Tool, Library, StaticLibrary, Framework,
and Bundle targets retain their source files, headers, resources, frameworks,
libraries, search paths, compiler/linker options, and referenced Info.plist.
Files remain in their original source directory. **Save Project** asks for an
`.xcodeproj` destination, initially beside the `.pcproj`; the original
ProjectCenter package is left unchanged. Custom GNUmakefile rules and subproject
build dependencies are not translated; subproject entries remain navigator references.
Aggregate and other unsupported target types are rejected.

Use **File > Export ProjectCenter Project...** to write a `.pcproj` package
containing `PC.project`. Export uses the selected target (or the only target)
and its default configuration. It writes current file membership, resources,
public headers, frameworks, libraries, and build options, and preserves metadata
from an imported ProjectCenter project. Paths are adjusted for the export
destination; source files stay where they are. Export leaves the active
document and its unsaved state unchanged.

Directories appear before files in the navigator. Compiled `.app` bundles
show their application icon when available, including resolved Products
references. Icons refresh after a successful build or clean; unbuilt products
use the generic icon.

## Editing and search

The editor defaults to a black background with white unhighlighted text. Saved
color preferences take precedence; **Preferences > Editor Colors > Restore
Defaults** applies the default palette.

The insertion cursor is red by default. Change it using **Preferences > Editor
Colors > Insertion cursor**. The color is saved and applied immediately to open
editors; **Restore Defaults** restores red.

Placing the caret immediately before or after `{}`, `()`, or `[]` highlights
its matching delimiter, including nested pairs. Punctuation inside C-style
comments and quoted strings is ignored. Highlighting is enabled by default;
toggle the **Preferences > Editor > Highlight matching delimiters** checkbox. Changes apply immediately to open editors. The highlight is temporary
and does not modify the file or its undo history.

The navigator's **Search** tab searches the contents of project file references,
including referenced folders and files outside the project directory. Enter text
and press Return for case-insensitive literal matches. Results show the file,
line, and matching text; select a result to open and select the occurrence.
Search includes unsaved changes in open editors and skips unreadable or binary
files. Run the search again after editing to refresh the results.

**Edit > Find...** and **Edit > Replace...** open a modeless panel for the
current editor tab. Search is literal, with options for case sensitivity and
wraparound. Use Next/Previous (or Return for Next), Replace, Replace & Find,
or Replace All. An empty replacement deletes matches. Replace operates on a
selected match; otherwise it finds the next match first. Replace All affects
only the current file and can be undone in one step. Switching tabs changes
the panel's target file. Searching alone does not mark the file changed.

Open text files update automatically when changed outside Ycode. Monitoring uses
inotify on Linux, kqueue on macOS/BSD, and Windows directory-change notifications;
there is no recurring file-polling timer. Watchers are shared by open files in
each directory, event bursts are coalesced, and closing the files releases their
watchers. Atomic replacement saves remain watched.

Clean files reload while preserving the selection and scroll position. Unsaved
local edits are preserved when the disk version changes; the tab gains a `!`
marker and an explanatory tooltip. Saving then offers **Overwrite**, **Reload**,
or **Cancel**. A deleted or unreadable file stays in the editor and is flagged
rather than replaced with empty text. Image and sound previews are not refreshed
by this text-file watcher. Platforms without one of these notification backends
log that monitoring is unavailable rather than silently falling back to polling.

Closing a tab or project, or quitting Ycode, asks whether to Save, Don’t Save,
or Cancel for each modified file. Cancelling or a failed save prevents closure.

Each project remembers its last selected source file and
reopens it next time. Closing the last source tab clears that saved selection;
missing files are skipped when reopening the project.

**File > Recent Documents** lists recently opened projects, newest first.
Choose an entry to reopen it, or **Clear Menu** to clear the saved history.
Missing projects remain listed but disabled.

Sound resources have an oscilloscope waveform icon in the navigator. Selecting one opens
a read-only preview and selects the **Sound** inspector, which shows a waveform,
duration, sample rate, and channel count. Use **Play**, **Pause/Resume**, and
**Stop** to audition it. Switching files or closing the window stops playback.
Supported playback formats depend on the installed NSSound codecs. GNUstep builds
enable background waveform decoding when `pkg-config sndfile` is available
(install the libsndfile development package before building); without it, playback
remains available and the inspector explains that waveform support is unavailable.

**Preferences > Indentation** controls tab and indentation width (1–16 spaces, default 2)
and whether indentation inserts spaces (the default) or literal tabs. Settings
are saved and update open editors immediately without rewriting existing whitespace.
The **Honor project .clang-format settings** option is enabled by default; turn
it off to use your chosen width and indentation style even in configured projects.
**Auto indentation (spaces)** independently sets how many literal spaces to add
after control statements and opening braces, and remove after closing braces (1–16, default 2).
This setting applies even when the project uses tabs or a different indent width.

The editor highlights keywords, types, function and method names, constants,
numbers, strings, and comments in Objective-C, C, C++, Swift, JavaScript,
TypeScript, Python, Ruby, and Java. Highlighting also covers GNUmakefiles, CMake files,
shell scripts, JSON, XML, property lists, and project files. GNUmakefile and
CMakeLists.txt are recognized by filename. Colors use lexical patterns;
they do not require a successful build or a language server.

Language support is supplied by versioned bundles. The included C-family,
Python, Ruby, Java, and standard-language bundles can be extended or overridden
without changing the editor. Python suite headers and Ruby blocks use the
configured indentation spaces; Ruby closing keywords align with their opening
blocks. **Edit > Comment/Uncomment Lines** toggles line comments using the
current language, supports undo, and marks the file modified when its content
changes. See [Language bundles](LANGUAGE_BUNDLES.md) for installation paths,
provider APIs, and the definition format.

**File > Save** and its keyboard shortcut save the active source tab. With no
source tab open, Save saves the project.

The navigator's **Add File...** and **Remove File from Project** actions update
project references and build-phase membership and mark the project as modified.
Removing a reference leaves the file on disk. Use **File > Save Project** to
save these changes while a source tab is open. Adding a group also marks the
project as modified.

Ycode starts without creating an untitled project. On GNUstep, the main menu
uses Info for About, Preferences, and Help, with Services, Hide, and Quit at
the top level. Build and run commands are in Project; window commands are in
Windows. The editor rulers show character columns across the top and source
line numbers down the side, following the font size and scroll position.
The editable area fills the window as it grows while long lines remain
horizontally scrollable. Return adds an indentation level after an opening
brace or a control statement awaiting its body, ignoring punctuation in comments
and strings. After a line beginning with a closing brace, Return removes the configured
auto indentation amount (two spaces by default), stopping at
column zero. A closing brace followed by a new
opening brace starts the new block instead. Completed statements do not add a level.
Tab reindents the current line or shifts selected lines, Shift-Tab
unindents selected lines, and closing delimiters align with their opening
line. Shift-arrow keys extend or contract the selection from its anchor.
Indentation defaults to two spaces and reads `IndentWidth`, `TabWidth`, and
`UseTab` from the nearest parent `.clang-format` file.

Control-statement bodies, including multiline conditions, use the auto
indentation preference and always insert spaces. Block indent/unindent measures mixed tabs and
spaces in columns, so Shift-Tab removes one indentation level even when tab
stops are wider. Shift-Tab also unindents the current line without a selection.
**Edit > Convert Tabs to Spaces** expands every tab in the current file to its
configured tab stop, preserving line endings and the selected text. Conversion
is one undoable edit and does not change indentation preferences.

## Running tests

In the **Test** tab, choose **Run Tests** to save edits and run the project's
tests. Results update with each XCTest case and show passed, failed, and skipped
states. On GNUstep, Xcode projects are built with `buildtool`, then their unit-test
bundles run with `xctest`; both tools must be on `PATH`. Tests with `TEST_HOST`
run inside their built application using Ycode's embedded test helper, so app
classes, resources, and launch setup are available. Startup failures appear in
the Test tab as well as Console. Native macOS uses
`xcodebuild test`. GNUmakefile projects use `make check`, and other make projects
use `make test`. Full output and build/runner errors appear in Console.
**Project > Stop** cancels the operation. Each run replaces the previous results.

Run the application regression checks with a working GUI display (or under
`xvfb-run -a` on a headless GNUstep system):

```sh
make -C Applications/ycode/Tests check
```

## Terminal

Choose **Project > Open Terminal** (**Product > Open Terminal** on macOS), or
select **Terminal** beside Console, Issues, and Debugger. A separate interactive
shell starts in each project's directory the first time you open its terminal.
It uses your `SHELL`, falling back to your account's shell or `/bin/sh`.
Switching tabs and hiding the bottom area keep the shell running. Closing the
project hangs up the shell and its foreground job.
The menu changes to Close Terminal while the terminal is visible. Closing hides
the pane and preserves the shell session; Open Terminal brings it back.

Use the terminal for custom `make` targets, Git, scripts, and interactive tools.
Console continues to display Ycode-managed build and run output. **Project > Stop**
controls those operations; in Terminal, **Ctrl+C** interrupts the foreground
job and **Ctrl+D** sends end-of-input. Type `exit` to leave the shell; Return on
the exited screen starts a new one. **Restart Terminal** in its context menu
hangs up the current session and starts again in the project's original directory.

Drag to select text, then use **Edit > Copy** or the context menu. **Paste**
supports bracketed-paste mode when requested by the shell or program. Scroll
with the scrollbar, mouse wheel, trackpad, or Shift+Page Up/Down through saved lines (5,000 by default);
typing returns to the live screen. When a program enables mouse reporting,
hold Shift to select text or use the context menu instead of sending mouse input.
Resizing the pane updates the PTY size and notifies the foreground program.

**Preferences > Terminal** controls the fixed-pitch font and size, default text
and background colors, scrollback limit, audible bell, and permission for
programs to blink the cursor. Settings apply immediately to all open terminals
and are saved for future sessions. Font changes update the terminal's row and
column counts without restarting its shell. Program-specified ANSI colors stay
intact. Scrollback can retain up to 50,000 lines; choose 0 to disable it.
Reducing the limit discards the oldest saved lines. **Restore Defaults** resets
only Terminal preferences, leaving editor and other pane settings unchanged.

Use the font button to open the native Fonts panel
and choose a fixed-pitch font (6–72 points). Text, background, and cursor colors
apply immediately through the Color panel. The cursor defaults to red. Choose
Program controlled, Block, Outline, Vertical line, or Underline for its shape.

The bundled MIT-licensed [libvterm](https://www.leonerd.org.uk/code/libvterm/)
0.3.3 engine handles ANSI/VT100 and many VT220/xterm sequences: cursor motion,
erase/insert/delete, scrolling regions, saved cursors, alternate screens,
DEC line drawing, UTF-8 with wide/combining characters, 16/256-color and
24-bit color, bold/italic/underline/reverse/conceal/strike/blink, application
cursor/keypad modes, function keys, mouse reporting, and terminal queries.
The child sees `TERM=xterm-256color` and `COLORTERM=truecolor`.

This is a text terminal, not complete xterm emulation. Sixel/inline graphics,
OSC hyperlinks and clipboard access, and VT double-height/double-width line
rendering are not implemented. Font coverage determines which Unicode glyphs
can be displayed. Scrollback does not reflow when the pane width changes.
Interactive sessions currently require POSIX PTYs (GNUstep on Unix or macOS);
Windows reports that the terminal is unavailable. No external terminal app or
separately installed libvterm is required.

## Debugging

Choose **Project > Debug** to build the selected target and open a GDB session.
Debugger support is supplied by executable backend bundles. The included GDB
bundle provides the existing debugging workflow; additional backends can supply
their own launch commands, stepping, breakpoints, and variables without changing
the editor or debugger pane. Select a backend with the `YCodeDebuggerBackend`
user default or the project's `DebuggerBackend` setting. See
[Debugger bundles](DEBUGGER_BUNDLES.md) for installation and the provider API.

GDB must be installed and available on `PATH`; set the `DebuggerPath` user
preference to use a specific GDB executable (for example,
`defaults write Ycode DebuggerPath /usr/bin/gdb`). This uses GDB's MI2 interface,
not LLDB. Build with debug symbols for source stepping.

**Project > Debugger** provides Go, Pause, Continue, Restart, Next, Step Into,
Step Out, and Up/Down stack-frame navigation. Debug initially waits for Go,
so you can set breakpoints before the program starts. Select a source line and
choose **Toggle Breakpoint at Selection** to add or remove a breakpoint;
Ycode remembers source breakpoints per project in its user preferences.
The bottom pane has separate **Console**, **Issues**, **Debugger**, and **Terminal** tabs.
The Debugger tab contains the GDB transcript, icon buttons for execution
controls, and a command field. Hover over a button to see its action name. Build and program output remain in Console. Starting a debugger session
or stopping at a source location selects the Debugger tab.

While debugging, a gutter appears beside the source line numbers. Click it to
add or remove a breakpoint; Shift-click a breakpoint to enable or disable it.
These actions also work while the program is running under GDB; pausing first
is not required.
Breakpoints can only be set in source implementation files, not headers or
resource/configuration files. The breakpoint gutter and menu command follow
this restriction.
Enabled breakpoints are red dots, including those awaiting resolution by GDB;
disabled breakpoints are grey.
A yellow arrow marks the current stopped line, drawn behind the breakpoint dot
when both occupy that line. The arrow clears on resume, exit, or session end.
GDB breakpoint commands also update the markers. Breakpoints relocated by GDB
appear at the executable source line. Saved breakpoints remain visible outside
a debug session, and their enabled/disabled state is remembered per project.
Before Go, a source file in a shared library may produce GDB's "No source file
named" message. If GDB accepts a pending breakpoint, Ycode reports that it will
be resolved when the library loads. For example, GormCore breakpoints normally
resolve when Gorm starts. A breakpoint that remains pending requires checking
the loaded library, its debug symbols, and source path.

Both Console and Debugger output are read-only but selectable. Use **Edit >
Copy**, the right-click **Copy** menu, or Ctrl+C to copy selected output.
Ctrl+A or the right-click **Select All** menu selects the full transcript.

The Debugger tab has a vertical split with a grid-free variables outline
to the left of its output. Name, Value, and Type columns show locals (including arguments)
and globals from the selected frame's source file. Expand structures, arrays,
and pointers to inspect children; large values show up to 200 children per
expansion. Values refresh when execution pauses or the selected frame changes,
and clear on resume. Debug symbols are required; unavailable values are reported
in the outline. The variables icon at the right of the debugger toolbar shows or hides the left pane. Its visibility
and divider proportion are saved in user defaults and restored next time.

The field in the Debugger tab accepts GDB commands such as `print variable`,
`backtrace`, `break main`, `disable 1`, and `enable 1`. Press Return to send a
command. **Project > Stop** ends the debugger session; an inferior's normal exit
leaves GDB available for another Go. A failed build never launches the debugger.

## Makefile folders

Use **File → Open Project** and select `GNUmakefile`, `makefile`, or `Makefile`,
or the folder containing it. Opening the makefile uses its containing folder as
the project and reuses that folder's window if already open.
Ycode shows the folder's files and subfolders without
creating an Xcode project or changing its makefiles. Hidden entries and the
`obj` and `build` directories are omitted from the navigator; directory symlinks
are not traversed. Use the navigator's **Refresh Folder** menu after adding files
outside Ycode. **Add Group** creates a real subdirectory in this mode.

Build invokes `make` in the selected folder, Clean invokes `make clean`, and
Tests invokes `make check` for GNUmakefile projects or `make test` otherwise.
Compiler output appears in the console and issues panes as usual.

Optional settings live in `.ycode.plist` inside the folder. Use **File > Create .ycode.plist** to create and open this file for editing. The command is enabled
for directory and ProjectCenter (`.pcproj`) projects without an existing settings file.
For `.pcproj` projects it writes beside the project, in the source directory,
not inside the project package. It preserves current
settings and supplies `CleanTarget = clean` and `TestTarget = check` for
GNUmakefile projects (`test` otherwise). The command sits below **Save Project**
and is disabled for Xcode (`.xcodeproj`) projects or when the file already exists.
The generated `Executable` uses an existing configured path, the ProjectCenter
runnable product, or a built application/tool discovered in a directory project.
Application bundles use the executable inside the bundle, including its declared
executable name. Paths within the project are stored relative to its directory.
If no executable can be identified unambiguously, the command opens a file
chooser; select the executable to use for Run and Debug. Cancelling leaves the
settings file uncreated. Build targets can be added manually. For example:

```plist
{
    MakeTargets = (all, application, tools);
    BuildTarget = all;
    CleanTarget = clean;
    TestTarget = check;
    Executable = "obj/My Tool";
}
```

Reopen the folder after editing these settings. `MakeTargets` supplies the
Target toolbar choices; Automatic uses `BuildTarget`, or make's default target
when omitted. Clean and Tests use their own targets. `Executable` is an absolute
path or a path relative to the folder, and enables Run and Debug after building.
For an application bundle, specify the executable inside the bundle. Ycode does
not parse arbitrary makefiles to discover targets. For directory projects without
a built product, build first or select an existing executable when creating settings.
Save Project writes only `.ycode.plist`; makefiles remain authoritative for
sources and dependencies. Project Save As does not convert or move this folder.

## Architecture selection

The status field after Architecture shows `Project Name - Activity - Build Time`,
followed by a separator. Build time updates in seconds while building and retains
the completed duration until the next build or project change. Activity reflects
building, running, debugging, testing, cleaning, failure, or cancellation; otherwise
it shows Ready. Before the first build, the duration is shown as a dash.

The **Architecture** toolbar selector follows Target. Native leaves the build
command and environment unchanged. Explicit selections are saved per project;
controls are disabled while a build or debug session is active.

For Makefile projects, Ycode passes `ARCH=<selection>` to make. All selected
builds receive `ARCH`, `ARCHS`, `CURRENT_ARCH`, and `YCODE_ARCH` in their child
process environment. On macOS, xcodebuild additionally receives `-arch`.
GNUstep buildtool does not implement `-arch`; its compiler and linker must instead
come from a configured toolchain environment.

Configure non-native toolchains in the project folder's `.ycode.plist`, under
`ArchitectureEnvironments`. Each architecture maps to a dictionary of environment
variable names and string values (for example `PATH`, `GNUSTEP_MAKEFILES`, and
compiler/sysroot settings appropriate to your toolchain). These overrides apply
only to that project's child processes. Additional architecture keys appear in
the selector. Native does not apply any overrides.

Ycode rejects a non-native GNUstep build when its environment entry is missing
or empty. Supplying an entry does not install or validate the cross-compiler,
SDK, runtime, or target libraries: configure those first, and ensure your
makefile or buildtool setup uses them. The build scripts must honor the selected
architecture and isolate their output directories, or you must Clean before
switching architectures to prevent reuse of incompatible objects. Running and
debugging foreign binaries still require an appropriate execution environment.

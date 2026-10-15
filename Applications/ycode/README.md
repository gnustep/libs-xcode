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

Use **File > New Project...** to choose a location, enter a project name, select
the project type, and choose Xcode or ProjectCenter format in one panel. The
name field starts with `MyProject`; Create makes a new folder with that name in
the chosen location and generates the project inside it. There is no separate
name dialog.
Templates include Application, Tool, Bundle, Framework, Dynamic Library, and
Static Library. Applications start with `main.m`, `AppController.h/.m`, and a
`MainMenu.xib` containing a window and About/Quit menu. The controller is wired
as the application delegate and opens the window on launch. Source files,
resources, framework linkage, and Info.plist settings are included in the
project; ProjectCenter projects also include a GNUmakefile. Existing nonempty
project folders are never overwritten.

Use **File > Open Project...** to select an `.xcodeproj` package. Ycode loads
its `project.pbxproj` through libs-xcode and displays its groups, files, and
targets in the project navigator. Missing or invalid project contents produce
an error instead of opening an empty project.

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

**Preferences > Tabs** controls tab and indentation width (1–16 spaces, default 2)
and whether indentation inserts spaces (the default) or literal tabs. Settings
are saved and update open editors immediately without rewriting existing whitespace.
The **Honor project .clang-format settings** option is enabled by default; turn
it off to use your chosen width and indentation style even in configured projects.

The editor highlights keywords, types, function and method names, constants,
numbers, strings, and comments in Objective-C, C, C++, Swift, JavaScript,
TypeScript, and Python. Highlighting also covers GNUmakefiles, CMake files,
shell scripts, JSON, XML, property lists, and project files. GNUmakefile and
CMakeLists.txt are recognized by filename. Colors use lexical patterns;
they do not require a successful build or a language server.

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
and strings. Closing braces and completed statements do not add a level.
Tab reindents the current line or shifts selected lines, Shift-Tab
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
The bottom pane has separate **Console**, **Issues**, and **Debugger** tabs.
The Debugger tab contains the GDB transcript, execution controls, and command
field. Build and program output remain in Console. Starting a debugger session
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

The field in the Debugger tab accepts GDB commands such as `print variable`,
`backtrace`, `break main`, `disable 1`, and `enable 1`. Press Return to send a
command. **Project > Stop** ends the debugger session; an inferior's normal exit
leaves GDB available for another Go. A failed build never launches the debugger.

## Makefile folders

Use **File → Open Project** and select a folder containing `GNUmakefile`,
`makefile`, or `Makefile`. Ycode shows the folder's files and subfolders without
creating an Xcode project or changing its makefiles. Hidden entries and the
`obj` and `build` directories are omitted from the navigator; directory symlinks
are not traversed. Use the navigator's **Refresh Folder** menu after adding files
outside Ycode. **Add Group** creates a real subdirectory in this mode.

Build invokes `make` in the selected folder, Clean invokes `make clean`, and
Tests invokes `make check` for GNUmakefile projects or `make test` otherwise.
Compiler output appears in the console and issues panes as usual.

Optional settings live in `.ycode.plist` inside the folder. For example:

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
not guess executable paths or parse arbitrary makefiles to discover targets.
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

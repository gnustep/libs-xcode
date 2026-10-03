# Repository guidance

## Project layout

libs-xcode is the GNUstep Objective-C library for parsing and building Xcode
projects and workspaces. Use the implementation, makefiles, and tests to verify
behavior; some README roadmap statements predate current functionality.

- `XCode/`: framework sources. `PBX*` classes model projects, targets, files,
  and build phases; `XC*` classes handle configurations and workspaces;
  `GSXC*` classes provide build contexts, operations, and generator support.
- `XCode/Resources/`: framework mappings, language codes, and build resources.
- `Tools/buildtool/`: command-line frontend; argument parsing lives in
  `ToolDelegate.m`. `Tools/pc2xc/` and `Tools/pcpg/` contain conversion tools.
- `Generators/`: Makefile, CMake, ProjectCenter, and ProjectBuilder generator
  bundles. CMake here is an output format, not the repository build system.
- `Tests/main.m`: regression test executable and its fixtures/helpers.
- `Applications/ycode/`: AppKit IDE, built separately from the root aggregate.
- `Documentation/`: gsdoc manual, generated API documentation, and man pages.

## Build and verification

Use an installed GNUstep development environment with an Objective-C compiler,
runtime, GNUstep Base, and GNUstep make. Ycode additionally needs GNUstep GUI.
The makefiles discover `GNUSTEP_MAKEFILES` through `gnustep-config` when it is
unset. If necessary, source the installed `GNUstep.sh` before building.

Run from the repository root:

```sh
make                       # XCode, generators, tools, and tests
make check                 # aggregate test entry point used by CI
```

For focused library work:

```sh
make -C XCode
make -C Tests check
```

`Tests/GNUmakefile` sets library search paths to the locally built framework
and supplies the arguments expected by the parser tests. Use this target
instead of invoking the test binary from an arbitrary directory: tests read
`../libs-xcode.xcodeproj/project.pbxproj` relative to `Tests/`.

- Build Ycode changes with `make -C Applications/ycode`; the root build does
  not validate them. Check affected UI behavior when changing controllers or
  interface resources.
- Build documentation with `make -C Documentation` when changing gsdoc.
- `.github/workflows/main.yml` defines GCC and Clang GNUstep runtime variants.
  Preserve compatibility with both compilers and legacy/modern runtimes.
- CI installs into its configured prefix before testing. Do not install into
  a system prefix merely to validate an ordinary source edit.
- Report the checks actually run and any missing prerequisites. Documentation
  edits alone generally need a diff/whitespace review rather than a rebuild.

## Objective-C and formatting conventions

- Match the surrounding file. Established GNUstep style uses two-space
  indentation, braces on separate lines, and indented control-flow braces.
  Existing files mix tabs and spaces; avoid unrelated whitespace rewrites.
- Preserve Objective-C spacing such as `- (id) initWithName: (NSString *)name`
  and `[object setName: name]`; align multiline selector arguments with nearby
  code. Keep actual tabs in makefile recipes.
- Use manual reference counting. Follow existing `ASSIGN`, `RETAIN`,
  `RELEASE`, `AUTORELEASE`, and explicit retain/release patterns; balance
  ownership and call `[super dealloc]`. Do not introduce ARC requirements.
- Retain the existing class prefixes, header guards, `#import` conventions,
  and Foundation collection APIs. Avoid introducing syntax or APIs that
  unnecessarily exclude the supported GNUstep toolchains.
- Keep public API comments consistent with the existing gsdoc-style comments
  in headers. Preserve copyright and license notices; follow the appropriate
  neighboring library or application license header for new source files.
- Add sources and public headers to the relevant `GNUmakefile` lists; expose
  public API through `XCode/XCode.h` where appropriate. Check the native
  `.xcodeproj` and `XCode.podspec` when a change affects those build paths.

## Behavior to preserve

Recent history includes fixes for build-setting inheritance, UIKit/XCTest
linking, header search paths, and Info.plist handling. When touching these areas:

- Preserve both string and array settings, quoted/escaped paths, and both
  `$(inherited)` and `${inherited}`. An override without an inheritance token
  replaces its parent value.
- Keep target contexts isolated. Repeated builds and sibling targets must not
  accumulate flags or inherit another target's overrides.
- Route framework linkage through the existing framework/configuration mapping
  logic. Test bundles need XCTest linkage without duplicate flags; do not
  reintroduce a blanket UIKit-to-AppKit substitution.
- Respect existing GNUstep, native macOS, and Windows conditional paths.
  Avoid unconditional Apple SDK assumptions in portable build code.
- Preserve original buildtool subcommands alongside xcodebuild-style options.
  Distinguish options accepted for compatibility from implemented behavior.

Extend `Tests/main.m` for behavioral fixes using its `testAssert` helpers and
register new test functions in `main`. Restore shared build contexts and
environment state after tests. Prefer focused regression cases demonstrating
the failure, including quoted paths or repeated builds when relevant.

## Change scope and documentation

Keep patches focused and preserve unrelated working-tree changes. Edit source
resources rather than generated copies inside app/framework bundles. Do not
add `obj/`, `build/`, `*.app`, `XCode.framework`, `*.generator`, generated
reference documentation, or personal Xcode workspace state to a patch.

For CLI changes, keep `README.md`, `Tools/buildtool/README.md`, and
`Documentation/buildtool.1` consistent. Buildtool configuration guidance lives
in `Documentation/README.md`. Check all relevant generators when changing
product types or generated build settings.

Commit history uses short imperative subjects such as "Fix handling of
Info.plist" and "Add Unit tests", without a required Conventional Commits
prefix. Use a specific subject describing the change. Summaries should explain
the affected behavior and verification; avoid release/version or broad
ChangeLog edits unless the task calls for them.

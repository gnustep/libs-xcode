# Xcode project build support: gaps

Assessment date: 2026-10-15.

This assessment concerns the library's ability to build `.xcodeproj` files,
not Ycode's editor features. The library has useful support for GNUstep
C/Objective-C projects, but several implementation paths can produce incomplete
or stale builds. Parsing a project successfully does not establish that all of
its build behavior is supported.

The findings below come from implementation review. They have not all been
independently reproduced with failing project fixtures. `make -C Tests check`
passed during the assessment.

## 1. Object-file name collisions

`Sources/One/Utilities.m` and `Sources/Two/Utilities.m` both map to
`build/<target>/Utilities.m.o`. Compilation can overwrite one object, and linking
collects the same path twice.

Object paths should preserve source identity, using project-relative paths or
another stable, collision-resistant mapping shared by compilation and linking.

Implementation: [PBXFileReference.m](XCode/PBXFileReference.m),
[PBXSourcesBuildPhase.m](XCode/PBXSourcesBuildPhase.m).

## 2. Incomplete incremental-build tracking

Rebuild decisions compare source and object timestamps. They do not track
included headers or changes to compiler arguments. Editing a header or changing
build settings can therefore leave stale objects. Output directories also lack
configuration separation.

Use compiler-generated dependency files and command fingerprints, and isolate
outputs by configuration and architecture. Verify both changes that require a
rebuild and unchanged inputs that should avoid one.

Implementation: [PBXFileReference.m](XCode/PBXFileReference.m),
[GSXCBuildDatabase.m](XCode/GSXCBuildDatabase.m),
[PBXNativeTarget.m](XCode/PBXNativeTarget.m).

## 3. Copy Files phases silently do nothing

`PBXCopyFilesBuildPhase` inherits the base class's no-op `build` method and has
a no-op `generate` method. Projects embedding frameworks, helper executables,
or other products can report success with missing contents.

Implement destination handling and copying, with errors propagated to the
build result. Until supported, these phases should produce an explicit
unsupported-operation error instead of reporting success.

Implementation: [PBXCopyFilesBuildPhase.m](XCode/PBXCopyFilesBuildPhase.m),
[PBXBuildPhase.m](XCode/PBXBuildPhase.m).

## 4. Incomplete build-setting evaluation

Basic project/target inheritance exists, but configuration application only
processes the embedded settings dictionary. It does not load
`baseConfigurationReference` `.xcconfig` files or evaluate conditional settings
such as SDK/architecture selectors. Standard compiler settings also need broader
coverage.

Add `.xcconfig` loading, include handling, conditional evaluation, and defined
precedence. Preserve existing string/array handling, quoted paths, and both
`$(inherited)` and `${inherited}` forms.

Implementation: [XCBuildConfiguration.m](XCode/XCBuildConfiguration.m),
[XCBuildConfiguration.h](XCode/XCBuildConfiguration.h),
[PBXFileReference.m](XCode/PBXFileReference.m).

## 5. Incorrect target dependency ordering

The dependency traversal inserts leaf dependencies, then appends remaining
targets in project order. A chain such as A → B → C can consequently become
C, A, B. There is no explicit cycle detection in that traversal.

Use a topological ordering with clear cycle diagnostics. Test chains, shared
dependencies, target selection, and cross-project dependencies.

Implementation: [PBXProject.m](XCode/PBXProject.m),
[PBXTargetDependency.m](XCode/PBXTargetDependency.m),
[PBXContainerItemProxy.m](XCode/PBXContainerItemProxy.m).

## 6. Custom build rules are not executed

Native targets store `buildRules`, but their build method executes dependencies
and phases without applying those rules. There is also a direct getter bug:
`PBXBuildRule.script` returns `_compilerSpec` instead of `_script`.

Fix the getter and implement rule matching, execution, and generated-output
dependencies. Generated sources must become available before their consumers
are compiled.

Implementation: [PBXBuildRule.m](XCode/PBXBuildRule.m),
[PBXNativeTarget.m](XCode/PBXNativeTarget.m).

## 7. Shell-script phase compatibility and dependency gaps

Generated scripts unconditionally use `set -eo pipefail`, despite honoring the
project's chosen shell. This fails with shells lacking `pipefail`. Scripts are
written as ASCII, and exported values are not safely shell-escaped. Input/output
file lists are stored but not used for dependency scheduling.

Respect the selected shell, preserve Unicode scripts, escape exported values,
and propagate script-write and execution failures. Incorporate declared inputs,
outputs, and file lists into build scheduling.

Implementation: [PBXShellScriptBuildPhase.m](XCode/PBXShellScriptBuildPhase.m).

## 8. Partial support for modern project features

- No Swift Package dependency implementation was found in this review.
- Unknown object classes return `nil`, potentially dropping referenced objects.
- Synchronized folders have basic enumeration but lack exception-set handling.
- `buildtool -scheme` is a target-name alias, not actual scheme processing.

Unsupported build-affecting objects should be diagnosed clearly. Add explicit
support and representative fixtures for each feature before advertising it as
supported.

Implementation: [PBXCoder.m](XCode/PBXCoder.m),
[PBXFileSystemSynchronizedRootGroup.m](XCode/PBXFileSystemSynchronizedRootGroup.m),
[PBXTarget.m](XCode/PBXTarget.m),
[ToolDelegate.m](Tools/buildtool/ToolDelegate.m).

## Recommended priorities

1. Correct object-path uniqueness, incremental-build tracking, and dependency
   ordering; fail explicitly for unsupported phases.
2. Implement Copy Files phases and `.xcconfig` evaluation.
3. Implement custom build rules and improve shell-script phase handling.
4. Extend modern project compatibility with explicit support boundaries.

## Verification gaps

The existing [regression suite](Tests/main.m) covers useful parser, inheritance,
linking, and command-result behavior. Passing it does not yet establish reliable
builds across representative `.xcodeproj` projects.

Add end-to-end fixtures that compile, link, and inspect products for the cases
above. In particular, verify duplicate source basenames, header-only edits,
configuration switches, dependency chains and cycles, embedded products,
`.xcconfig` inheritance, generated sources, and shell-script failures.

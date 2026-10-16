# Debugger bundles

Ycode's debugger backends are executable Foundation bundles. The application
owns process transport, toolbar controls, transcripts, source navigation, and
the variables outline. Backends translate generic actions into debugger commands
and interpret incoming bytes into session state, source locations, breakpoints,
and variables.

The included **GDB** bundle contains the existing GDB/MI2 implementation. It
preserves the existing breakpoint defaults and the `DebuggerPath` setting. GDB
must still be installed; the bundle is an adapter, not a copy of the GDB program.
Other debuggers need their own backend implementation.

## Discovery and selection

On first use, Ycode scans its `Debuggers` resource directory and then
`Ycode/Debuggers` under the system, local, and user Library directories returned
by Foundation. For example, a GNUstep user directory may be
`~/GNUstep/Library/Ycode/Debuggers`; macOS normally uses
`~/Library/Ycode/Debuggers`. Bundle names are sorted within each directory.
Later valid bundles with the same identifier override earlier registrations.
Use unique Objective-C class names even when overriding an identifier; loaded
classes cannot safely be replaced or unloaded.

GDB (`gdb`) is the default. Set the `YCodeDebuggerBackend` user default to select
another installed backend. A project's settings dictionary can override this
with `DebuggerBackend`, for example in a directory project's `.ycode.plist`:

```xml
<key>DebuggerBackend</key>
<string>gdb</string>
```

Selection happens when a project's debugger session is first created. Reopen
the project after changing its selection, and restart Ycode after installing
bundles. An unknown selection fails with an error; it does not silently start a
different debugger. Each project gets its own backend instance.

## Backend contract, version 1

Implement the Foundation-only protocol in
[YCodeDebuggerBackend.h](YCodeDebuggerBackend.h). Set `NSPrincipalClass` to that
class in the platform's bundle information dictionary. Include a `Debugger.plist`
resource containing an integer `APIVersion` of **1** and a string `Identifier`.
The principal class must return the same API version and identifier from
`+debuggerAPIVersion` and `+debuggerIdentifier`, and a readable name from
`+debuggerDisplayName`.

The loader checks the manifest before loading executable code, then validates
metadata and all required instance selectors before registering the backend.
Executable bundles run inside Ycode; install only trusted code built for the
host platform and Objective-C runtime.

The protocol separates these responsibilities:

- **Launch:** return a command and an array of arguments for the target
  executable. Ycode starts it in the project directory using the configured
  environment. Argument boundaries are preserved; no shell command is built.
- **Transport:** `receiveData:` receives arbitrary stdout byte chunks. Buffer
  incomplete messages in the backend. Send complete UTF-8 commands through
  `debuggerBackend:sendCommand:`; include required framing and terminators.
- **Actions:** `canPerformAction:` governs toolbar/menu availability;
  `performAction:` implements Run, Pause, Continue, Restart, Next, Step, Finish,
  Frame Up, Frame Down, and Stop. `consoleCommand:` handles user-entered backend
  commands. The host also terminates the task when stopping the session.
- **State:** report readiness, running state, and the stopped source location.
  Emit `debuggerBackendDidChange:` whenever visible state changes. The session
  facade republishes `YCodeDebuggerDidChangeNotification` with its own stable
  identity, so views never depend on a backend class.
- **Output:** send debugger transcripts and target output through separate
  delegate callbacks. Report stopped locations through the navigation callback.
- **Breakpoints:** implement file eligibility, toggling, enable/disable, and
  line/state queries. `setBreakpointStorageKey:` supplies the existing
  per-project defaults key. GDB continues to read older saved formats.
- **Variables:** return an object conforming to `YCodeDebuggerVariableSource`,
  or nil when unavailable. The source owns dictionary nodes with `name`,
  `value`, `type`, `numchild`, and `children` keys. `loadChildren:` may fetch
  children asynchronously, then notify a state change. `setEnabled:` controls
  whether the pane requests values.
- **Lifecycle:** `reset` clears transient protocol/frame state while retaining
  user breakpoints. Delegates are non-owning references. Use manual reference
  counting, and deliver callbacks on the main thread.

The included implementation is in [DebuggerBundles/GDB](DebuggerBundles/GDB).
It has no dependency on the application's Objective-C classes or AppKit.
The stable application facade is [YCodeDebugger.h](YCodeDebugger.h).

## Building and checking

`make -C Applications/ycode` builds the bundle and embeds it in the app.
`make -C Applications/ycode/Tests all` does the same for test resources. The
native Xcode project has a build phase that compiles a Foundation-only native
bundle using `DebuggerBundles/build-macos.sh` and signs it when signing is
configured.

From the Ycode Tests directory, run `ycode_tests --check-debugger-bundles` in a
GUI session or virtual X display, with the local XCode framework on the library
search path. This checks bundle loading, API rejection, independent sessions,
backend-neutral actions, saved breakpoints, notifications, and variable queries.
`--check-target-toolbar` also exercises the asynchronous build/debug launch,
gutter interactions, and cleanup using a deterministic debugger process fixture.

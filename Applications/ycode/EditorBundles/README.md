# Ycode editor bundles

Ycode loads the Text, Image, Sound, and Model bundles from its `Editors` resources.
It also searches `Library/Ycode/Editors` in the system, local, and user domains,
using Foundation's platform-specific library paths. Restart Ycode after adding
an editor. Bundles are native code and remain loaded for the process lifetime.

Each bundle's principal class subclasses `YCodeEditorDocument`, which implements
`YCodeEditorPlugin`. Override the class methods `editorIdentifier`, `editorKind`,
`editorPriority`, and `canOpenFilePath:`. API version 1 is inherited from the base
class; incompatible versions are rejected. Use a unique Objective-C class name
and identifier. Later search directories replace matching identifiers. Among
matching editors, the highest priority wins; equal priorities are resolved by
identifier in alphabetical order. Text uses priority -1000 as the fallback;
Image uses 100, Sound uses 200, and Model uses 300. A selected editor's load failure is returned
to the caller rather than trying to interpret the same file as text.

Override `initWithFilePath:`, `editorView`, and `loadFromFile` to own the editor's
view and data. Call the superclass initializer, use manual reference counting,
and balance ownership in `dealloc`. Keep the root view stable across reloads.
A successful load should call `setModified:NO` and update `_lastModified`.
`editorKind` values `image` and `sound` select the existing media inspectors;
image documents also override `image`. Other kinds use the normal file inspector.

The default document is read-only. An editable editor overrides `isEditable`
and `writeContentsToFile`, and calls `setModified:YES` when its content changes.
The host owns tabs and close prompts; `saveToFile` handles saving and notifications.
Editors can override `checkForExternalChanges` to detect conflicts, setting
`_externalChange` and posting `YCodeFileModificationDidChange` when appropriate.
Keep the document's controller reference non-owning. Notify the controller with
`YCodeCurrentDocumentDidChangeNotification` when inspector data changes.

Text-only methods return empty values in the base class. Text editors expose
`textView`, `scrollView`, and `syntaxHighlighter` for the existing text commands.
The Text bundle owns text document behavior and uses Ycode's shared text-view,
ruler, syntax-highlighting, and language services. Image and Sound retain their
existing preview behavior; sound playback and waveforms remain in the Sound
inspector. This refactor does not add image or audio editing tools.

Build with `make -C Applications/ycode`. The application build embeds the four
bundles automatically. `make -C Applications/ycode/Tests all` also packages them
for tests; `ycode_tests --check-editor-bundles` checks discovery and selection.
The existing editing, external-file, image, and sound tests cover their behavior.

## Interface model viewer

The Model bundle previews `.gorm` files/packages, `.xib` files, and keyed `.nib`
files/packages using GNUstep GUI's decoders. It does not link to Gorm. Select a
model in the navigator to preview it; double-click still opens its associated
application. Windows (including initially hidden windows) and standalone views
appear as widgets in framed previews on a scrollable canvas. Menus and submenus
use native menu views, including separators, checkmarks, and key equivalents.
Visual previews wrap into rows within the available width and reflow when the
editor is resized. Drag a simulated window’s title bar to reposition it on the
canvas; manually positioned windows retain their positions where space permits.
These positions last only until the preview is reloaded. Oversized previews scale down proportionally without changing
the archived widget geometry; additional rows are accessible by vertical scrolling. Nonvisual
objects appear in a separate scrollable pane on the left, using Gorm’s original
object, File’s Owner, First Responder, and Font Manager icons. These image
resources are bundled locally; no Gorm installation is needed. Attribution and
the image license are included in the Model bundle. Menu items, table columns, and cells are
part of the graphical previews and are excluded from the nonvisual object pane. The viewer does not save or modify model files.

The Connections inspector beneath the preview lists the model’s archived
connections, including outlets, actions, bindings, and other connector types.
Each row shows its type, source, outlet/action name, and destination. Actions
are shown from sender to receiver consistently across formats. Archived names
and XIB identifiers distinguish objects; File’s Owner and First Responder are
labeled explicitly. Resize columns or scroll horizontally to inspect long values;
hover over a cell to see its full text. The inspector is read only and does not
establish connections. Empty and unsupported models display an explicit status.

The decoder does not awaken the interface or establish outlet/action connections.
Custom-class templates use available base classes; application code and Gorm
palettes are not loaded. Appearance follows the installed GNUstep theme. This is
an archived-layout preview, not a running application or an interface designer.
Support is limited to the formats understood by GNUstep GUI's archive decoders;
unsupported or malformed models display an explanation inside the editor pane.
Other Gorm plugin formats, such as CIB and Gux, are not supported by this bundle.

`ycode_tests --check-editor-bundles` includes model preview regressions.
Add `--model-preview-screenshot` to write a rendered preview to
`/tmp/ycode-model-preview.png` and a widget fixture to
`/tmp/ycode-model-widgets.png` for visual inspection.

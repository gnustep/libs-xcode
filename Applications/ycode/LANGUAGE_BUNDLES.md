# Ycode language bundles

Ycode loads `.ycode-language` bundles at startup. Language definitions supply
highlighting, comment/string recognition, indentation rules, and line comment
markers. The editor owns text storage, rendering, preferences, undo, and document
saving. Build systems and debuggers remain independent.

Included bundles:

- **CFamily**: C, Objective-C, Objective-C++, and C++.
- **Python**: Python, including comments, triple-quoted strings, and indentation
  after single-line suite headers.
- **Ruby**: Ruby (`rb`, `rake`, `gemspec`, `ru`), Rakefile, Gemfile, Guardfile,
  and Vagrantfile. Supports block indentation, `do` blocks, and alignment of
  `end`, `else`, `elsif`, `when`, `rescue`, and `ensure`.
- **Java**: Java, including annotations, text blocks, and brace indentation.
- **Standard**: the existing JavaScript/TypeScript, Swift, Make, CMake, shell,
  JSON, plist, and XML definitions.

## Installation and precedence

Ycode first loads `Languages` in its application resources, followed by
`Ycode/Languages` inside the system, local, and user Library directories returned
by Foundation. For example, a GNUstep installation may use
`~/GNUstep/Library/Ycode/Languages`; macOS normally uses
`~/Library/Ycode/Languages`. Restart Ycode after installing or editing a bundle.

Directories are scanned once, with bundle filenames sorted. Later definitions
replace earlier registrations for the same extension or exact filename. Exact
filenames take precedence over filename regex patterns, then extensions. Filename
patterns are checked in reverse load order. Extension matching tries the original
case first, then lowercase, preserving the C/C++ distinction between `.c` and `.C`.
Unknown file types remain plain text and preserve their indentation.

## Data-only bundles

Most languages need no executable code. Copy an included bundle from
`Resources/Languages`, rename it, and edit `Resources/Language.plist`. The manifest
is an XML property list containing integer `APIVersion` **1** and a nonempty
`Languages` array. Each entry has:

| Key | Type | Meaning |
| --- | --- | --- |
| `Identifier` | String | Language identifier, such as `ruby`. |
| `Extensions` | Array of strings | Extensions without dots; may be empty for filename-only languages. |
| `FileNames` | Array of strings | Optional exact filenames. |
| `Patterns` | Dictionary | Regex patterns described below; may be empty. |
| `Indentation` | String | `braces`, `colon`, `blocks`, or `preserve`; omitted means preserve. |
| `CompletionKeywords` | Array of strings | Optional vocabulary for Edit > Complete Word; combined with words in the current file. |
| `ControlKeywords` | Array of strings | Brace-language control words followed by parenthesized conditions. |
| `StandaloneControls` | Array of strings | Brace-language headers such as `else`, `try`, or `do`. |
| `LineComment` | String | Optional marker for Edit > Comment/Uncomment Lines. |
| `HighlightStringKeys` | Boolean | Color strings followed by `:` or `=` as keys. |
| `LanguageServer` | Dictionary | Reserved configuration exposed to future integrations; no language-server process is started. |

`Patterns` uses `NSRegularExpression` syntax with anchors matching individual
lines. These keys are supported:

- `preprocessor`, `symbol`, `constant`, `type`, `number`, `keyword`: painted in
  this order, with later categories taking precedence.
- `annotation`: painted after keywords using the preprocessor color.
- `literal`: painted last; **capture group 1 must match comments**. The other
  alternative matches strings. All internal grouping should be noncapturing.
  This same pattern masks comments and strings during indentation and delimiter
  matching, preserving UTF-16 offsets and line endings.
- `fileName`: matches the basename before extension lookup. Anchor the regex
  to match the complete filename; use `(?i)` for case-insensitive matching.
- `indentAfter`: for `colon` and `blocks`, matches a comment/string-masked line
  that should increase indentation after Return.
- `indentBefore`: for `blocks`, matches closing or middle keywords. The editor
  aligns these with the most recent unmatched opening block. Middle clauses
  should match both `indentBefore` and `indentAfter`.

Indent increases use the configured control-statement space count, default two.
Line commenting preserves line endings and indentation and uses the normal
undo and document-modification path. Languages without `LineComment` disable
that command.

Malformed definitions, invalid regex patterns, and unsupported API versions are
rejected before any registrations from that bundle are applied. Patterns are
compiled once and reused. The public types are in [YCodeLanguage.h](YCodeLanguage.h).

## Optional Objective-C provider

An executable bundle may set `NSPrincipalClass` in its platform-native bundle
information dictionary. Its principal class implements `YCodeLanguageProvider`:

```objc
- (NSUInteger)languageAPIVersion;
- (NSArray *)languageDefinitions;
```

Return API version 1 and an array using the same definition schema. The bundle
still needs `Language.plist` with `APIVersion` 1; the provider supplies `Languages`.
Use Foundation and manual reference counting. Ycode retains accepted provider
instances. Build the executable bundle for the host platform and Objective-C
runtime, and include the manifest as a bundle resource. Executable providers run
inside Ycode and should come from trusted sources.

## Scope

These are lexical editing rules, not compiler parsers. Complex nested Ruby
percent literals, heredocs, regex literals, and interpolation are not fully
parsed. Ruby indentation is intended for conventional multiline blocks;
multiline Python headers and parser-based formatting need a future provider API.
Adding a language bundle does not add a compiler, debugger, completion engine,
or language-server client.

Run `make -C Applications/ycode/Tests all`, then run its `ycode_tests` executable
with `--check-languages` from the Tests directory in a GUI session (or virtual
X display), with the local XCode framework on the library search path. Existing
`--check-editing` and `--check-delimiters` checks cover the shared editor behavior.

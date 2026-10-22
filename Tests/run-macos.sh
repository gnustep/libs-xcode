#!/bin/sh
# Build against Apple Foundation and run the shared regression tests.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${CONFIGURATION:-Debug}
case "$configuration" in
  Debug|Release) ;;
  *) echo "CONFIGURATION must be Debug or Release" >&2; exit 1 ;;
esac
products_dir="$repo_dir/build/macos/$configuration"
cd "$repo_dir"

xcodebuild -project libs-xcode.xcodeproj \
  -target XCodeNative -target buildtool-native \
  -target pc2xc-native -target pcpg-native \
  -configuration "$configuration" \
  SYMROOT="$repo_dir/build/macos" CODE_SIGNING_ALLOWED=NO build

# Build and package the AppKit application against the same local framework.
xcodebuild -project Applications/ycode/Ycode.xcodeproj -target Ycode \
  -configuration "$configuration" \
  SYMROOT="$repo_dir/build/macos" CODE_SIGNING_ALLOWED=NO build

app_contents="$products_dir/Ycode.app/Contents"
test -x "$app_contents/MacOS/Ycode"
# Editor bundles dynamically link to host classes in the application executable.
nm -gU "$app_contents/MacOS/Ycode" > "$products_dir/ycode-exported-symbols.log"
for host_class in YCodeEditorDocument YCodeTextView YCodeSyntaxHighlighter YCEditorRulerView; do
  grep -Fq "_OBJC_CLASS_\$_$host_class" "$products_dir/ycode-exported-symbols.log"
done
test "$(plutil -extract CFBundleIconFile raw "$app_contents/Info.plist")" = Ycode.icns
test -s "$app_contents/Resources/Ycode.icns"
test "$(plutil -extract CFBundleDocumentTypes.0.NSDocumentClass raw -o - "$app_contents/Info.plist")" = YCodeProject
test "$(plutil -extract CFBundleDocumentTypes.0.LSItemContentTypes.0 raw -o - "$app_contents/Info.plist")" = com.apple.xcode.project
test -f "$app_contents/Frameworks/XCode.framework/XCode"
for editor in Text Image Sound Model; do
  test -x "$app_contents/Resources/Editors/$editor.bundle/Contents/MacOS/$editor"
done
test -x "$app_contents/Resources/Debuggers/GDB.bundle/Contents/MacOS/GDB"
test -x "$app_contents/Resources/YCodeTestHost.bundle/Contents/MacOS/YCodeTestHost"

xcrun --sdk macosx clang -fno-objc-arc -fobjc-exceptions \
  -I "$repo_dir/Tools/buildtool" -F "$products_dir" \
  -include "$products_dir/XCode.framework/Headers/GSXCCommon.h" \
  Tests/main.m Tools/buildtool/ArgPair.m Tools/buildtool/ToolDelegate.m \
  -framework Foundation -framework XCode \
  -Wl,-rpath,@executable_path -o "$products_dir/xcode_tests"

cd "$repo_dir/Tests"
"$products_dir/xcode_tests" -project Sample.xcodeproj \
  -workspace Sample.xcworkspace -target SampleTarget -scheme SampleScheme \
  -configuration Debug -alltargets build

# Exercise startup without building a project or requiring GNUstep tools.
startup_status=0
"$products_dir/buildtool" -project > "$products_dir/buildtool-startup.log" 2>&1 \
  || startup_status=$?
test "$startup_status" -eq 1
grep -q 'Parameter is mandatory' "$products_dir/buildtool-startup.log"

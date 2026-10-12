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
"$products_dir/buildtool" -project > "$products_dir/buildtool-startup.log" 2>&1
grep -q 'Parameter is mandatory' "$products_dir/buildtool-startup.log"

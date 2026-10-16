#!/bin/sh
# Build the Foundation-only backend as a native resource bundle for Xcode.
set -eu
source_root=${SRCROOT:?}
bundle_root=${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/Debuggers/GDB.bundle
mkdir -p "$bundle_root/Contents/MacOS" "$bundle_root/Contents/Resources"
set --
for architecture in ${ARCHS:-}; do
  set -- "$@" -arch "$architecture"
done
if [ -n "${SDKROOT:-}" ]; then
  set -- "$@" -isysroot "$SDKROOT"
fi
xcrun --sdk macosx clang -bundle -fno-objc-arc "$@" \
  -I"$source_root" -framework Foundation \
  "$source_root/DebuggerBundles/GDB/YCodeGDBDebugger.m" \
  "$source_root/DebuggerBundles/GDB/YCodeGDBVariables.m" \
  -o "$bundle_root/Contents/MacOS/GDB"
cp "$source_root/DebuggerBundles/GDB/Debugger.plist" "$bundle_root/Contents/Resources/"
cp "$source_root/DebuggerBundles/GDB/Info.plist" "$bundle_root/Contents/Info.plist"
if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$bundle_root"
fi

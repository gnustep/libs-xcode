#!/bin/sh
# Package native editor bundles and the local framework in the application.
set -eu
source_root=${SRCROOT:?}
resources=${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}
frameworks=${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH:?}
mkdir -p "$resources/Editors" "$frameworks"
ditto "${BUILT_PRODUCTS_DIR:?}/XCode.framework" "$frameworks/XCode.framework"
set --
for architecture in ${ARCHS:-}; do
  set -- "$@" -arch "$architecture"
done
if [ -n "${SDKROOT:-}" ]; then
  set -- "$@" -isysroot "$SDKROOT"
fi
# Finder and the Dock expect an ICNS file referenced by the app Info.plist.
iconset="${DERIVED_FILE_DIR:?}/Ycode.iconset"
mkdir -p "$iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_root/Resources/Ycode.tiff" \
    -s format png --out "$iconset/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z "$retina_size" "$retina_size" "$source_root/Resources/Ycode.tiff" \
    -s format png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$resources/Ycode.icns"
for editor in Text Image Sound Model YCodeTestHost; do
  bundle="$resources/Editors/$editor.bundle"
  principal="YCode${editor}EditorDocument"
  source_file="$source_root/EditorBundles/$editor/$principal.m"
  if [ "$editor" = YCodeTestHost ]; then
    bundle="$resources/$editor.bundle"
    principal=YCodeTestHost
    source_file="$source_root/TestHost/YCodeTestHost.m"
  fi
  mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
  xcrun --sdk macosx clang -bundle -fno-objc-arc -fobjc-exceptions "$@" \
    -mmacosx-version-min="${MACOSX_DEPLOYMENT_TARGET:-10.13}" \
    -I"$source_root" -F"$BUILT_PRODUCTS_DIR" \
    -include "$source_root/YCodePrefix.h" \
    -framework Cocoa -undefined dynamic_lookup \
    "$source_file" \
    -o "$bundle/Contents/MacOS/$editor"
  cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$editor</string>
<key>CFBundleIdentifier</key><string>org.gnustep.Ycode.$editor</string>
<key>CFBundlePackageType</key><string>BNDL</string>
<key>NSPrincipalClass</key><string>$principal</string>
</dict></plist>
PLIST
  if [ -d "$source_root/EditorBundles/$editor/Resources" ]; then
    ditto "$source_root/EditorBundles/$editor/Resources" "$bundle/Contents/Resources"
  fi
  if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$bundle"
  fi
done
if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" "$frameworks/XCode.framework"
fi

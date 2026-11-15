#!/bin/sh
# Compile and link without running AppKit or requiring a display.
task_dir=$(mktemp -d) || exit 1
trap 'rm -rf "$task_dir"' EXIT HUP INT TERM
cat > "$task_dir/probe.m" <<'SOURCE'
#import <GormCore/GormDocumentIO.h>
#import <GormCore/GormAbstractDelegate.h>
int main(void)
{
  return [GormDocumentIO class] == Nil || [GormAbstractDelegate class] == Nil;
}
SOURCE
if ${CC:-cc} $(gnustep-config --objc-flags) "$task_dir/probe.m" \
    -o "$task_dir/probe" -lGormCore -lInterfaceBuilder \
    -lGormObjCHeaderParser $(gnustep-config --gui-libs) >/dev/null 2>&1; then
  echo yes
fi

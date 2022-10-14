#!/bin/bash

#
# This script is meant to build the dummy framework class needed to get the class list from the framework bundle.
#

FILES=$1
NAME=$2

classes="";
for object_file in ${FILES} __dummy__; do
  if [ "$object_file" != "__dummy__" ]; then
    sym=`nm -Pg $object_file | sed -n -e '/^._OBJC_CLASS_[A-Za-z0-9_.]* [^U]/ {s/^._OBJC_CLASS_\([A-Za-z0-9_.]*\) [^U].*/\1/p;}' -e '/^__objc_class_name_[A-Za-z0-9_.]* [^U]/ {s/^__objc_class_name_\([A-Za-z0-9_.]*\) [^U].*/\1/p;}'`;
    classes="$classes $sym";
  fi;
done;
classlist="";
classarray="";
for f in $classes __dummy__ ; do
  if [ "$f" != "__dummy__" ]; then
    if [ "$classlist" = "" ]; then
      classlist="@\"$f\"";
      classarray="(\"$f\"";
    else
      classlist="$classlist, @\"$f\"";
      classarray="$classarray, \"$f\"";
    fi;
  fi;
done;
if [ "$classlist" = "" ]; then
  classlist="NULL";
  classarray="()";
else
  classlist="$classlist, NULL";
  classarray="$classarray)";
fi;

rm -rf ./derived_src
mkdir ./derived_src

echo "$classarray" > ./derived_src/${NAME}-class-list;
echo "#include <Foundation/NSObject.h>" > derived_src/NSFramework_${NAME}.m;
echo "#include <Foundation/NSString.h>" >> derived_src/NSFramework_${NAME}.m;
echo "@interface NSFramework_${NAME} : NSObject" >> derived_src/NSFramework_${NAME}.m;
echo "+ (NSString *)frameworkVersion;" >> derived_src/NSFramework_${NAME}.m;
echo "+ (NSString *const*)frameworkClasses;" >> derived_src/NSFramework_${NAME}.m;
echo "@end" >> derived_src/NSFramework_${NAME}.m;
echo "@implementation NSFramework_${NAME}" >> derived_src/NSFramework_${NAME}.m;
echo "+ (NSString *)frameworkVersion { return @\"0\"; }" >> derived_src/NSFramework_${NAME}.m;
echo "static NSString *allClasses[] = {$classlist};" >> derived_src/NSFramework_${NAME}.m;
echo "+ (NSString *const*)frameworkClasses { return allClasses; }" >> derived_src/NSFramework_${NAME}.m;
echo "@end" >> derived_src/NSFramework_${NAME}.m

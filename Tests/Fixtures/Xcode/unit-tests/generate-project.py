#!/usr/bin/env python3
# Writes Calc.xcodeproj/project.pbxproj for the buildtool test regressions:
#   CalcTool     - a command-line tool (Sources/)
#   CalcTests    - unit tests for Calc (Tests/)
#   CalcApp      - a GNUstep application (App/)
#   AppTests     - unit tests hosted in CalcApp (TEST_HOST)
ids = iter(range(1, 500))
def nid(): return "%024X" % next(ids)
objs = {}
def add(d):
    i = nid(); objs[i] = d; return i
def conflist(settings):
    confs = [add({"buildSettings": settings, "isa": "XCBuildConfiguration", "name": n}) for n in ("Debug", "Release")]
    return add({"buildConfigurations": confs, "defaultConfigurationName": "Debug", "isa": "XCConfigurationList"})
def fref(path, ftype):
    return add({"isa": "PBXFileReference", "lastKnownFileType": ftype, "path": path, "sourceTree": "<group>"})
def product(path, ftype):
    return add({"includeInIndex": "0", "isa": "PBXFileReference", "explicitFileType": ftype, "path": path, "sourceTree": "BUILT_PRODUCTS_DIR"})
def bf(ref): return add({"fileRef": ref, "isa": "PBXBuildFile"})
def phase(isa, refs=()): return add({"files": [bf(r) for r in refs], "isa": isa})
def target(name, ptype, prod, settings, sources, extra_phases=()):
    phases = [phase("PBXSourcesBuildPhase", sources), phase("PBXFrameworksBuildPhase")] + list(extra_phases)
    return add({"buildConfigurationList": conflist(dict(settings, PRODUCT_NAME=name, SDKROOT="macosx")),
                "buildPhases": phases, "isa": "PBXNativeTarget", "name": name, "productName": name,
                "productReference": prod, "productType": ptype})

calc_h = fref("Sources/Calc.h", "sourcecode.c.h")
calc_m = fref("Sources/Calc.m", "sourcecode.c.objc")
main_m = fref("Sources/main.m", "sourcecode.c.objc")
tests_m = fref("Tests/CalcTests.m", "sourcecode.c.objc")
app_h = fref("App/AppDelegate.h", "sourcecode.c.h")
app_m = fref("App/AppDelegate.m", "sourcecode.c.objc")
app_main = fref("App/main.m", "sourcecode.c.objc")
apptests_m = fref("AppTests/AppTests.m", "sourcecode.c.objc")

tool_prod = product("CalcTool", "compiled.mach-o.executable")
tests_prod = product("CalcTests.xctest", "wrapper.cfbundle")
app_prod = product("CalcApp.app", "wrapper.application")
apptests_prod = product("AppTests.xctest", "wrapper.cfbundle")

tool = target("CalcTool", "com.apple.product-type.tool", tool_prod, {}, [calc_m, main_m])
tests = target("CalcTests", "com.apple.product-type.bundle.unit-test", tests_prod,
               {"HEADER_SEARCH_PATHS": "Sources"}, [calc_m, tests_m], [phase("PBXResourcesBuildPhase")])
app = target("CalcApp", "com.apple.product-type.application", app_prod, {}, [app_m, app_main],
             [phase("PBXResourcesBuildPhase")])
apptests = target("AppTests", "com.apple.product-type.bundle.unit-test", apptests_prod,
                  {"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/CalcApp.app/Contents/MacOS/CalcApp",
                   "BUNDLE_LOADER": "$(TEST_HOST)"},
                  [apptests_m], [phase("PBXResourcesBuildPhase")])

products = add({"children": [tool_prod, tests_prod, app_prod, apptests_prod], "isa": "PBXGroup", "name": "Products", "sourceTree": "<group>"})
main_group = add({"children": [calc_h, calc_m, main_m, tests_m, app_h, app_m, app_main, apptests_m, products],
                  "isa": "PBXGroup", "sourceTree": "<group>"})
project = add({"buildConfigurationList": conflist({"SDKROOT": "macosx"}), "compatibilityVersion": "Xcode 15.0",
               "developmentRegion": "en", "hasScannedForEncodings": "0", "isa": "PBXProject", "mainGroup": main_group,
               "productRefGroup": products, "projectDirPath": "", "projectRoot": "",
               "targets": [tool, tests, app, apptests]})

def fmt(v, ind):
    pad = "\t" * ind
    if isinstance(v, dict):
        return "{\n" + "".join('%s\t"%s" = %s;\n' % (pad, k, fmt(v[k], ind + 1)) for k in sorted(v)) + pad + "}"
    if isinstance(v, list):
        if not v:
            return "(\n%s)" % pad
        return "(\n" + ",\n".join('%s\t%s' % (pad, fmt(x, ind + 1)) for x in v) + "\n" + pad + ")"
    return '"%s"' % v

root = {"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objs, "rootObject": project}
open("Calc.xcodeproj/project.pbxproj", "w").write("// !$*UTF8*$!\n" + fmt(root, 0) + "\n")

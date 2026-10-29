#!/usr/bin/env bash
#
# Regressions for `buildtool test`, on Tests/Fixtures/Xcode/unit-tests
# (Calc.xcodeproj: a tool, its unit tests, an application, and unit tests
# hosted in the application). Needs tools-xctest's xctest (in PATH, or
# XCTEST=...); the hosted tests also need xvfb-run or an X display.
#
# usage: Tests/run-buildtool-test-action.sh [buildtool]

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
buildtool=${1:-$root/Tools/buildtool/obj/buildtool}
fixture=$root/Tests/Fixtures/Xcode/unit-tests
export LD_LIBRARY_PATH="$root/XCode/XCode.framework/Versions/Current${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ -z "${XCTEST:-}" ] && ! command -v xctest >/dev/null 2>&1 && [ ! -x /usr/GNUstep/System/Tools/xctest ]; then
  echo "Skipping buildtool test regressions: xctest (tools-xctest) not found."
  exit 0
fi

# The xctest buildtool will use, and the options it lists: -skip-testing
# and -host come with newer tools-xctest, and without them buildtool fails
# those cases with a message instead.
xctest=${XCTEST:-$(command -v xctest || echo /usr/GNUstep/System/Tools/xctest)}
xctest_usage=$("$xctest" --help 2>&1 || true)
can_skip=no; [[ "$xctest_usage" == *-skip-testing* ]] && can_skip=yes
can_host=no; [[ "$xctest_usage" == *-host* ]] && can_host=yes

if command -v xvfb-run >/dev/null 2>&1; then
  display=(xvfb-run -a)
elif [ -n "${DISPLAY:-}" ]; then
  display=()
else
  display=(none)
fi

fail() {
  echo "$1" >&2
  echo "$output" >&2
  exit 1
}

# run_buildtool [args...] sets $output and $status (in the fixture).
run_buildtool() {
  set +e
  output=$(cd "$fixture" && "$@" 2>&1)
  status=$?
  set -e
}

assert_contains() { [[ "$output" == *"$1"* ]] || fail "expected output to contain: $1"; }
assert_not_contains() { [[ "$output" != *"$1"* ]] || fail "expected output to omit: $1"; }
# Whether xctest ran a test method; its log names it in any output format.
assert_ran() { grep -Eq "(^|[^A-Za-z0-9_])$1([^A-Za-z0-9_]|\$)" <<<"$output" || fail "expected $1 to run"; }
assert_not_ran() { ! grep -Eq "(^|[^A-Za-z0-9_])$1([^A-Za-z0-9_]|\$)" <<<"$output" || fail "expected $1 not to run"; }
assert_status() { [ "$status" -eq "$1" ] || fail "expected exit status $1, got $status"; }

rm -rf "$fixture/build"

echo "Running buildtool test regressions..."

# Builds, then runs the unit-test bundle with xctest.
run_buildtool "$buildtool" test -target CalcTests
assert_status 0
assert_contains "Testing Target"
assert_ran testAdds
assert_ran testAddsNegatives
assert_ran testKnownBroken
[ -f "$fixture/build/CalcTests/Products/CalcTests.xctest/CalcTests" ] || fail "expected the test bundle"
grep -Eq 'NSExecutable = "?CalcTests"?;' "$fixture/build/CalcTests/Products/CalcTests.xctest/Resources/Info-gnustep.plist" \
  || fail "expected the bundle's Info-gnustep.plist to name its executable"

# A failing test fails the action and buildtool's exit status.
CALC_TESTS_FAIL=1 run_buildtool "$buildtool" test -target CalcTests
assert_status 1
assert_contains "deliberately wrong"
assert_contains "Test Failed"

# xcodebuild-style test selection.
run_buildtool "$buildtool" test -target CalcTests -only-testing:CalcTests/CalcTests/testAdds
assert_status 0
assert_ran testAdds
assert_not_ran testAddsNegatives
assert_not_ran testKnownBroken
run_buildtool "$buildtool" test -target CalcTests -only-testing:CalcTests/CalcTests
assert_status 0
assert_ran testAddsNegatives
run_buildtool "$buildtool" test -target CalcTests -skip-testing:CalcTests/CalcTests/testAdds
if [ "$can_skip" = yes ]; then
  assert_status 0
  assert_not_ran testAdds
  assert_ran testAddsNegatives
else
  assert_status 1
  assert_contains "needs an xctest with -skip-testing"
fi

# A scheme's testables and skipped tests (AppTests is not a testable there,
# and testAddsNegatives is skipped).
run_buildtool "$buildtool" test -scheme CalcTests
if [ "$can_skip" = yes ]; then
  assert_status 0
  assert_ran testAdds
  assert_not_ran testAddsNegatives
else
  assert_status 1
  assert_contains "needs an xctest with -skip-testing"
fi
assert_not_ran testRunsInsideTheApp

# Mistakes are failures.
run_buildtool "$buildtool" test -target CalcTool
assert_status 1
assert_contains "CalcTool is not a unit-test target"
run_buildtool "$buildtool" test -scheme Missing
assert_status 1
assert_contains "Could not read scheme Missing"

# TEST_HOST: the tests run inside the application it names.
if [ "${display[0]:-}" != none ]; then
  run_buildtool "${display[@]}" "$buildtool" test -only-testing:AppTests
  if [ "$can_host" = yes ]; then
    assert_status 0
    assert_contains "CalcApp["
    assert_ran testRunsInsideTheApp
  else
    assert_status 1
    assert_contains "needs an xctest with -host"
  fi
  assert_not_ran testAdds
else
  echo "Skipping the hosted test: no X display and no xvfb-run."
fi

rm -rf "$fixture/build"
echo "buildtool test regressions passed."

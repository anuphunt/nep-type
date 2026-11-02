#!/bin/bash
# Non-destructive tests; accepts an existing development bundle. No signing or install.
set -euo pipefail
if [ "$#" -ne 1 ]; then printf 'Usage: %s SIGNED-DEV.app\n' "$0" >&2; exit 2; fi
source_app=$1
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/lekha-stage-test.XXXXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
cp -a "$source_app" "$test_dir/Source.app"
xattr -w com.example.lekha-test marker "$test_dir/Source.app"
"$root/stage-preview.sh" "$test_dir/Source.app" "$test_dir/Output.app"
test "$(xattr -p com.example.lekha-test "$test_dir/Output.app")" = marker
printf 'PASS: unrelated custom attribute preserved in this test\n'
if "$root/stage-preview.sh" "$test_dir/Source.app" "$test_dir/Output.app"; then
    printf 'FAIL: existing destination accepted\n' >&2; exit 1
fi
printf 'PASS: existing destination refused\n'
if "$root/stage-preview.sh" "$test_dir/Source.app" "$test_dir/Source.app/Contents/Nested.app"; then
    printf 'FAIL: destination inside source accepted\n' >&2; exit 1
fi
printf 'PASS: source-child destination refused\n'
ln -s "$test_dir/Source.app" "$test_dir/Link.app"
if "$root/stage-preview.sh" "$test_dir/Link.app" "$test_dir/LinkOutput.app"; then
    printf 'FAIL: symlink source accepted\n' >&2; exit 1
fi
printf 'PASS: symlink source refused\n'
ln -s /tmp "$test_dir/Source.app/Contents/UnexpectedLink"
if "$root/stage-preview.sh" "$test_dir/Source.app" "$test_dir/NestedLinkOutput.app"; then
    printf 'FAIL: nested symlink accepted\n' >&2; exit 1
fi
printf 'PASS: nested symlink refused\n'
rm "$test_dir/Source.app/Contents/UnexpectedLink"
cp -a "$test_dir/Source.app" "$test_dir/NestedQuarantine.app"
xattr -w com.apple.quarantine '0081;60000000;Example;' "$test_dir/NestedQuarantine.app/Contents/Info.plist"
if "$root/stage-preview.sh" "$test_dir/NestedQuarantine.app" "$test_dir/NestedQuarantineOutput.app"; then
    printf 'FAIL: nested quarantine accepted\n' >&2; exit 1
fi
printf 'PASS: nested quarantine refused\n'
xattr -w com.apple.quarantine '0081;60000000;Example;' "$test_dir/Source.app"
if "$root/stage-preview.sh" "$test_dir/Source.app" "$test_dir/QuarantineOutput.app"; then
    printf 'FAIL: quarantined source accepted\n' >&2; exit 1
fi
printf 'PASS: quarantined source refused\n'
test "$(xattr -p com.apple.quarantine "$test_dir/Source.app")" = '0081;60000000;Example;'
test "$(xattr -p com.example.lekha-test "$test_dir/Source.app")" = marker
printf 'PASS: test source attributes retained\n'

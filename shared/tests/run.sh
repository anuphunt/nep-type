#!/bin/bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
work="${NEPTYPE_SHARED_TEST_WORK:-/tmp/neptype-shared-tests}"
mkdir -p "$work/classes"
bash "$root/scripts/build-shared-engine.sh"
bin="$root/build/shared-engine"
case "$(uname -s)" in
 Darwin) library="$bin/libNepTypeEngine.dylib"; extension=dylib; dynamic=-dynamiclib; dl=;;
 Linux) library="$bin/libNepTypeEngine.so"; extension=so; dynamic=-shared; dl=-ldl;;
 *) echo "Run host bridge parity on macOS/Linux; Windows uses the C++ smoke target." >&2; exit 1;;
esac
python3 "$root/scripts/engine-data.py" stage "$work/dictionaries"
sed '/^import NepaliCore$/d' "$root/shared/tests/reference.swift" > "$work/main.swift"
swiftc -I "$root/shared/include" "$root"/Sources/NepaliCore/*.swift "$work/main.swift" "$root/engine/target/release/libneptype_engine.a" -o "$work/reference"
clang++ -std=c++17 -Wall -Wextra -Werror -pthread "$root/shared/tests/probe.cpp" $dl -o "$work/cpp-probe"
if [ -z "${JDK_BIN:-}" ] && [ -x /opt/homebrew/opt/openjdk/bin/javac ]; then JDK_BIN=/opt/homebrew/opt/openjdk/bin; fi
if [ -z "${JDK_BIN:-}" ]; then echo "Set JDK_BIN for the required JNI parity checks." >&2; exit 1; fi
java_root=$(CDPATH= cd -- "$JDK_BIN/.." && pwd)
clang++ -std=c++17 -Wall -Wextra -Werror -fPIC $dynamic "$root/shared/cpp/neptype_jni.cpp" \
    -I "$java_root/include" -I "$java_root/include/darwin" -I "$java_root/include/linux" \
    -L "$bin" -lNepTypeEngine -Wl,-rpath,"$bin" -o "$work/libneptype_jni.$extension"
"$JDK_BIN/javac" --release 8 -d "$work/classes" "$root/platforms/android/app/src/main/java/app/neptype/keyboard/core/SharedEngine.java" "$root/platforms/android/tests/SharedEngineProbe.java"
python3 "$root/shared/tests/parity.py" "$library" "$work/dictionaries" "$work/reference" "$work/cpp-probe" \
    --java "$JDK_BIN/java" --jni-dir "$work" --classes "$work/classes"
python3 "$root/scripts/check-shared-engine.py"

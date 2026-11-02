#!/bin/sh
set -eu
experiment=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root=${LEKHA_ROOT:-$(CDPATH= cd -- "$experiment/../../../.." && pwd)}
jdk=${JDK_BIN:-/opt/homebrew/opt/openjdk/bin}
test -x "$jdk/javac" && test -x "$jdk/java"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/lekha-android-phonetic.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
cp "$experiment/phonetic-reference.swift" "$scratch/main.swift"
swiftc -O -module-cache-path "$scratch/cache" \
    "$root/Sources/NepaliCore/Transliterator.swift" "$root/Sources/NepaliCore/Composer.swift" \
    "$root/Sources/NepaliCore/GeneratedIndexes.swift" "$root/Sources/NepaliCore/GeneratedAliasIndex.swift" \
    "$scratch/main.swift" -o "$scratch/swift-reference"
"$jdk/javac" --release 8 -d "$scratch/classes" "$experiment/PhoneticCandidates.java" \
    "$root/platforms/android/app/src/main/java/app/lekha/keyboard/core/CandidateMerger.java" "$experiment/PhoneticProbe.java"
python3 - "$scratch" <<'PY'
import random, sys
from pathlib import Path
scratch = Path(sys.argv[1]); rng = random.Random(729451); alphabet = 'abcdefghijklmnopqrstuvwxyz'
words = ['ma', 'namaste', 'bhaisakeko', 'kshama', 'chhito', 'gharma', 'swastha', 'aau', 'khusi', 'football']
words += [''.join(rng.choice(alphabet) for _ in range(rng.randint(1, 35))) for _ in range(5000)]
(scratch / 'words').write_text(''.join(w + '\n' for w in words), encoding='utf-8')
PY
"$scratch/swift-reference" < "$scratch/words" > "$scratch/swift-output"
"$jdk/java" -cp "$scratch/classes" PhoneticProbe < "$scratch/words" > "$scratch/java-output"
cmp "$scratch/swift-output" "$scratch/java-output"
printf 'PASS: Swift and rejected Java phonetic mapping match for 5,010 deterministic lowercase inputs.\n'

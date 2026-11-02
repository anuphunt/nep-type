#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output="${TMPDIR:-/tmp}/neptype-windows-composition-test"
clang++ -std=c++17 -Wall -Wextra -Werror -I"$root/include" "$root/composition.cpp" "$root/tests/composition_test.cpp" -o "$output"
"$output"
clang++ -std=c++17 -Wall -Wextra -Werror -I"$root/include" "$root/composition.cpp" "$root/candidate_adapter.cpp" "$root/tests/candidate_adapter_test.cpp" -o "${TMPDIR:-/tmp}/neptype-windows-candidate-test"
"${TMPDIR:-/tmp}/neptype-windows-candidate-test"
clang++ -std=c++17 -Wall -Wextra -Werror -DNEPTYPE_TSF_TEST -I"$root/tests/fake_windows" -I"$root/include" -I"$root/tsf" "$root/composition.cpp" "$root/candidate_adapter.cpp" "$root/tsf/edit_bridge.cpp" "$root/tsf/service.cpp" "$root/tests/tsf_lifecycle_test.cpp" -o "${TMPDIR:-/tmp}/neptype-windows-tsf-test"
"${TMPDIR:-/tmp}/neptype-windows-tsf-test"
clang++ -std=c++17 -Wall -Wextra -Werror -DNEPTYPE_TSF_TEST -I"$root/tests/fake_windows" -I"$root/include" -I"$root/tsf" "$root/composition.cpp" "$root/candidate_adapter.cpp" "$root/tsf/edit_bridge.cpp" "$root/tests/tsf_edit_test.cpp" -o "${TMPDIR:-/tmp}/neptype-windows-tsf-edit-test"
"${TMPDIR:-/tmp}/neptype-windows-tsf-edit-test"
clang++ -std=c++17 -Wall -Wextra -Werror -DNEPTYPE_TSF_TEST -I"$root/tests/fake_windows" -I"$root/include" -I"$root/tsf" "$root/tsf/owned_range.cpp" "$root/tests/owned_range_test.cpp" -o "${TMPDIR:-/tmp}/neptype-windows-owned-range-test"
"${TMPDIR:-/tmp}/neptype-windows-owned-range-test"
if [ -n "${NEPTYPE_TEST_CORE:-}" ]; then
  python3 "$root/tests/real_engine_probe.py" "$NEPTYPE_TEST_CORE" "${TMPDIR:-/tmp}/neptype-windows-candidate-test"
fi

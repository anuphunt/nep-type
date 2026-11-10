"""Bind the setup helper to the exact keyboard/engine binaries it can install."""
import hashlib
import pathlib
import sys

tsf, engine, destination = map(pathlib.Path, sys.argv[1:])
values = [hashlib.sha256(path.read_bytes()).hexdigest() for path in (tsf, engine)]
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(
    '#pragma once\nnamespace neptype::setup {\n'
    f'inline constexpr wchar_t expected_tsf[] = L"{values[0]}";\n'
    f'inline constexpr wchar_t expected_engine[] = L"{values[1]}";\n'
    '}\n', encoding='utf-8')

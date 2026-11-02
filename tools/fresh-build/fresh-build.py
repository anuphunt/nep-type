#!/usr/bin/env python3
"""Build isolated local Lekha development bundles into a new directory only.

This is not a release, notarization, input-source installation or publishing tool.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile


def run(args, **kwargs):
    print('+', ' '.join(str(x) for x in args), flush=True)
    subprocess.run([str(x) for x in args], check=True, **kwargs)


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def checked_input(root, relative):
    p = root / relative
    # Never silently traverse links, including links in ancestor components.
    current = root
    for part in ('', *relative.parts):
        if part:
            current = current / part
        if current.is_symlink():
            raise ValueError(f'symlink input refused: {relative}')
        result = subprocess.run(['xattr', str(current)], capture_output=True, text=True)
        if result.returncode != 0:
            raise ValueError(f'could not inspect input attributes: {relative}')
        if 'com.apple.quarantine' in result.stdout.splitlines():
            raise ValueError(f'quarantined input refused: {relative}')
    if not p.is_file():
        raise ValueError(f'missing regular input: {relative}')
    return p


def collect(root):
    required = [Path('Package.swift'), Path('data/compiled/google-ne-aliases.tsv'), Path('data/compiled/aksharantar-indiccorp-v1.tsv'), Path('data/compiled/aksharantar-indiccorp-v1.manifest.json'), Path('data/sources/CMUDICT-LICENSE.txt'), Path('data/sources/GOOGLE-NE-ATTRIBUTION.txt'), Path('data/sources/AKSHARANTAR-ATTRIBUTION.txt')]
    for base in ('Sources', 'Tests'):
        directory = root / base
        if not directory.is_dir() or directory.is_symlink():
            raise ValueError(f'missing/linked input directory: {base}')
        for p in directory.rglob('*'):
            if p.is_symlink():
                raise ValueError(f'symlink input refused: {p.relative_to(root)}')
            if p.is_file():
                required.append(p.relative_to(root))
    return sorted(set(required), key=lambda p: str(p))


def plist(executable, identifier, name, display, version, is_ime):
    import plistlib
    d = {'CFBundleExecutable': executable, 'CFBundleIdentifier': identifier,
         'CFBundleName': name, 'CFBundleDisplayName': display, 'CFBundlePackageType': 'APPL',
         'CFBundleVersion': '1', 'CFBundleShortVersionString': version,
         'LSMinimumSystemVersion': '13.0', 'NSPrincipalClass': 'NSApplication'}
    if is_ime:
        d.update({'LSUIElement': True, 'InputMethodConnectionName': 'LekhaInput_Connection',
                  'InputMethodServerControllerClass': 'LekhaInputController',
                  'TISIntendedLanguage': 'ne', 'tsInputMethodCharacterRepertoireKey': ['Devanagari']})
    else:
        d['NSHighResolutionCapable'] = True
    return plistlib.dumps(d, fmt=plistlib.FMT_XML, sort_keys=True)


def assemble(stage, snapshot, binary, name, executable, identifier, display, version, is_ime):
    app = stage / name
    macos = app / 'Contents/MacOS'; resources = app / 'Contents/Resources'; licenses = resources / 'Licenses'
    macos.mkdir(parents=True); licenses.mkdir(parents=True)
    shutil.copy2(binary, macos / executable)
    # The copied data is never rewritten or filtered, preserving existing attribution.
    for filename in ('google-ne-aliases.tsv', 'aksharantar-indiccorp-v1.tsv'):
        shutil.copyfile(snapshot / 'data/compiled' / filename, resources / filename)
    for filename in ('CMUDICT-LICENSE.txt', 'GOOGLE-NE-ATTRIBUTION.txt', 'AKSHARANTAR-ATTRIBUTION.txt'):
        shutil.copyfile(snapshot / 'data/sources' / filename, licenses / filename)
    shutil.copyfile(snapshot / 'data/compiled/aksharantar-indiccorp-v1.manifest.json', licenses / 'AKSHARANTAR-PROVENANCE.json')
    (app / 'Contents/Info.plist').write_bytes(plist(executable, identifier, 'Lekha Input' if is_ime else 'Lekha', display, version, is_ime))
    # Exactly the existing ad-hoc development signing policy; not Developer ID signing.
    run(['codesign', '--force', '--sign', '-', app])
    run(['codesign', '--verify', '--deep', '--strict', app])
    run(['plutil', '-lint', app / 'Contents/Info.plist'])
    return app


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, help='existing project root')
    parser.add_argument('--output', required=True, help='new, non-existing output directory')
    parser.add_argument('--disable-swiftpm-sandbox', action='store_true', help='only for environments where the nested SwiftPM sandbox is unavailable; this flag does not itself grant OS access')
    args = parser.parse_args()
    project_argument = Path(args.project).expanduser()
    if project_argument.is_symlink():
        raise ValueError('project root must not be a symlink')
    project = project_argument.resolve(strict=True)
    target = Path(args.output).expanduser().absolute()
    if target.exists() or target.is_symlink():
        raise ValueError('output already exists; refusing to overwrite')
    parent = target.parent.resolve(strict=True)
    if not parent.is_dir() or target.parent.is_symlink():
        raise ValueError('output parent must be an existing non-symlink directory')
    target = parent / target.name
    # Do not place build output anywhere inside an input source tree.
    if project == parent or project in parent.parents:
        raise ValueError('output must be outside the source project')
    files = collect(project)
    print(f'Snapshotting {len(files)} inputs; no project files will be changed.', flush=True)
    with tempfile.TemporaryDirectory(prefix='lekha-fresh-build-') as temp:
        scratch = Path(temp); snap = scratch / 'project'; stage = scratch / 'artifacts'
        snap.mkdir(); stage.mkdir()
        manifest = {}
        for relative in files:
            original = checked_input(project, relative)
            before = digest(original)
            copy = snap / relative
            copy.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(original, copy)
            after = digest(original)
            copied = digest(copy)
            if before != after or before != copied:
                raise ValueError(f'input changed while snapshotting: {relative}')
            manifest[str(relative)] = copied
        env = os.environ.copy()
        env['CLANG_MODULE_CACHE_PATH'] = str(scratch / 'clang-cache')
        env['SWIFTPM_MODULECACHE_OVERRIDE'] = str(scratch / 'clang-cache')
        common = ['--package-path', snap, '--cache-path', scratch / 'cache', '--config-path', scratch / 'config', '--security-path', scratch / 'security']
        if args.disable_swiftpm_sandbox:
            common.append('--disable-sandbox')
        # Reject external dependencies and package resources rather than implicitly resolving/downloads.
        dump = subprocess.run(['swift', 'package', *map(str, common), 'dump-package'], env=env, check=True, capture_output=True, text=True)
        package = json.loads(dump.stdout)
        if package.get('dependencies') or any(t.get('resources') for t in package.get('targets', [])):
            raise ValueError('external dependencies or target resources need explicit build review')
        run(['swift', 'build', *common, '--disable-automatic-resolution', '--scratch-path', scratch / 'swift', '-c', 'release'], env=env)
        run(['swift', 'test', *common, '--disable-automatic-resolution', '--scratch-path', scratch / 'swift'], env=env)
        binaries = scratch / 'swift/release'
        assemble(stage, snap, binaries / 'Lekha', 'Lekha.app', 'Lekha', 'local.anup.lekha.prototype', 'Lekha', '0.1.0', False)
        assemble(stage, snap, binaries / 'LekhaInput', 'Lekha Input.app', 'LekhaInput', 'local.anup.inputmethod.Lekha', 'Lekha Nepali', '0.1', True)
        swift_version = subprocess.run(['swift', '--version'], check=True, capture_output=True, text=True).stdout.strip()
        metadata = {'format': 1, 'inputs_sha256': manifest, 'swift_version': swift_version,
                    'machine': platform.machine(), 'macos_version': platform.mac_ver()[0],
                    'configuration': 'release', 'swiftpm_sandbox_disabled': args.disable_swiftpm_sandbox,
                    'external_package_dependencies': 0,
                    'note': 'local development snapshot; ad-hoc signing; dataset rights unresolved; not a distribution release'}
        (stage / 'build-inputs.json').write_text(json.dumps(metadata, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        # Exclusive creation ensures old artifacts are never overwritten or merged.
        try:
            os.mkdir(target, 0o700)
        except FileExistsError:
            raise ValueError('output appeared during build; refusing to overwrite')
        print(f'Created {target}; if final copy/verification fails, inspect this incomplete directory.', flush=True)
        for child in stage.iterdir():
            destination = target / child.name
            if child.is_dir():
                shutil.copytree(child, destination, copy_function=shutil.copy2)
            else:
                shutil.copy2(child, destination)
        for app in (target / 'Lekha.app', target / 'Lekha Input.app'):
            # Do not remove quarantine or other attributes. Fail visibly if the output
            # filesystem attaches FinderInfo or otherwise invalidates strict signing.
            run(['codesign', '--verify', '--deep', '--strict', app])
        print('Done. Local ad-hoc development output only; no input source installed.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f'Build stopped: {exc}', file=sys.stderr)
        sys.exit(1)

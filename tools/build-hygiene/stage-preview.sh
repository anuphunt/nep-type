#!/bin/bash
# Stage a previously built, locally signed development bundle. Does not sign,
# install, publish or alter the source. Strict verification is a diagnostic,
# not a Developer ID/notarization check or distribution authorization.
set -euo pipefail
if [ "$#" -ne 2 ]; then
    printf 'Usage: %s SOURCE.app NEW-DESTINATION.app\n' "$0" >&2
    exit 2
fi
source_app=$1
destination=$2
case "$source_app" in *.app) ;; *) printf 'Source must be an .app bundle.\n' >&2; exit 2 ;; esac
case "$destination" in *.app) ;; *) printf 'Destination must end in .app.\n' >&2; exit 2 ;; esac
if [ ! -d "$source_app" ] || [ -L "$source_app" ]; then
    printf 'Source must be a real directory, not a symlink.\n' >&2; exit 2
fi
if [ -e "$destination" ] || [ -L "$destination" ]; then
    printf 'Destination already exists; refusing to overwrite.\n' >&2; exit 2
fi
if [ ! -d "$(dirname "$destination")" ] || [ -L "$(dirname "$destination")" ]; then
    printf 'Destination parent must be an existing real directory.\n' >&2; exit 2
fi
source_absolute=$(CDPATH= cd -- "$source_app" && pwd -P)
parent_absolute=$(CDPATH= cd -- "$(dirname "$destination")" && pwd -P)
case "$parent_absolute/" in
    "$source_absolute/"*) printf 'Destination cannot be inside the source bundle.\n' >&2; exit 2 ;;
esac
# This narrow development workflow does not follow or recreate links from an
# arbitrary source. Existing bundles requiring framework symlinks are unsupported.
if ! source_links=$(find "$source_app" -type l -print -quit); then
    printf 'Could not inspect source links; refusing to stage.\n' >&2; exit 2
fi
if [ -n "$source_links" ]; then
    printf 'Source contains symlinks; this staging tool does not support them.\n' >&2; exit 2
fi
# Copying a quarantined source can cause the OS to rewrite quarantine metadata.
# Refuse it instead of silently removing, changing or bypassing that state.
if ! source_attributes=$(xattr -r "$source_app" 2>/dev/null); then
    printf 'Could not inspect source attributes; refusing to stage.\n' >&2; exit 2
fi
if printf '%s\n' "$source_attributes" | grep -qE '(^|: )com\.apple\.quarantine$'; then
    printf 'Source carries quarantine metadata; refusing to stage it.\n' >&2; exit 2
fi
codesign --verify --deep "$source_app"
# mkdir gives an exclusive, empty target; copying cannot merge with an old bundle.
mkdir -m 700 "$destination"
printf 'Created %s; if verification fails, inspect and remove this incomplete copy.\n' "$destination"
# Preserve metadata including root extended attributes; never strip quarantine or unrelated attributes.
cp -a "$source_app/." "$destination/"
# FinderInfo on the generated top-level copy is disallowed by strict codesign.
# Remove this attribute only from this newly created copy, not its source.
if xattr -p com.apple.FinderInfo "$destination" >/dev/null 2>&1; then
    xattr -d com.apple.FinderInfo "$destination"
fi
codesign --verify --deep --strict --verbose=2 "$destination"
printf 'Local staging verified immediately. Signature identity, notarization, data rights and future filesystem metadata remain separate checks.\n'

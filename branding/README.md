# NepType

Write the name **NepType**, with a capital N and T. Use `neptype` in package names and file-system identifiers, and `NEPTYPE` in environment variables and build flags.

NepType helps people type Nepali using familiar Roman letters. The voice is clear, practical, and friendly. Emphasize local typing, spelling choices, and mixed Nepali–English text. Avoid claims about translation or AI understanding.

Optional short description: **Nepali typing, made simple.**

## Selected logo: blue NT

The owner selected **direction 1**, the blue NT monogram, on November 1, 2026. Its dark application variant uses a soft-white N, cobalt-blue T and cursor, and graphite background. Keep the NepType wordmark white in the dark app UI; blue is a brand accent rather than a change to editor or suggestion colors.

The approved artwork is [the master PNG](assets/neptype-icon-master.png). [The 1024-pixel icon](assets/neptype-icon-1024.png), [small mark](assets/neptype-mark.png), and [macOS icon](assets/NepType.icns) are exported from that image. The master is raster artwork; no vector master is asserted. Platform exports are installed in the iOS asset catalog, Android drawable resources, Linux assets, Windows icon resource, and landing-page assets. The Mac build scripts and isolated fresh-build tool bundle the mark and app icon.

Regenerate all platform sizes on macOS with `python3 scripts/export-brand-assets.py`. The older `swift platforms/ios/generate-app-icon.swift` command delegates to that exporter so it cannot restore the previous placeholder.

The master was refined from the selected concept with the built-in imagegen tool. The exact final prompt is in [final-logo-prompt.txt](final-logo-prompt.txt). Use the full-bleed square for system app icons; the OS supplies its icon mask where applicable. At narrow iPhone widths, show the mark alone to leave room for the language and help controls. The mark retains the accessible name NepType.

## Original concept explorations

1. [NT monogram](concepts/01-monogram.png): graphite and cobalt, with a cursor incorporated into the initials.
2. [Nepali letter key](concepts/02-letter-key.png): a vermilion keyboard key with **न** and a charcoal wordmark.
3. [Script bridge](concepts/03-script-bridge.png): teal and cream, with a continuous mark joining the initials and a script-inspired headline.

These presentations record the original exploration. Direction 1 is selected and its graphite variant is applied. Directions 2 and 3 remain unused.

Generated using the built-in imagegen tool. The full prompts are recorded in [logo-prompts.json](logo-prompts.json).

## Rebrand implementation

The current app labels, source namespaces, build products, setup instructions, and project documents use NepType. The language corpus retains ordinary Nepali words and Roman transliterations.

Pre-rebrand source backups, compiled previews, and screenshots are preserved outside the project at `/Users/anupdhakal/Desktop/apps/nepali-keyboard-archives/pre-neptype-2026-11-01`. The backup includes a file-change and path-rename manifest. Rebuilt previews belong in `build/`; new verification evidence belongs in `evidence/`.

Historical evaluation results retain their original measured values and digest values. Namespace paths were updated for navigation; those historical digests describe the source at measurement time and are not a checksum of the rebranded source. New verification results must be distinguished from those historical measurements. The portable-core source manifest was refreshed for the current snapshot.

The package identifiers, preference keys, environment variables, and command names were also renamed. Existing prototype installations are separate from builds using the new identifiers. This change does not migrate old installation settings or enable a keyboard automatically.

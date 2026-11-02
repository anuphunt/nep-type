# NepType desktop platform interfaces

The Windows and Linux standalone frontend sources now follow the Mac app's compact Graphite layout: Roman input, a horizontal suggestion area, read-only Nepali output and a quiet copy icon. Both default to 620 × 430 and support smaller desktop windows.

- Windows uses native Win32 rich-edit controls and neutral owner-drawn controls. Build with the Windows CMake project.
- Linux uses GTK 4 and Python GObject bindings. Run `platforms/linux/run-pad.sh`.

These two document-conversion bridges are not implemented yet. Both frontends explicitly show conversion as unavailable, keep output empty, and disable conversion/copy controls until a renderer is connected. Their existing experimental TSF and IBus services are separate and are not installed, activated, or modified by the UI launchers.

The development Mac can run the portable transaction and adapter tests, but has no Windows SDK or Linux GTK desktop. Native compilation, font rendering, accessibility and clipboard behavior still require those target environments. See each platform's README for build commands and integration limits.

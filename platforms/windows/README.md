# NepType Windows keyboard and typing pad

The source includes a live, in-process Microsoft Text Services Framework (TSF) keyboard alongside the existing Win32 typing pad. It uses the shared offline Rust engine and embedded dictionary; it does not use a global keyboard hook, clipboard injection, network service or subprocess per key. It is a development build on main pending the Windows host acceptance checks below. A keyboard installer has not been released.

## Typing

Choose **NepType Nepali Keyboard** using Win+Space. Type a Roman word and press Space to accept the highlighted conversion. Roman text stays visible in the composition while you type; the candidate window previews Nepali. The original spelling is always Ctrl+1. Ctrl+2–4 select the other visible choices; Up/Down cycle choices, Escape commits the original, and Backspace edits the Roman spelling. Enter and Tab commit the highlighted choice and then retain their normal application action.

Ctrl+Shift+Space cycles **Mixed → Nepali → English → Mixed**. Mixed preserves English according to the shared engine. English passes ordinary keys directly to Windows. Navigation and shortcuts end the current composition with the exact Roman text before Windows handles the key; Ctrl+Z is delegated to the host's undo system. Focus changes retain the Roman spelling and end only the owned composition, without moving selection or rewriting text. Each context has its own transaction generation; stale choices cannot be applied to another word.

Password/disabled/read-only contexts and non-prose input scopes (URL, email, numeric, PIN, telephone and private fields) pass through before text reaches the engine. Hosts must correctly expose their field semantics to TSF. Windows secure desktop activation is rejected. Terminals, elevated apps, Store apps, remote sessions and apps without a usable TSF text store are outside the validated support matrix until tested.

## Build

Use native Windows 10 1607+ or Windows 11, Visual Studio Desktop C++ workload, Windows SDK, CMake, Rust and Python. From the repository root:

```powershell
python scripts/engine-data.py check
cargo build --locked --release --manifest-path engine/Cargo.toml
New-Item -ItemType Directory -Force build/rust-windows
Copy-Item engine/target/release/neptype_engine.dll build/rust-windows/NepTypeEngine.dll
cmake -S platforms/windows -B build/windows -A x64 -DNEPTYPE_ENGINE_BINARY_DIR="$PWD/build/rust-windows"
cmake --build build/windows --config Release
ctest --test-dir build/windows -C Release --output-on-failure
cmake --install build/windows --config Release --prefix build/windows-package
```

The package contains the pad, `NepTypeTsf.dll`, `NepTypeEngine.dll`, the install script and this guide. Build native ARM64 separately with a matching Rust DLL and `-A ARM64`; ARM64 and 32-bit applications are not yet validated. Do not mix architectures or promise x86 coverage from an x64 build.

## Install and remove on a Windows test desktop

From a **native PowerShell as Administrator**, explicitly install the development build:

```powershell
./build/windows-package/install-keyboard.ps1 -Action Install
```

The script copies only the two DLLs into `Program Files/NepType Keyboard`, then runs native regsvr32. The DLL registers its COM class, Nepali language profile and keyboard category. It does not change the default language or input method. Sign out/back in, add Nepali in Settings → Time & language → Language & region, and add **NepType Nepali Keyboard** in its keyboard options. Select it with Win+Space. The pad's Keyboard setup button also offers this explicit installation when its packaged script is present.

Switch to another keyboard before removal:

```powershell
./build/windows-package/install-keyboard.ps1 -Action Uninstall
```

This unregisters the service. Sign out before deleting the two DLLs from `Program Files/NepType Keyboard`; open apps may still hold them. The installer refuses to overwrite an existing install. Keep builds unsigned/development-only until signing and clean-install, upgrade and uninstall checks are complete. UAC approval is a normal part of machine-wide TSF registration.

## Verification and limitations

`tests/run.sh` runs the existing portable composition, candidate, mocked lifecycle/edit and owned-range tests, plus the production keyboard transaction policy. Set `NEPTYPE_TEST_ENGINE=/absolute/path/to/libneptype_engine.dylib` (or `.so`) to test the same production candidate conversion bridge with the real engine. This covers default/explicit/original choice, repeated identical words, stale generations, conversion failure and literal URLs/email/numbers. These portable tests do not prove Windows host behavior.

On Windows, CTest also builds and loads the **production DLL** in `NepTypeNativeTsfTests` using a real Microsoft TSF thread manager, document, context and an application-owned `ITextStoreACP`. It exercises SDK ABI, real owned-range/composition semantics, typing, conversion, backspace, Escape, selected-text replacement, moved caret, denied locks, read-only behavior and teardown. The text store is a test host; this is not evidence of Notepad, Office or browser integration, OS profile routing or host undo.

The old `tsf/service.cpp` is retained only as a fake-interface lifecycle fixture. The production target builds `tsf/live_service.cpp` and `registration.cpp`. Key edits are synchronous: denied/unrun requests pass through and are never queued/replayed; late callbacks cannot use a previous stack. Focus cleanup uses separate asynchronous sessions that only end composition. A failure after a mutation attempt disables conversion for that context and avoids replaying an uncertain key; a hostile/partially failing host can still leave an incomplete edit. Switch to another keyboard and inspect text if that happens. Registration rollback and installer failure paths also require real-desktop verification.

Before release, execute and record every row in [WINDOWS_KEYBOARD_ACCEPTANCE.md](../../docs/WINDOWS_KEYBOARD_ACCEPTANCE.md). No desktop acceptance row is assumed to pass from unit tests or CI.

References: [TSF edit sessions](https://learn.microsoft.com/en-us/windows/win32/api/msctf/nf-msctf-itfcontext-requesteditsession), [composition ownership](https://learn.microsoft.com/en-us/windows/win32/api/msctf/nf-msctf-itfcontextcomposition-startcomposition), [language profiles](https://learn.microsoft.com/en-us/windows/win32/api/msctf/nn-msctf-itfinputprocessorprofiles), [input scopes](https://learn.microsoft.com/en-us/windows/win32/api/inputscope/nf-inputscope-itfinputscope-getinputscopes).

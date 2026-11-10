$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../../..").Path
$output = Join-Path $root 'build/windows-installer'
$packagePath = Join-Path $output 'package.json'
$package = Get-Content $packagePath -Raw | ConvertFrom-Json
$package.tested = $false
$installer = Join-Path $output $package.filename
$installed = Join-Path $env:LOCALAPPDATA 'Programs/NepType preview परीक्षण'
$shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'NepType.lnk'
$uninstallKey = 'HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/{5E4BC5AE-0272-4601-9D59-3018815A456C}_is1'
$stateDirectory = Join-Path $output 'isolated-user-state'
New-Item -ItemType Directory $stateDirectory -Force | Out-Null
$checks = [System.Collections.Generic.List[string]]::new()
$observations = [System.Collections.Generic.List[object]]::new()
function Record-PadState([string]$label) {
    if (!$window) { return }
    $snapshot = [ordered]@{
        label = $label
        input = [PadUI]::Text([PadUI]::GetDlgItem($window, 101))
        output = [PadUI]::Text([PadUI]::GetDlgItem($window, 102))
        status = [PadUI]::Text([PadUI]::GetDlgItem($window, 110))
        candidates = @(201..203 | ForEach-Object { [PadUI]::Text([PadUI]::GetDlgItem($window, $_)) })
    }
    $observations.Add($snapshot)
    Write-Host ('PAD STATE: ' + ($snapshot | ConvertTo-Json -Compress))
}
function Check($value, [string]$name) {
    if (!$value) { throw "FAILED: $name" }
    $checks.Add($name)
    Write-Host "PASS: $name"
}
function Wait-For([scriptblock]$condition, [string]$name) {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    do {
        if (& $condition) { Check $true $name; return }
        Start-Sleep -Milliseconds 100
    } while ([DateTime]::UtcNow -lt $deadline)
    Record-PadState "Timeout: $name"
    throw "Timed out: $name"
}
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class PadUI {
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr window, int id);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")]
    public static extern IntPtr Message(IntPtr window, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")]
    public static extern IntPtr SetText(IntPtr window, uint msg, IntPtr w, string text);
    [DllImport("user32.dll", CharSet=CharSet.Unicode, EntryPoint="SendMessageW")]
    public static extern IntPtr GetText(IntPtr window, uint msg, IntPtr length, StringBuilder text);
    public delegate bool WindowCallback(IntPtr window, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumWindows(WindowCallback callback, IntPtr data);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr window, WindowCallback callback, IntPtr data);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint process);
    public static IntPtr SetupDialog(int process) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((window, data) => {
            uint owner; GetWindowThreadProcessId(window, out owner);
            if (owner == process && Text(window) == "NepType keyboard setup") { found = window; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static string ChildText(IntPtr window) {
        var result = new StringBuilder();
        EnumChildWindows(window, (child, data) => { result.AppendLine(Text(child)); return true; }, IntPtr.Zero);
        return result.ToString();
    }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr window, out Rect rect);
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left,Top,Right,Bottom; }
    public static string Text(IntPtr window) {
        var text = new StringBuilder(32768);
        GetText(window, 13, (IntPtr)text.Capacity, text);
        return text.ToString();
    }
    public static string CandidateText(IntPtr window) {
        return System.Text.RegularExpressions.Regex.Replace(Text(window), @"  Ctrl\+[1-3]$", "");
    }
}
'@
function Click([IntPtr]$button) { [void][PadUI]::Message($button, 245, [IntPtr]::Zero, [IntPtr]::Zero) }
function Type-Text([IntPtr]$inputBox, [string]$text) {
    [void][PadUI]::SetText($inputBox, 12, [IntPtr]::Zero, $text)
    [void][PadUI]::Message($inputBox, 177, [IntPtr]$text.Length, [IntPtr]$text.Length)
}
function Launch-Pad {
    # Exercise installed files with no engine path overrides. Only LOCALAPPDATA
    # is isolated so tests never read or change a real user draft or spellings.
    Remove-Item Env:NEPTYPE_ENGINE_LIBRARY, Env:NEPTYPE_DICTIONARY_DIR -ErrorAction SilentlyContinue
    $expectGuide = !(Test-Path (Join-Path $stateDirectory 'NepType/guide'))
    $app = Start-Process (Join-Path $installed 'NepType.exe') -WorkingDirectory $env:TEMP -Environment @{ LOCALAPPDATA = $stateDirectory } -PassThru
    Wait-For { $app.Refresh(); $app.MainWindowHandle -ne [IntPtr]::Zero } 'Installed app launches from unrelated working directory'
    $dialog = [IntPtr]::Zero
    if ($expectGuide) {
        Wait-For { $script:dialog = [PadUI]::SetupDialog($app.Id); $script:dialog -ne [IntPtr]::Zero } 'First-launch setup guide appears'
        Check ([PadUI]::ChildText($script:dialog).Contains('system keyboard is still in development')) 'Setup guide accurately describes Windows keyboard availability'
        Check ([PadUI]::ChildText($script:dialog).Contains('Ctrl+1')) 'Setup guide explains native suggestion shortcuts'
        Click ([PadUI]::GetDlgItem($script:dialog, 7)) # No: do not open OS settings.
    }
    $app.Refresh()
    return $app
}
$app = $null
try {
    Check (!(Test-Path $installed)) 'Fresh install destination'
    Check (!(Test-Path $uninstallKey)) 'No previous NepType uninstall entry'
    Check (!(Test-Path $shortcut)) 'No previous NepType shortcut'
    Check (((Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()) -eq $package.sha256) 'Installer SHA-256 matches manifest'
    Check ((Get-AuthenticodeSignature $installer).Status -eq 'NotSigned') 'Unsigned status recorded accurately'
    $install = Start-Process $installer -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',"/DIR=`"$installed`"", "/LOG=`"$output/install.log`"") -Wait -PassThru
    Check ($install.ExitCode -eq 0) 'Installer exits successfully'
    Check (Test-Path "$installed/NepType.exe") 'Pad executable installed'
    Check (Test-Path "$installed/NepTypeEngine.dll") 'Offline engine installed'
    Check (Test-Path "$installed/dictionaries/neptype-dictionaries.json") 'Dictionary identity and attribution installed'
    Check (!(Get-ChildItem $installed -Recurse -Filter '*Tsf*')) 'Experimental TSF service excluded'
    Check (Test-Path $shortcut) 'Start menu shortcut created'
    Check (Test-Path $uninstallKey) 'Per-user uninstall entry created'
    foreach ($file in Get-ChildItem "$root/build/windows-payload" -File -Recurse) {
        $relative = [IO.Path]::GetRelativePath("$root/build/windows-payload", $file.FullName)
        Check ((Get-FileHash $file.FullName).Hash -eq (Get-FileHash (Join-Path $installed $relative)).Hash) "Installed bytes: $relative"
    }
    $vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
    $dumpbin = (& $vswhere -latest -products '*' -find 'VC/Tools/MSVC/**/bin/Hostx64/x64/dumpbin.exe' | Select-Object -First 1)
    Check (![string]::IsNullOrWhiteSpace($dumpbin)) 'Windows SDK dependency inspection available'
    foreach ($binary in @('NepType.exe','NepTypeEngine.dll')) {
        $dependencies = & $dumpbin /DEPENDENTS (Join-Path $installed $binary) | Out-String
        if ($LASTEXITCODE) { throw 'dumpbin failed' }
        $dependencies | Set-Content (Join-Path $output "$binary.dependencies.txt")
        Check ($dependencies -notmatch '(?i)(VCRUNTIME|MSVCP|CONCRT)\d+.*\.dll') "$binary needs no separate Visual C++ runtime"
    }
    $app = Launch-Pad
    $window = $app.MainWindowHandle
    $inputBox = [PadUI]::GetDlgItem($window, 101)
    $result = [PadUI]::GetDlgItem($window, 102)
    $status = [PadUI]::GetDlgItem($window, 110)
    Check ($inputBox -ne [IntPtr]::Zero -and $result -ne [IntPtr]::Zero) 'Native editors exist'
    Wait-For { [PadUI]::Text($status) -eq 'Local · Shared offline engine' } 'Installed offline engine loads'
    Type-Text $inputBox 'namaste'
    Wait-For { [PadUI]::Text($result) -eq 'नमस्ते' } 'Roman input renders Devanagari'
    Click ([PadUI]::GetDlgItem($window, 104))
    Wait-For { (Get-Clipboard -Raw) -eq 'नमस्ते' } 'Copy button writes Unicode clipboard'
    Type-Text $inputBox 'gaadi gadi gayera'
    Wait-For { [PadUI]::Text($result).Length -gt 0 } 'Dictionary renders the historical vehicle probe'
    Record-PadState 'Historical vocabulary probe; quality differences remain documented'
    Type-Text $inputBox 'pani'
    # The frozen shared-engine contract defaults to पनि. Select पानी so this
    # assertion exercises an actual output change rather than selecting default.
    Wait-For { [PadUI]::Text($result) -eq 'पनि' } 'Pani default spelling matches shared engine'
    Record-PadState 'Pani default before selection'
    $candidate = [IntPtr]::Zero
    Wait-For {
        foreach ($id in 201..203) {
            $button = [PadUI]::GetDlgItem($window, $id)
            if ([PadUI]::CandidateText($button) -eq 'पानी') { $script:candidate = $button; return $true }
        }
        return $false
    } 'Alternative spelling appears'
    Click $candidate
    Wait-For { [PadUI]::Text($result) -eq 'पानी' } 'Alternative candidate selection changes output'
    Check ([PadUI]::Text($inputBox) -eq 'pani') 'Candidate selection preserves Roman input'
    Record-PadState 'Pani alternative selected'
    $candidate = [IntPtr]::Zero
    Wait-For {
        foreach ($id in 201..203) {
            $button = [PadUI]::GetDlgItem($window, $id)
            if ([PadUI]::CandidateText($button) -eq 'pani') { $script:candidate = $button; return $true }
        }
        return $false
    } 'Original Roman spelling remains offered'
    Click $candidate
    Wait-For { [PadUI]::Text($result) -eq 'pani' } 'Original Roman spelling can be selected'
    Record-PadState 'Pani original selected'
    Type-Text $inputBox 'school'
    Wait-For { [PadUI]::Text($result) -eq 'school' } 'Mixed mode preserves English'
    Click ([PadUI]::GetDlgItem($window, 106))
    Wait-For { [PadUI]::Text($result) -match '[\u0900-\u097f]' } 'All Nepali mode converts English letters'
    Click ([PadUI]::GetDlgItem($window, 105))
    Type-Text $inputBox 'namaste! malai momo man parcha.'
    Wait-For { [PadUI]::Text($result).Contains('नमस्ते') } 'Sentence conversion'
    Add-Type -AssemblyName System.Drawing
    $rect = New-Object PadUI+Rect
    Check ([PadUI]::GetWindowRect($window, [ref]$rect)) 'Window geometry available'
    $bitmap = [Drawing.Bitmap]::new($rect.Right-$rect.Left, $rect.Bottom-$rect.Top)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($rect.Left,$rect.Top,0,0,$bitmap.Size)
    $bitmap.Save((Join-Path $output 'installed-pad.png'))
    $graphics.Dispose(); $bitmap.Dispose()
    Type-Text $inputBox 'namaste gayera'
    Click ([PadUI]::GetDlgItem($window, 106))
    Wait-For { [PadUI]::Text($result) -eq 'नमस्ते गएर' } 'Draft prepared for relaunch'
    [void]$app.CloseMainWindow()
    Check ($app.WaitForExit(30000)) 'Draft saves on clean exit'
    $app = Launch-Pad
    $window = $app.MainWindowHandle
    $inputBox = [PadUI]::GetDlgItem($window, 101)
    $result = [PadUI]::GetDlgItem($window, 102)
    Wait-For { [PadUI]::Text($inputBox) -eq 'namaste gayera' -and [PadUI]::Text($result) -eq 'नमस्ते गएर' } 'Installed draft restores after relaunch'
    Check ((Get-Content (Join-Path $stateDirectory 'NepType/mode') -Raw).Trim() -eq '2') 'Output mode persists locally'
    Click ([PadUI]::GetDlgItem($window, 103))
    Wait-For { [PadUI]::Text($inputBox) -eq '' -and [PadUI]::Text($result) -eq '' } 'Clear empties local pad'
    [void]$app.CloseMainWindow()
    Check ($app.WaitForExit(30000)) 'App exits cleanly'
    Check ($app.ExitCode -eq 0) 'App exit code'
    $app = $null
    $reinstall = Start-Process $installer -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',"/DIR=`"$installed`"", "/LOG=`"$output/reinstall.log`"") -Wait -PassThru
    Check ($reinstall.ExitCode -eq 0) 'Same-version reinstall succeeds'
    $app = Launch-Pad
    Wait-For { [PadUI]::Text([PadUI]::GetDlgItem($app.MainWindowHandle,110)) -eq 'Local · Shared offline engine' } 'Reinstalled pad loads engine'
    [void]$app.CloseMainWindow()
    Check ($app.WaitForExit(30000)) 'Reinstalled pad exits'
    $app = $null
    $uninstall = Start-Process "$installed/unins000.exe" -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=`"$output/uninstall.log`"") -Wait -PassThru
    Check ($uninstall.ExitCode -eq 0) 'Uninstaller exits successfully'
    Wait-For { !(Test-Path "$installed/NepType.exe") -and !(Test-Path "$installed/NepTypeEngine.dll") } 'App and engine removed'
    Check (!(Test-Path $uninstallKey)) 'Uninstall entry removed'
    Check (!(Test-Path $shortcut)) 'Start menu shortcut removed'
    Check (!(Test-Path $installed)) 'Install directory removed'
    $package.tested = $true
    $package | ConvertTo-Json | Set-Content $packagePath -Encoding utf8
} finally {
    $observations | ConvertTo-Json -Depth 5 -AsArray | Set-Content "$output/observations.json" -Encoding utf8
    if ($app -and !$app.HasExited) { $app.Kill(); $app.WaitForExit() }
    $package | ConvertTo-Json | Set-Content $packagePath -Encoding utf8
    [ordered]@{
        sourceCommit = $package.sourceCommit
        installerSha256 = $package.sha256
        success = $package.tested
        os = (Get-CimInstance Win32_OperatingSystem).Caption
        architecture = $env:PROCESSOR_ARCHITECTURE
        runnerImage = $env:ImageVersion
        checks = $checks
        limitations = @('Automated Windows Server 2022 runner, not consumer Windows 10/11.', 'No manual accessibility, high-DPI, ARM64, browser download or SmartScreen acceptance test.', 'Unsigned preview; no publisher identity or SmartScreen reputation established.')
    } | ConvertTo-Json -Depth 5 | Set-Content "$output/verification.json" -Encoding utf8
}

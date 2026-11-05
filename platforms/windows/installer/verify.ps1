$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {
    throw 'Installer verification changes machine registration and must run on a disposable GitHub-hosted Windows runner.'
}
$root = (Resolve-Path "$PSScriptRoot/../../..").Path
$output = Join-Path $root 'build/windows-installer'
$packagePath = Join-Path $output 'package.json'
$package = Get-Content $packagePath -Raw | ConvertFrom-Json
$package.tested = $false
$installer = Join-Path $output $package.filename
$installed = Join-Path $env:ProgramFiles 'NepType preview परीक्षण'
$shortcut = Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'NepType.lnk'
$uninstallKey = 'HKLM:/Software/Microsoft/Windows/CurrentVersion/Uninstall/{36AC730E-43BC-4D6B-B6BB-38F712E24BF7}_is1'
$legacyKey = 'HKCU:/Software/Microsoft/Windows/CurrentVersion/Uninstall/{5E4BC5AE-0272-4601-9D59-3018815A456C}_is1'
$keyboardRoot = Join-Path $env:ProgramFiles 'NepType Keyboard'
$keyboardRegistry = 'HKLM:/Software/Classes/CLSID/{B6A68F96-5819-4B7F-8569-A11590D12001}/InprocServer32'
$buildHelper = Join-Path $root 'build/windows/Release/NepTypeKeyboardSetup.exe'
$fixture = Get-Content (Join-Path $output 'upgrade-fixture/package.json') -Raw | ConvertFrom-Json
$fixtureInstaller = Join-Path $output "upgrade-fixture/$($fixture.filename)"
$rollbackFixture = Get-Content (Join-Path $output 'rollback-fixture/package.json') -Raw | ConvertFrom-Json
$rollbackInstaller = Join-Path $output "rollback-fixture/$($rollbackFixture.filename)"
$hold = $null
$holdReady = Join-Path $output 'held-old-dlls.json'
$holdStop = Join-Path $output 'release-held-dlls'
$legacyCreated = $false
$aclFixture = Join-Path $env:ProgramFiles ('NepType-CI-ACL-' + [Guid]::NewGuid().ToString('N'))
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
        Check ([PadUI]::ChildText($script:dialog).Contains('Windows keyboard is installed')) 'Setup guide confirms the installed system keyboard'
        Check ([PadUI]::ChildText($script:dialog).Contains('Ctrl+1')) 'Setup guide explains native suggestion shortcuts'
        Click ([PadUI]::GetDlgItem($script:dialog, 7)) # No: do not open OS settings.
    }
    $app.Refresh()
    return $app
}
function Read-RegisteredKeyboard {
    if (!(Test-Path $keyboardRegistry)) { return '' }
    return [string](Get-Item -LiteralPath $keyboardRegistry).GetValue('')
}
function Run-KeyboardHelper([string]$helper, [string[]]$arguments, [bool]$expectFailure = $false) {
    $text = & $helper @arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    Write-Host $text
    if ($expectFailure) { Check ($code -ne 0) ('Keyboard helper rejects: ' + ($arguments -join ' ')) }
    else { Check ($code -eq 0) ('Keyboard helper succeeds: ' + ($arguments -join ' ')) }
    return $text
}
function Install-Package([string]$path, [string]$label, [bool]$expectFailure = $false) {
    $process = Start-Process $path -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/SP-',"/DIR=`"$installed`"", "/LOG=`"$output/$label.log`"") -Wait -PassThru
    if ($expectFailure) {
        Check ($process.ExitCode -ne 0) "$label returns failure"
        if ($label.StartsWith('injected-')) {
            $failureLog = Get-Content "$output/$label.log" -Raw
            Check ($failureLog -match 'CI fixture: fail after keyboard registration') "$label reaches the intended post-registration failure"
            Check ($failureLog -match 'Keyboard helper: begin .*; exit 0') "$label registered its staged payload before failing"
            Check ($failureLog -match 'Keyboard helper: rollback .*; exit 0') "$label completes native rollback during installer cleanup"
        }
    }
    else {
        Check ($process.ExitCode -eq 0) "$label succeeds"
        Check ((Get-Content "$output/$label.log" -Raw) -notmatch '(?i)(raised an exception|Runtime error)') "$label has no ignored installer exceptions"
    }
}
function Verify-InstalledKeyboard {
    $path = Read-RegisteredKeyboard
    Check (![string]::IsNullOrEmpty($path) -and (Test-Path -LiteralPath $path)) 'Registered keyboard DLL exists'
    Check ($path.StartsWith((Join-Path $keyboardRoot 'versions'), [StringComparison]::OrdinalIgnoreCase)) 'COM registration uses a protected version folder'
    Check ((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -eq $package.keyboardPayload.tsfSha256) 'Installed TSF bytes match the package'
    Check ((Get-FileHash -LiteralPath (Join-Path (Split-Path $path) 'NepTypeEngine.dll')).Hash.ToLowerInvariant() -eq $package.keyboardPayload.engineSha256) 'Installed keyboard engine bytes match the package'
    $statusText = Run-KeyboardHelper (Join-Path $installed 'NepTypeKeyboardSetup.exe') @('status')
    Check ($statusText -match 'User enabled: 1') 'Existing account enablement is retained'
    & "$root/build/windows/Release/NepTypeNativeTsfTests.exe" $path --existing-registration 2>&1 | Tee-Object -FilePath (Join-Path $output 'installed-keyboard-test.log') -Append
    Check ($LASTEXITCODE -eq 0) 'Installed keyboard types through native TSF and cleans its temporary profile'
    Check ((Read-RegisteredKeyboard) -eq $path) 'Native fixture preserves the installed production registration'
}
function Uninstall-Package([string]$label) {
    $process = Start-Process "$installed/unins000.exe" -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/LOG=`"$output/$label.log`"") -Wait -PassThru
    Check ($process.ExitCode -eq 0) "$label succeeds without restarting Windows automatically"
}
$app = $null
try {
    Check (!(Test-Path $installed)) 'Fresh machine-wide install destination'
    Check (!(Test-Path $keyboardRoot)) 'Fresh protected keyboard root'
    Check (!(Test-Path $keyboardRegistry)) 'No previous keyboard registration'
    Check (!(Test-Path $uninstallKey)) 'No previous machine uninstall entry'
    Check (!(Test-Path $legacyKey)) 'No previous per-user pad entry'
    Check (!(Test-Path $shortcut)) 'No previous common Start shortcut'
    Check ($package.systemKeyboard -and $package.installationScope -eq 'machine') 'Package declares the system keyboard and machine scope'
    Check ($fixture.testFixture -and !$package.testFixture) 'Upgrade fixture is separate from the distributable package'
    Check (((Get-FileHash $installer -Algorithm SHA256).Hash.ToLowerInvariant()) -eq $package.sha256) 'Installer SHA-256 matches manifest'
    Check ((Get-AuthenticodeSignature $installer).Status -eq 'NotSigned') 'Unsigned status recorded accurately'
    # Reject explicit account permissions, ownership and writable ancestry,
    # rather than relying only on a Program Files path prefix.
    New-Item -ItemType Directory $aclFixture -Force | Out-Null
    $null = Run-KeyboardHelper $buildHelper @('probe', $aclFixture)
    $account = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $originalAcl = Get-Acl $aclFixture
    $writableAcl = Get-Acl $aclFixture
    $writableAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($account, 'Modify', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    Set-Acl $aclFixture $writableAcl
    $null = Run-KeyboardHelper $buildHelper @('probe', $aclFixture) $true
    $child = Join-Path $aclFixture 'protected-child'
    New-Item -ItemType Directory $child -Force | Out-Null
    $childAcl = Get-Acl $child
    $childAcl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {
        $childAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    }
    Set-Acl $child $childAcl
    $null = Run-KeyboardHelper $buildHelper @('probe', $child) $true
    Set-Acl $aclFixture $originalAcl
    $ownerAcl = Get-Acl $aclFixture; $ownerAcl.SetOwner($account); Set-Acl $aclFixture $ownerAcl
    $null = Run-KeyboardHelper $buildHelper @('probe', $aclFixture) $true
    Remove-Item $aclFixture -Recurse -Force
    # A per-user uninstaller is never launched with the elevated setup token.
    New-Item $legacyKey -Force | Out-Null; $legacyCreated = $true
    New-ItemProperty $legacyKey -Name DisplayName -Value 'NepType legacy CI fixture' -Force | Out-Null
    Install-Package $installer 'legacy-pad-blocked' $true
    Check (!(Test-Path $installed) -and !(Test-Path $keyboardRegistry)) 'Legacy pad blocker changes no app files or COM registration'
    Remove-Item $legacyKey -Force; $legacyCreated = $false
    # Exercise journal rollback before a fresh install and reject changed bytes.
    $freshTransaction = [Guid]::NewGuid().ToString('N')
    $null = Run-KeyboardHelper $buildHelper @('begin', (Join-Path $package.payloadDirectory 'keyboard'), $package.version, $freshTransaction)
    Check (![string]::IsNullOrEmpty((Read-RegisteredKeyboard))) 'Fresh transaction registers staged keyboard files'
    $null = Run-KeyboardHelper $buildHelper @('rollback', $freshTransaction)
    Check (!(Test-Path $keyboardRegistry)) 'Fresh rollback removes its registration'
    $null = Run-KeyboardHelper $buildHelper @('cleanup')
    Check ($rollbackFixture.testFixture -and $rollbackFixture.rollbackInjection -and !$package.rollbackInjection) 'Rollback injection is isolated from the distributable installer'
    Install-Package $rollbackInstaller 'injected-fresh-install-failure' $true
    Check (!(Test-Path $installed) -and !(Test-Path $keyboardRegistry) -and !(Test-Path $uninstallKey)) 'Failed fresh installer rolls back app files, COM registration and uninstall entry'
    $null = Run-KeyboardHelper $buildHelper @('cleanup')
    $tampered = Join-Path $output 'tampered-payload'
    Copy-Item (Join-Path $package.payloadDirectory 'keyboard') $tampered -Recurse
    $data = [IO.File]::ReadAllBytes((Join-Path $tampered 'NepTypeTsf.dll')); $data[0] = $data[0] -bxor 1
    [IO.File]::WriteAllBytes((Join-Path $tampered 'NepTypeTsf.dll'), $data)
    $null = Run-KeyboardHelper $buildHelper @('begin', $tampered, $package.version, 'bad-payload') $true
    Check (!(Test-Path $keyboardRegistry)) 'Rejected payload does not change registration'
    Install-Package $fixtureInstaller 'install-older-keyboard-fixture'
    $helper = Join-Path $installed 'NepTypeKeyboardSetup.exe'
    $null = Run-KeyboardHelper $helper @('enable-user')
    $oldKeyboard = Read-RegisteredKeyboard
    Check (Test-Path -LiteralPath $oldKeyboard) 'Older keyboard fixture is registered'
    $oldHash = (Get-FileHash -LiteralPath $oldKeyboard).Hash
    Install-Package $rollbackInstaller 'injected-upgrade-failure' $true
    Check ((Read-RegisteredKeyboard) -eq $oldKeyboard -and (Test-Path $installed)) 'Failed upgrade restores the previous registered keyboard and installed app'
    Verify-InstalledKeyboard
    $python = (Get-Command python).Source
    $hold = Start-Process $python -ArgumentList @('-u', "`"$PSScriptRoot/hold_dlls.py`"", "`"$oldKeyboard`"", "`"$(Join-Path (Split-Path $oldKeyboard) 'NepTypeEngine.dll')`"", "`"$holdReady`"", "`"$holdStop`"") -PassThru
    Wait-For { Test-Path $holdReady } 'Old keyboard DLL and engine are held by another process'
    Install-Package $installer 'upgrade-to-keyboard-package'
    $activeKeyboard = Read-RegisteredKeyboard
    Check ($activeKeyboard -ne $oldKeyboard) 'Upgrade switches registration to a new immutable folder'
    Check ((Get-FileHash -LiteralPath $oldKeyboard).Hash -eq $oldHash -and !$hold.HasExited) 'Loaded old DLL bytes are untouched and its host is not terminated'
    Check (Test-Path "$installed/NepType.exe") 'Pad executable installed'
    Check (Test-Path "$installed/NepTypeEngine.dll") 'Offline pad engine installed'
    Check (Test-Path "$installed/NepTypeKeyboardSetup.exe") 'Native setup helper installed'
    Check (Test-Path "$installed/dictionaries/neptype-dictionaries.json") 'Dictionary identity and attribution installed'
    Check (Test-Path $shortcut) 'Common Start menu shortcut created'
    Check (Test-Path $uninstallKey) 'Machine uninstall entry created'
    foreach ($file in Get-ChildItem $package.payloadDirectory -File -Recurse) {
        $relative = [IO.Path]::GetRelativePath($package.payloadDirectory, $file.FullName)
        if ($relative.StartsWith('keyboard' + [IO.Path]::DirectorySeparatorChar)) { $relative = $relative.Replace('keyboard' + [IO.Path]::DirectorySeparatorChar, 'keyboard-payload' + [IO.Path]::DirectorySeparatorChar) }
        Check ((Get-FileHash $file.FullName).Hash -eq (Get-FileHash (Join-Path $installed $relative)).Hash) "Installed bytes: $relative"
    }
    $rollbackTransaction = [Guid]::NewGuid().ToString('N')
    $null = Run-KeyboardHelper $helper @('begin', (Join-Path $fixture.payloadDirectory 'keyboard'), $fixture.version, $rollbackTransaction)
    Check ((Read-RegisteredKeyboard) -ne $activeKeyboard) 'Upgrade transaction switches to its staged target'
    $null = Run-KeyboardHelper $helper @('rollback', $rollbackTransaction)
    Check ((Read-RegisteredKeyboard) -eq $activeKeyboard) 'Upgrade rollback restores the previous registered DLL'
    $recoveryTransaction = [Guid]::NewGuid().ToString('N')
    $null = Run-KeyboardHelper $helper @('begin', (Join-Path $fixture.payloadDirectory 'keyboard'), $fixture.version, $recoveryTransaction)
    $null = Run-KeyboardHelper $helper @('recover')
    Check ((Read-RegisteredKeyboard) -eq $activeKeyboard) 'Next-process recovery restores an uncommitted installation'
    Verify-InstalledKeyboard
    $vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
    $dumpbin = (& $vswhere -latest -products '*' -find 'VC/Tools/MSVC/**/bin/Hostx64/x64/dumpbin.exe' | Select-Object -First 1)
    Check (![string]::IsNullOrWhiteSpace($dumpbin)) 'Windows SDK dependency inspection available'
    foreach ($binary in @('NepType.exe','NepTypeEngine.dll','NepTypeKeyboardSetup.exe','keyboard-payload/NepTypeTsf.dll')) {
        $dependencies = & $dumpbin /DEPENDENTS (Join-Path $installed $binary) | Out-String
        if ($LASTEXITCODE) { throw 'dumpbin failed' }
        $dependencies | Set-Content (Join-Path $output ($binary.Replace('/', '-') + '.dependencies.txt'))
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
    Wait-For { [PadUI]::Text($result) -eq 'गाडी गाडी गएर' } 'Vehicle and gayera spelling regressions fixed in installed engine'
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
    Type-Text $inputBox 'gaadi gayera'
    Click ([PadUI]::GetDlgItem($window, 106))
    Wait-For { [PadUI]::Text($result) -eq 'गाडी गएर' } 'Draft prepared for relaunch'
    [void]$app.CloseMainWindow()
    Check ($app.WaitForExit(30000)) 'Draft saves on clean exit'
    $app = Launch-Pad
    $window = $app.MainWindowHandle
    $inputBox = [PadUI]::GetDlgItem($window, 101)
    $result = [PadUI]::GetDlgItem($window, 102)
    Wait-For { [PadUI]::Text($inputBox) -eq 'gaadi gayera' -and [PadUI]::Text($result) -eq 'गाडी गएर' } 'Installed draft restores after relaunch'
    Check ((Get-Content (Join-Path $stateDirectory 'NepType/mode') -Raw).Trim() -eq '2') 'Output mode persists locally'
    Click ([PadUI]::GetDlgItem($window, 103))
    Wait-For { [PadUI]::Text($inputBox) -eq '' -and [PadUI]::Text($result) -eq '' } 'Clear empties local pad'
    [void]$app.CloseMainWindow()
    Check ($app.WaitForExit(30000)) 'App exits cleanly'
    Check ($app.ExitCode -eq 0) 'App exit code'
    $app = $null
    Install-Package $installer 'same-version-reinstall'
    Check ((Read-RegisteredKeyboard) -eq $activeKeyboard) 'Same-version reinstall reuses the intact active payload'
    $app = Launch-Pad
    Wait-For { [PadUI]::Text([PadUI]::GetDlgItem($app.MainWindowHandle,110)) -eq 'Local · Shared offline engine' } 'Reinstalled pad loads engine'
    [void]$app.CloseMainWindow(); Check ($app.WaitForExit(30000)) 'Reinstalled pad exits'; $app = $null
    Uninstall-Package 'uninstall-with-loaded-old-keyboard'
    Check (!(Test-Path $keyboardRegistry)) 'Uninstall removes COM registration before deleting keyboard files'
    Check (!(Test-Path $uninstallKey) -and !(Test-Path $shortcut)) 'Machine uninstall entry and shortcut removed'
    Check (!(Test-Path $installed)) 'Pad installation directory removed'
    Check (!$hold.HasExited -and (Test-Path -LiteralPath $oldKeyboard)) 'Uninstall keeps loaded DLLs without terminating their host'
    $pending = (Get-ItemProperty 'HKLM:/SYSTEM/CurrentControlSet/Control/Session Manager').PendingFileRenameOperations
    Check (($pending -join "`n").IndexOf($oldKeyboard,[StringComparison]::OrdinalIgnoreCase) -ge 0) 'Loaded old DLL is scheduled for removal at restart'
    # Reinstall before restart must never reuse a path in that pending list.
    Install-Package $installer 'reinstall-before-restart'
    $reinstalledKeyboard = Read-RegisteredKeyboard
    Check ($reinstalledKeyboard -ne $oldKeyboard -and $reinstalledKeyboard -ne $activeKeyboard) 'Reinstall uses a fresh generation after deferred removal'
    Check (($pending -join "`n").IndexOf($reinstalledKeyboard,[StringComparison]::OrdinalIgnoreCase) -lt 0) 'Pending deletion does not target the reinstalled active DLL'
    $null = Run-KeyboardHelper (Join-Path $installed 'NepTypeKeyboardSetup.exe') @('enable-user')
    Verify-InstalledKeyboard
    New-Item -ItemType File $holdStop -Force | Out-Null
    Check ($hold.WaitForExit(10000) -and $hold.ExitCode -eq 0) 'Old host exits only when the test requests it'
    $hold = $null
    Uninstall-Package 'uninstall-final'
    Check (!(Test-Path $keyboardRegistry)) 'Final removal leaves no COM registration'
    if (Test-Path $keyboardRoot) {
        $finalPending = (Get-ItemProperty 'HKLM:/SYSTEM/CurrentControlSet/Control/Session Manager').PendingFileRenameOperations -join "`n"
        Check (!(Test-Path (Join-Path $keyboardRoot 'setup.ini'))) 'No active keyboard state remains after removal'
        foreach ($file in Get-ChildItem $keyboardRoot -Recurse -File) {
            Check ($finalPending.IndexOf($file.FullName,[StringComparison]::OrdinalIgnoreCase) -ge 0) "Remaining file is scheduled for restart cleanup: $($file.Name)"
        }
    } else { Check $true 'All managed keyboard folders removed without restart' }
    Check (!(Test-Path $uninstallKey) -and !(Test-Path $installed) -and !(Test-Path $shortcut)) 'Final removal clears app files, shortcut and machine entry'
    $package.tested = $true
    $package | ConvertTo-Json | Set-Content $packagePath -Encoding utf8
} finally {
    $observations | ConvertTo-Json -Depth 5 -AsArray | Set-Content "$output/observations.json" -Encoding utf8
    if ($legacyCreated) { Remove-Item $legacyKey -Force -ErrorAction SilentlyContinue }
    if (Test-Path $aclFixture) { Remove-Item $aclFixture -Recurse -Force -ErrorAction SilentlyContinue }
    if ($hold -and !$hold.HasExited) { New-Item -ItemType File $holdStop -Force | Out-Null; if (!$hold.WaitForExit(10000)) { $hold.Kill(); $hold.WaitForExit() } }
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
        limitations = @('Automated Windows Server 2022 runner, not consumer Windows 10/11.', 'No manual accessibility, high-DPI, ARM64, browser download or SmartScreen acceptance test.', 'Unsigned preview; no publisher identity or SmartScreen reputation established.', 'Temporary native TSF test profile uses the current input language; consumer Nepali language setup and physical layouts are not tested.', 'Locked-file removal is scheduled and path separation verified; an actual restart is not performed.')
    } | ConvertTo-Json -Depth 5 | Set-Content "$output/verification.json" -Encoding utf8
}

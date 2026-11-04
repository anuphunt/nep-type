# Run from a matching native x64/ARM64 PowerShell, as Administrator.
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall')][string]$Action = 'Install',
    [string]$BuildDirectory = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open a native PowerShell as Administrator and run this command again.'
}
if (-not [Environment]::Is64BitProcess) { throw 'Use native 64-bit PowerShell.' }
$nativeArchitecture = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
if ($env:PROCESSOR_ARCHITECTURE -ne $nativeArchitecture) { throw 'Use native PowerShell, rather than an emulated process.' }
$expectedMachine = switch ($nativeArchitecture) { 'AMD64' { 0x8664 } 'ARM64' { 0xAA64 } default { throw 'Only native x64 and ARM64 builds are supported.' } }
function Get-PeMachine([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Invalid Windows DLL header.' }
        $stream.Position = 0x3C
        $offset = $reader.ReadInt32()
        if ($offset -lt 64 -or $offset -gt ($stream.Length - 6)) { throw 'Invalid Windows DLL offset.' }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x4550) { throw 'Invalid Windows DLL signature.' }
        return $reader.ReadUInt16()
    } finally { $reader.Dispose(); $stream.Dispose() }
}
$destination = Join-Path $env:ProgramFiles 'NepType Keyboard'
$dll = Join-Path $destination 'NepTypeTsf.dll'
$regsvr = Join-Path $env:windir 'System32\regsvr32.exe'
if ($Action -eq 'Install') {
    foreach ($name in @('NepTypeTsf.dll', 'NepTypeEngine.dll')) {
        if (-not (Test-Path -LiteralPath (Join-Path $BuildDirectory $name))) { throw "Missing $name in $BuildDirectory" }
        if ((Get-PeMachine (Join-Path $BuildDirectory $name)) -ne $expectedMachine) { throw "$name does not match this Windows architecture." }
    }
    if (Test-Path -LiteralPath $dll) {
        throw 'A keyboard is already installed. Switch to another keyboard, uninstall, sign out, then install the new build.'
    }
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    try {
        foreach ($name in @('NepTypeTsf.dll', 'NepTypeEngine.dll')) {
            Copy-Item -LiteralPath (Join-Path $BuildDirectory $name) -Destination $destination
        }
        $process = Start-Process -FilePath $regsvr -ArgumentList @('/s', ('"' + $dll + '"')) -PassThru -Wait
        if ($process.ExitCode -ne 0) { throw "Keyboard registration failed ($($process.ExitCode)). Check DLL architecture and administrator access." }
    } catch {
        if (Test-Path -LiteralPath $dll) {
            Start-Process -FilePath $regsvr -ArgumentList @('/s', '/u', ('"' + $dll + '"')) -Wait | Out-Null
        }
        throw
    }
    Write-Host 'Installed. Sign out and back in. Add Nepali in Settings > Time & language > Language & region, then choose NepType Nepali Keyboard in its keyboard options. Use Win+Space to select it.'
} else {
    if (-not (Test-Path -LiteralPath $dll)) { throw 'No installed NepType keyboard was found.' }
    $process = Start-Process -FilePath $regsvr -ArgumentList @('/s', '/u', ('"' + $dll + '"')) -PassThru -Wait
    if ($process.ExitCode -ne 0) { throw "Unregistration failed ($($process.ExitCode)); files have been kept." }
    Write-Host 'Unregistered. Switch to another keyboard and sign out before removing the two DLLs from Program Files\NepType Keyboard. Running apps may still hold them open.'
}

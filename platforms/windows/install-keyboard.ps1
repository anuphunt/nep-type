# Developer/portable setup. The consumer Inno installer calls the same native
# transaction helper directly; it does not run a PowerShell script.
#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Uninstall')][string]$Action = 'Install',
    [string]$BuildDirectory = $PSScriptRoot
)
$ErrorActionPreference = 'Stop'
$helper = Join-Path $BuildDirectory 'NepTypeKeyboardSetup.exe'
if (-not (Test-Path -LiteralPath $helper)) { throw 'Build/extract the complete keyboard package, including NepTypeKeyboardSetup.exe.' }
function Invoke-KeyboardSetup([string[]]$Arguments, [int[]]$Allowed = @(0)) {
    & $helper @Arguments
    if ($LASTEXITCODE -notin $Allowed) { throw "Keyboard setup failed ($LASTEXITCODE). Existing version folders and any recovery journal were kept." }
}
if ($Action -eq 'Install') {
    $transaction = [Guid]::NewGuid().ToString('N')
    $version = 'dev-' + (Get-FileHash (Join-Path $BuildDirectory 'NepTypeTsf.dll') -Algorithm SHA256).Hash.Substring(0,12).ToLowerInvariant()
    try {
        Invoke-KeyboardSetup @('begin', [IO.Path]::GetFullPath($BuildDirectory), $version, $transaction)
        Invoke-KeyboardSetup @('commit', $transaction)
    } catch {
        & $helper rollback $transaction
        throw
    }
    Write-Host 'Installed. Add/enable NepType under Nepali in Windows language settings, then use Win+Space. Your default keyboard was not changed.'
} else {
    Invoke-KeyboardSetup @('uninstall') @(0,3010)
    if ($LASTEXITCODE -eq 3010) { Write-Host 'Unregistered. Restart Windows to remove files held by open apps; no app was forcibly closed.' }
    else { Write-Host 'The managed keyboard registration and payloads were removed.' }
}

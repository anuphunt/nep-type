param(
    [string]$Version = '0.1.4-preview.1',
    [string]$OutputDirectory = '',
    [switch]$TestFixture,
    [switch]$TestRollback
)
$ErrorActionPreference = 'Stop'
if ($TestRollback -and !$TestFixture) { throw 'Rollback injection is only allowed in a separately marked CI test fixture.' }
$root = (Resolve-Path "$PSScriptRoot/../../..").Path
if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)-preview\.(\d+)$') { throw 'Use an immutable x.y.z-preview.n version.' }
$numericVersion = "$($Matches[1]).$($Matches[2]).$($Matches[3]).$($Matches[4])"
$output = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $root 'build/windows-installer' }
$payload = Join-Path $root "build/windows-payload/$Version"
if (Test-Path $payload) { Remove-Item $payload -Recurse -Force }
New-Item -ItemType Directory $output, $payload -Force | Out-Null
New-Item -ItemType Directory (Join-Path $payload 'keyboard') -Force | Out-Null
Copy-Item "$root/build/windows/Release/NepTypeWindows.exe" "$payload/NepType.exe"
Copy-Item "$root/build/windows/Release/NepTypeEngine.dll" $payload
Copy-Item "$root/build/windows/Release/NepTypeKeyboardSetup.exe" $payload
Copy-Item "$root/build/windows/Release/NepTypeTsf.dll" "$payload/keyboard"
Copy-Item "$root/build/windows/Release/NepTypeEngine.dll" "$payload/keyboard"
Copy-Item "$root/build/windows/Release/dictionaries" $payload -Recurse -Force
Copy-Item "$root/LICENSE" "$payload/LICENSE.txt"
Copy-Item "$root/THIRD_PARTY_NOTICES.md" $payload
Copy-Item "$PSScriptRoot/preview.txt" "$payload/README.txt"
# Explicit payload: the pad, bounded native setup helper and actual TSF keyboard.
$expected = @('NepType.exe', 'NepTypeEngine.dll', 'NepTypeKeyboardSetup.exe', 'keyboard', 'dictionaries', 'LICENSE.txt', 'THIRD_PARTY_NOTICES.md', 'README.txt')
foreach ($item in Get-ChildItem $payload) {
    if ($item.Name -notin $expected) { throw "Unexpected payload file: $($item.Name)" }
}
foreach ($item in Get-ChildItem "$payload/keyboard") {
    if ($item.Name -notin @('NepTypeTsf.dll', 'NepTypeEngine.dll')) { throw "Unexpected keyboard payload file: $($item.Name)" }
}
$iscc = "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe"
if (!(Test-Path $iscc)) { throw 'Inno Setup 6 is required. No dependency will be installed automatically.' }
[string[]]$compilerArguments = @("/DAppVersion=$Version", "/DAppNumericVersion=$numericVersion", "/DPayloadDir=$payload", "/DOutputDir=$output")
if ($TestRollback) { $compilerArguments += '/DTestRollback=1' }
$compilerArguments += "$PSScriptRoot/neptype.iss"
& $iscc @compilerArguments
if ($LASTEXITCODE) { throw "Inno Setup failed: $LASTEXITCODE" }
$installer = Get-Item "$output/NepType-$Version-windows-x64-setup.exe"
$hash = (Get-FileHash $installer.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $($installer.Name)" | Set-Content "$($installer.FullName).sha256" -Encoding ascii
$manifest = [ordered]@{
    version = $Version
    sourceCommit = (git -C $root rev-parse HEAD).Trim()
    filename = $installer.Name
    sha256 = $hash
    bytes = $installer.Length
    architecture = 'x64'
    minimumWindows = '10'
    signing = (Get-AuthenticodeSignature $installer.FullName).Status.ToString()
    dictionaryId = (Get-Content "$root/engine/data/manifest.json" -Raw | ConvertFrom-Json).id
    linguisticApproval = $false
    systemKeyboard = $true
    installationScope = 'machine'
    requiresAdministrator = $true
    payloadDirectory = $payload
    testFixture = [bool]$TestFixture
    rollbackInjection = [bool]$TestRollback
    keyboardPayload = [ordered]@{
        tsfSha256 = (Get-FileHash "$payload/keyboard/NepTypeTsf.dll" -Algorithm SHA256).Hash.ToLowerInvariant()
        engineSha256 = (Get-FileHash "$payload/keyboard/NepTypeEngine.dll" -Algorithm SHA256).Hash.ToLowerInvariant()
        helperSha256 = (Get-FileHash "$payload/NepTypeKeyboardSetup.exe" -Algorithm SHA256).Hash.ToLowerInvariant()
        versioned = $true
    }
    tested = $false
}
$manifest | ConvertTo-Json | Set-Content "$output/package.json" -Encoding utf8

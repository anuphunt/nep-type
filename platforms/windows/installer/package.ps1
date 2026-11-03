$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../../..").Path
$version = '0.1.1-preview.1'
$output = Join-Path $root 'build/windows-installer'
$payload = Join-Path $root 'build/windows-payload'
if (Test-Path $payload) { Remove-Item $payload -Recurse -Force }
New-Item -ItemType Directory $output, $payload -Force | Out-Null
Copy-Item "$root/build/windows/Release/NepTypeWindows.exe" "$payload/NepType.exe"
Copy-Item "$root/build/windows/Release/NepTypeEngine.dll" $payload
Copy-Item "$root/build/windows/Release/dictionaries" $payload -Recurse -Force
Copy-Item "$root/LICENSE" "$payload/LICENSE.txt"
Copy-Item "$root/THIRD_PARTY_NOTICES.md" $payload
Copy-Item "$PSScriptRoot/preview.txt" "$payload/README.txt"
# Use an explicit allowlist: the experimental TSF DLL is never distributed.
$expected = @('NepType.exe', 'NepTypeEngine.dll', 'dictionaries', 'LICENSE.txt', 'THIRD_PARTY_NOTICES.md', 'README.txt')
foreach ($item in Get-ChildItem $payload) {
    if ($item.Name -notin $expected) { throw "Unexpected payload file: $($item.Name)" }
}
$iscc = "${env:ProgramFiles(x86)}/Inno Setup 6/ISCC.exe"
if (!(Test-Path $iscc)) { throw 'Inno Setup 6 is required. No dependency will be installed automatically.' }
& $iscc "/DAppVersion=$version" "/DPayloadDir=$payload" "/DOutputDir=$output" "$PSScriptRoot/neptype.iss"
if ($LASTEXITCODE) { throw "Inno Setup failed: $LASTEXITCODE" }
$installer = Get-Item "$output/NepType-$version-windows-x64-setup.exe"
$hash = (Get-FileHash $installer.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $($installer.Name)" | Set-Content "$($installer.FullName).sha256" -Encoding ascii
$manifest = [ordered]@{
    version = $version
    sourceCommit = (git -C $root rev-parse HEAD).Trim()
    filename = $installer.Name
    sha256 = $hash
    bytes = $installer.Length
    architecture = 'x64'
    minimumWindows = '10'
    signing = (Get-AuthenticodeSignature $installer.FullName).Status.ToString()
    systemKeyboard = $false
    tested = $false
}
$manifest | ConvertTo-Json | Set-Content "$output/package.json" -Encoding utf8

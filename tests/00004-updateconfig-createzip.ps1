# 00004-updateconfig-createzip.ps1
# Functional test: Generate files, update IAC config, and create zip

$ErrorActionPreference = "Stop"

$TestName = "00004-updateconfig-createzip"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }
if (Test-Path "../config") { Copy-Item -Recurse -Force "../config" $TestOut }

& "../hash.ps1" -UpdateConfig -CreateZip -ModsPath "../mods" -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
$hashFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-hash.txt" | Select-Object -First 1
if (-not $hashFile) { Write-Error "hash.txt not found"; exit 1 }
$readmeFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-README.md" | Select-Object -First 1
if (-not $readmeFile) { Write-Error "README.md not found"; exit 1 }
if (-not (Test-Path "$TestOut/config/InertiaAntiCheat/InertiaAntiCheat.toml")) { Write-Error "IAC config not found"; exit 1 }
if (-not (Get-ChildItem "$TestOut" -Filter "client-mod-all-*.zip")) { Write-Error "mods zip file not found"; exit 1 }
Write-Host "Test $TestName passed." 
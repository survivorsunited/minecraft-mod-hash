# 00007-updateconfig-motdmessage.ps1
# Functional test: Update IAC config with custom MOTD message

$ErrorActionPreference = "Stop"

$TestName = "00007-updateconfig-motdmessage"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }
if (Test-Path "../config") { Copy-Item -Recurse -Force "../config" $TestOut }

& "../hash.ps1" -UpdateConfig -MotdMessage 'Allowed Mods:' -ModsPath "../mods" -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
$hashFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-hash.txt" | Select-Object -First 1
if (-not $hashFile) { Write-Error "hash.txt not found"; exit 1 }
$readmeFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-README.md" | Select-Object -First 1
if (-not $readmeFile) { Write-Error "README.md not found"; exit 1 }
if (-not (Test-Path "$TestOut/config/InertiaAntiCheat/InertiaAntiCheat.toml")) { Write-Error "IAC config not found"; exit 1 }
Write-Host "Test $TestName passed." 
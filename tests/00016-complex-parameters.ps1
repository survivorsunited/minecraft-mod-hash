# 00016-complex-parameters.ps1
# Functional test: Complex parameter combinations

$ErrorActionPreference = "Stop"

$TestName = "00016-complex-parameters"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Test complex parameter combination: CreateZip + UpdateConfig + Custom messages
& "../hash.ps1" -CreateZip -UpdateConfig -ModsPath "../mods" -OutputPath $TestOut -MotdMessage "Custom MOTD:" -ModpackMessage "Custom Modpack:" -BannedModsMessage "Custom Banned:" *> "$TestOut/test.log"

# Assertions
$hashFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-hash.txt" | Select-Object -First 1
if (-not $hashFile) { Write-Error "hash.txt not found"; exit 1 }
$readmeFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-README.md" | Select-Object -First 1
if (-not $readmeFile) { Write-Error "README.md not found"; exit 1 }

# Check for ZIP file
$zipFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*.zip" | Select-Object -First 1
if (-not $zipFile) { Write-Error "ZIP file not found"; exit 1 }

# Check for config file
$configFile = Get-ChildItem "$TestOut" -Filter "client-mod-all-*-InertiaAntiCheat.toml" | Select-Object -First 1
if (-not $configFile) { Write-Error "Config file not found"; exit 1 }

# Verify custom messages in config
$configContent = Get-Content $configFile.FullName -Raw
if ($configContent -notmatch "Custom MOTD:") { Write-Error "Custom MOTD message not found in config"; exit 1 }
if ($configContent -notmatch "Custom Modpack:") { Write-Error "Custom modpack message not found in config"; exit 1 }
if ($configContent -notmatch "Custom Banned:") { Write-Error "Custom banned message not found in config"; exit 1 }

Write-Host "Test $TestName passed."
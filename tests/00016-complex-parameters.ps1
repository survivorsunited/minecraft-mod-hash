# 00016-complex-parameters.ps1
# Functional test: Complex parameter combinations

$ErrorActionPreference = "Stop"

$TestName = "00016-complex-parameters"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Test complex parameter combination: CreateZip + UpdateConfig + Custom messages
& "../hash.ps1" -CreateZip -UpdateConfig -ModsPath "../mods" -OutputPath $TestOut -MotdMessage "Custom MOTD:" -ModpackMessage "Custom Modpack:" -BannedModsMessage "Custom Banned:" *> "$TestOut/test.log"

# Assertions
# Find the version directory (pattern: YYYY.M.D-HHMMSS)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Check for ZIP file
$zipFile = Join-Path $versionDir.FullName "modpack.zip"
if (-not (Test-Path $zipFile)) { Write-Error "modpack.zip not found in version directory"; exit 1 }

# Check for config file (should be in root output directory with timestamped name)
$configFile = Get-ChildItem "$TestOut" -Filter "*-InertiaAntiCheat.toml" | Select-Object -First 1
if (-not $configFile) { Write-Error "Config file not found"; exit 1 }

# Verify custom messages in config
$configContent = Get-Content $configFile.FullName -Raw
if ($configContent -notmatch "Custom MOTD:") { Write-Error "Custom MOTD message not found in config"; exit 1 }
if ($configContent -notmatch "Custom Modpack:") { Write-Error "Custom modpack message not found in config"; exit 1 }
if ($configContent -notmatch "Custom Banned:") { Write-Error "Custom banned message not found in config"; exit 1 }

Write-Host "Test $TestName passed."
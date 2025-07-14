# 00016-complex-parameters.ps1
# Functional test: Complex parameter combinations

$ErrorActionPreference = "Stop"

$TestName = "00016-complex-parameters"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }

# Create versioned directory
$releaseVersion = Get-Date -Format "yyyy.M.d-HHmmss"
$versionedDir = Join-Path $TestOut $releaseVersion
if (-not (Test-Path $versionedDir)) { New-Item -ItemType Directory -Path $versionedDir | Out-Null }

# Run and capture to temp log
$tempLog = "$versionedDir/temp.log"

Write-Host "Temp log: $tempLog"

# Run script
Write-Host "Running script"
# Test complex parameter combination: CreateZip + UpdateConfig + Custom messages
& "../hash.ps1" -CreateZip -UpdateConfig -ModsPath "../mods" -OutputPath $versionedDir -MotdMessage "Custom MOTD:" -ModpackMessage "Custom Modpack:" -BannedModsMessage "Custom Banned:" *>&1 | Tee-Object -FilePath $tempLog

# Assertions
$hashFile = Join-Path $versionedDir "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionedDir "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

# Check for ZIP file
$zipFile = Join-Path $versionedDir "modpack.zip"
if (-not (Test-Path $zipFile)) { Write-Error "modpack.zip not found in version directory"; exit 1 }

# Check for config file (should be in root output directory with timestamped name)
$configFile = Get-ChildItem "$versionedDir" -Filter "InertiaAntiCheat.toml" | Select-Object -First 1
if (-not $configFile) { Write-Error "Config file not found at $versionedDir"; exit 1 }

# Verify custom messages in config
$configContent = Get-Content $configFile.FullName -Raw
if ($configContent -notmatch "Custom MOTD:") { Write-Error "Custom MOTD message not found in config"; exit 1 }
if ($configContent -notmatch "Custom Modpack:") { Write-Error "Custom modpack message not found in config"; exit 1 }
if ($configContent -notmatch "Custom Banned:") { Write-Error "Custom banned message not found in config"; exit 1 }

# Copy log to version folder if temp log exists
Write-Host "Checking for temp log: $tempLog"
if (Test-Path $tempLog) {
    Write-Host "Temp log exists, copying to version directory"
    $finalLog = Join-Path $versionedDir "test.log"
    Copy-Item -Path $tempLog -Destination $finalLog -Force
    Write-Host "Copied temp log to version directory"
    Remove-Item -Path $tempLog -Force
} else {
    Write-Host "Warning: Temp log not found: $tempLog"
}

Write-Host "Test $TestName passed."
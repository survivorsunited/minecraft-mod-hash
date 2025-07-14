# 00011-outputpath.ps1
# Functional test: Save files to custom output directory

$ErrorActionPreference = "Stop"

$TestName = "00011-outputpath"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }
if (Test-Path "../config") { Copy-Item -Recurse -Force "../config" $TestOut }

# Create versioned directory
$releaseVersion = Get-Date -Format "yyyy.M.d-HHmmss"
$versionedDir = Join-Path $TestOut $releaseVersion
if (-not (Test-Path $versionedDir)) { New-Item -ItemType Directory -Path $versionedDir | Out-Null }

# Run and capture to temp log
$tempLog = "$versionedDir/temp.log"

Write-Host "Temp log: $tempLog"

# Run script
Write-Host "Running script"
& "../hash.ps1" -ModsPath "../mods" -OutputPath $versionedDir *>&1 | Tee-Object -FilePath $tempLog

# Assertions
$hashFile = Join-Path $versionedDir "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionedDir "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }

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
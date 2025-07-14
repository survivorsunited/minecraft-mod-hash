# 00002-createzip.ps1
# Functional test: Generate files and create mods zip package

$ErrorActionPreference = "Stop"

$TestName = "00002-createzip"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }
if (Test-Path "../config") { Copy-Item -Recurse -Force "../config" $TestOut }

& "../hash.ps1" -CreateZip -ModsPath "../mods" -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
# Find the version directory (pattern: YYYY.M.D-HHMMSS)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }
$zipFile = Join-Path $versionDir.FullName "modpack.zip"
if (-not (Test-Path $zipFile)) { Write-Error "modpack.zip not found in version directory"; exit 1 }
Write-Host "Test $TestName passed." 
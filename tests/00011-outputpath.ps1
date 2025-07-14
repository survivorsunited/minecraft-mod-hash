# 00011-outputpath.ps1
# Functional test: Save files to custom output directory

$ErrorActionPreference = "Stop"

$TestName = "00011-outputpath"
$TestOut = "./output/$TestName"
if (-not (Test-Path $TestOut)) { New-Item -ItemType Directory -Path $TestOut | Out-Null }
if (Test-Path "../config") { Copy-Item -Recurse -Force "../config" $TestOut }

& "../hash.ps1" -ModsPath "../mods" -OutputPath $TestOut *> "$TestOut/test.log"

# Assertions
# Find the version directory (pattern: YYYY.M.D-HHMMSS)
$versionDir = Get-ChildItem "$TestOut" -Directory | Where-Object { $_.Name -match '^\d{4}\.\d{1,2}\.\d{1,2}-\d{6}$' } | Select-Object -First 1
if (-not $versionDir) { Write-Error "Version directory not found"; exit 1 }

$hashFile = Join-Path $versionDir.FullName "hash.txt"
if (-not (Test-Path $hashFile)) { Write-Error "hash.txt not found in version directory"; exit 1 }
$readmeFile = Join-Path $versionDir.FullName "README.md"
if (-not (Test-Path $readmeFile)) { Write-Error "README.md not found in version directory"; exit 1 }
Write-Host "Test $TestName passed." 